import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'models/home_product.dart';
import 'models/sort_option.dart';
import 'repositories/home_repository.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel() {
    _initialize();
  }

  // Remote data from Firestore
  List<HomeProduct> _remote = <HomeProduct>[];
  StreamSubscription<List<HomeProduct>>? _listingsSubscription;
  bool _isLoading = true;
  String? _error;
  final HomeRepository _repository = HomeRepository();
  // Filtrelenmiş sonuçlar için basit cache
  List<HomeProduct> _filteredCache = <HomeProduct>[];
  bool _filtersDirty = true;
  
  // Local state
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _dateFilter = 'all';
  String _conditionFilter = 'all';
  SortOption _currentSort = SortOption.newest;
  Set<String> _favorites = <String>{};
  double _maxDistanceMiles = 50.0;
  SharedPreferences? _prefs;
  Timer? _searchDebounce;
  bool _showFavoritesOnly = false;
  String? _locationFilter; // e.g., "Buffalo, New York" – null => show all
  // String? _selectedState; // currently unused
  // String? _selectedCity;  // currently unused
  
  // No dummy data - only real Firestore data

  // Getters
  List<HomeProduct> get products => _remote;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<HomeProduct> get filteredProducts {
    if (!_filtersDirty) return _filteredCache;
    List<HomeProduct> filtered = _remote;
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) =>
          product.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Category filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((product) => product.category == _selectedCategory).toList();
    }
    
    // Date filter
    filtered = filtered.where((product) => _matchesDateFilter(product.createdAt)).toList();
    
    // Condition filter
    if (_conditionFilter != 'all') {
      if (kDebugMode) {
        debugPrint('HomeViewModel: Applying condition filter: $_conditionFilter');
      }
      final beforeCount = filtered.length;
      filtered = filtered.where((product) {
        if (_conditionFilter == 'used') return product.condition == 'used';
        if (_conditionFilter == 'new') return product.condition == 'newItem';
        if (_conditionFilter == 'likeNew') return product.condition == 'likeNew';
        return true;
      }).toList();
      if (kDebugMode) {
        debugPrint('HomeViewModel: Condition filter result: $beforeCount -> ${filtered.length} products');
      }
    }
    
    // Location filter first (exact-ish text match)
    if (_locationFilter != null && _locationFilter!.trim().isNotEmpty) {
      final needle = _locationFilter!.toLowerCase();
      filtered = filtered.where((p) {
        final loc = (p.locality ?? '').toLowerCase();
        // locality boş olanları ve eşleşmeyenleri dışla
        return loc.isNotEmpty && (loc.contains(needle) || needle.contains(loc));
      }).toList();
    }

    // Distance filter
    if (_locationFilter != null && _locationFilter!.trim().isNotEmpty) {
      // Bölge seçiliyse mesafe bilinmiyorsa da gösterebiliriz; yalnızca radius üstünü ele
      filtered = filtered
          .where((p) => p.distanceMiles == 0 || p.distanceMiles <= _maxDistanceMiles)
          .toList();
    } else if (_maxDistanceMiles < 50.0) {
      filtered = filtered.where((product) => product.distanceMiles <= _maxDistanceMiles).toList();
    }
    
    // Favorites filter
    if (_showFavoritesOnly) {
      filtered = filtered.where((product) => _favorites.contains(product.id)).toList();
    }
    
    // Apply sorting based on current sort option
    filtered.sort((a, b) {
      switch (_currentSort) {
        case SortOption.newest:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.nearest:
          return a.distanceMiles.compareTo(b.distanceMiles);
        case SortOption.lowestPrice:
        case SortOption.highestPrice:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    _filteredCache = filtered;
    _filtersDirty = false;
    return _filteredCache;
  }

  bool _matchesDateFilter(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    switch (_dateFilter) {
      case 'today':
        return difference.inDays == 0;
      case 'week':
        return difference.inDays <= 7;
      case 'month':
        return difference.inDays <= 30;
      case 'all':
      default:
        return true;
    }
  }

  List<HomeProduct> get nearbyRecommendations {
    final List<HomeProduct> items = filteredProducts;
    items.sort((a, b) => a.distanceMiles.compareTo(b.distanceMiles));
    return items.take(6).toList();
  }

  Future<void> initialize() async {
    await _initialize();
  }

  Future<void> _initialize() async {
    // Get user location
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        // Location permission denied
      } else {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        // User location retrieved
        await _repository.setUserLocation(position);
      }
    } catch (e) {
      // Error getting location
      // Keep default location if GPS fails
    }

    // Start listening to Firestore listings
    try {
      _listingsSubscription = _repository.listenListings().listen(
        (listings) {
          // Received listings from Firestore
          _remote = listings;
          _isLoading = false;
          _error = null;
          _filtersDirty = true;
          notifyListeners();
        },
        onError: (error) {
          // Error listening to listings
          _isLoading = false;
          _error = 'Failed to load listings. Please try again.';
          _filtersDirty = true;
          notifyListeners();
        },
      );
    } catch (e) {
      // Error setting up Firestore listener
    }

    // Initialize favorites
    await _initializeFavorites();
  }

  Future<void> _initializeFavorites() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      // Load favorites in background
      _loadFavorites();
    } catch (e) {
      // Error initializing favorites
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favoritesJson = _prefs?.getString('favorites');
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = jsonDecode(favoritesJson);
        _favorites = favoritesList.cast<String>().toSet();
        notifyListeners();
      }
    } catch (e) {
      // Error loading favorites
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final favoritesJson = jsonEncode(_favorites.toList());
      await _prefs?.setString('favorites', favoritesJson);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  Future<void> toggleFavorite(String productId) async {
    try {
      if (_favorites.contains(productId)) {
        _favorites.remove(productId);
      } else {
        _favorites.add(productId);
      }
      
      await _saveFavorites();
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  bool isFavorite(String productId) {
    return _favorites.contains(productId);
  }

  bool get showFavoritesOnly => _showFavoritesOnly;

  void toggleShowFavorites() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _filtersDirty = true;
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchDebounce?.cancel();
    _searchQuery = query;
    _filtersDirty = true;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      notifyListeners();
    });
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _filtersDirty = true;
    notifyListeners();
  }

  void setDateFilter(String filter) {
    _dateFilter = filter;
    _filtersDirty = true;
    notifyListeners();
  }

  void setConditionFilter(String filter) {
    _conditionFilter = filter;
    _filtersDirty = true;
    notifyListeners();
  }

  void setCondition(String condition) {
    _conditionFilter = condition;
    _filtersDirty = true;
    if (kDebugMode) {
      debugPrint('HomeViewModel: Condition set to $condition');
    }
    notifyListeners();
  }

  void setMaxDistance(double distance) {
    _maxDistanceMiles = distance;
    _filtersDirty = true;
    notifyListeners();
  }

  void setManualLocation(String location, double lat, double lng) {
    // Manual location set
    // Create a Position object from manual location
    final position = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
    
    _repository.setUserLocation(position);
    _locationFilter = location; // filter by selected region on client
    // Location updated, notifying listeners
    _filtersDirty = true;
    notifyListeners();
  }

  void setSort(SortOption sort) {
    _currentSort = sort;
    _filtersDirty = true;
    notifyListeners();
  }

  // Restart Firestore stream with current repository filters
  void _restartSubscription() {
    try {
      _listingsSubscription?.cancel();
    } catch (_) {}
    _listingsSubscription = _repository.listenListings().listen(
      (listings) {
        _remote = listings;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _error = 'Failed to load listings. Please try again.';
        notifyListeners();
      },
    );
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _dateFilter = 'all';
    _conditionFilter = 'all';
    _currentSort = SortOption.newest;
    _showFavoritesOnly = false;
    // Keep other filters cleared
    _filtersDirty = true;
    notifyListeners();
  }

  List<String> get categories {
    final Set<String> categorySet = <String>{'All'};
    for (final product in _remote) {
      categorySet.add(product.category);
    }
    return categorySet.toList()..sort();
  }

  String get currentLocationLabel => _locationFilter ?? 'Current Location';
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  void setLocationFilter(String? regionLabel) {
    _locationFilter = regionLabel;
    _filtersDirty = true;
    notifyListeners();
  }

  void clearLocationFilter() {
    _locationFilter = null;
    _filtersDirty = true;
    notifyListeners();
  }

  // Server-side state/city filter controls
  void applyStateCityFilter({required String state, String? city}) {
    _repository.setStateCityFilter(state: state, city: city);
    _locationFilter = city != null && city.isNotEmpty ? '$city, $state' : state;
    _filtersDirty = true;
    notifyListeners();
    _restartSubscription();
  }

  void clearStateCityFilter() {
    _repository.clearLocationFilters();
    _locationFilter = null;
    _filtersDirty = true;
    notifyListeners();
    _restartSubscription();
  }
  String get dateFilter => _dateFilter;
  String get conditionFilter => _conditionFilter;
  double get maxDistanceMiles => _maxDistanceMiles;
  String get condition => _conditionFilter;
  SortOption get sort => _currentSort;

  @override
  void dispose() {
    _listingsSubscription?.cancel();
    _searchDebounce?.cancel();
    _prefs = null;
    super.dispose();
  }
}