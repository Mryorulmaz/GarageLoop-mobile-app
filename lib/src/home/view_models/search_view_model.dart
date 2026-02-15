import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/search_filters.dart';
import '../models/listing.dart';
import '../repositories/search_repository.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchRepository _repository = SearchRepository();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchResult> _searchResults = [];
  List<String> _recentSearches = [];
  List<String> _trendingSearches = [];
  List<String> _searchSuggestions = [];
  SearchFilters _currentFilters = SearchFilters();
  String _currentQuery = '';
  bool _isSearching = false;

  // Stream subscription
  StreamSubscription<List<SearchResult>>? _searchSubscription;
  Timer? _debounce;
  List<SearchResult> _cache = [];
  String _lastQueryKey = '';

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<SearchResult> get searchResults => List.unmodifiable(_searchResults);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<String> get trendingSearches => List.unmodifiable(_trendingSearches);
  List<String> get searchSuggestions => List.unmodifiable(_searchSuggestions);
  SearchFilters get currentFilters => _currentFilters;
  String get currentQuery => _currentQuery;
  bool get isSearching => _isSearching;
  bool get hasActiveFilters => _currentFilters.hasActiveFilters;
  String get filterSummary => _currentFilters.filterSummary;

  SearchViewModel() {
    _initialize();
    // Start with a basic search to populate results
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Load all active listings initially
      final filters = SearchFilters(query: '');
      final results = await _repository.searchListings(filters);
      _searchResults = results;
      _isSearching = true;
      // initial results loaded: ${results.length}
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SearchViewModel: Failed to load initial data: $e');
      }
    }
  }

  Future<void> _initialize() async {
    await _loadRecentSearches();
    await _loadTrendingSearches();
  }

  // Search methods
  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    try {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () async {
        setLoading(true);
      setError(null);
      _currentQuery = query.trim();
      _isSearching = true;

      // Save search to history
      await _repository.saveSearchToHistory(_currentQuery);

      // Update filters with query
      _currentFilters = _currentFilters.copyWith(query: _currentQuery);

        // Basit cache: aynı sorgu ve filtrede tekrar istek yapma
        final key = '${_currentFilters.hashCode}-${_currentQuery.hashCode}';
        if (_lastQueryKey == key && _cache.isNotEmpty) {
          _searchResults = _cache;
          notifyListeners();
        } else {
          final results = await _repository.searchListings(_currentFilters);
          _searchResults = results;
          _cache = results;
          _lastQueryKey = key;
          notifyListeners();
        }
      });
    } catch (e) {
      setError('Failed to search: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> searchWithFilters(SearchFilters filters) async {
    try {
      setLoading(true);
      setError(null);
      _currentFilters = filters;
      _currentQuery = filters.query;
      _isSearching = true;

      // starting search with filters

      // Save search to history if query is provided
      if (_currentQuery.isNotEmpty) {
        await _repository.saveSearchToHistory(_currentQuery);
      }

      // Perform search
      final results = await _repository.searchListings(_currentFilters);
      _searchResults = results;

      // found ${results.length} results

      // Keep isSearching true to show results
      _isSearching = true;
      notifyListeners();
      
      // isSearching=$_isSearching, results=${_searchResults.length}
    } catch (e) {
      setError('Failed to search with filters: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> searchByText(String query) async {
    if (query.trim().isEmpty) return;

    try {
      setLoading(true);
      setError(null);
      _currentQuery = query.trim();
      _isSearching = true;

      // Save search to history
      await _repository.saveSearchToHistory(_currentQuery);

      // Perform text search
      final results = await _repository.searchByText(_currentQuery);
      _searchResults = results;

      notifyListeners();
    } catch (e) {
      setError('Failed to search by text: $e');
    } finally {
      setLoading(false);
    }
  }

  // Filter methods
  void updateFilters(SearchFilters filters) {
    _currentFilters = filters;
    notifyListeners();
  }

  void setCategory(String? category) {
    _currentFilters = _currentFilters.copyWith(category: category);
    notifyListeners();
  }

  void setPriceRange(double? minPrice, double? maxPrice) {
    _currentFilters = _currentFilters.copyWith(
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    notifyListeners();
  }

  void setCondition(ProductCondition? condition) {
    _currentFilters = _currentFilters.copyWith(condition: condition);
    notifyListeners();
  }

  void setLocation(String? location) {
    _currentFilters = _currentFilters.copyWith(location: location);
    notifyListeners();
  }

  void setRadius(double? radius) {
    _currentFilters = _currentFilters.copyWith(radius: radius);
    notifyListeners();
  }

  void setTags(List<String> tags) {
    _currentFilters = _currentFilters.copyWith(tags: tags);
    notifyListeners();
  }

  void setSortBy(SortBy sortBy) {
    _currentFilters = _currentFilters.copyWith(sortBy: sortBy);
    notifyListeners();
  }

  void setIncludeInactive(bool includeInactive) {
    _currentFilters = _currentFilters.copyWith(includeInactive: includeInactive);
    notifyListeners();
  }

  void clearFilters() {
    _currentFilters = SearchFilters();
    notifyListeners();
  }

  // Location methods
  Future<void> setUserLocation() async {
    try {
      final location = await _repository.getCurrentLocation();
      if (location != null) {
        _currentFilters = _currentFilters.copyWith(userLocation: location);
        notifyListeners();
      }
    } catch (e) {
      setError('Failed to get location: $e');
    }
  }

  // Search history methods
  Future<void> _loadRecentSearches() async {
    try {
      _recentSearches = await _repository.getRecentSearches();
      notifyListeners();
    } catch (e) {
      // ignore: empty_catches
    }
  }

  Future<void> _loadTrendingSearches() async {
    try {
      _trendingSearches = await _repository.getTrendingSearches();
      notifyListeners();
    } catch (e) {
      // ignore: empty_catches
    }
  }

  Future<void> getSearchSuggestions(String query) async {
    if (query.isEmpty) {
      _searchSuggestions = [];
      notifyListeners();
      return;
    }

    try {
      _searchSuggestions = await _repository.getSearchSuggestions(query);
      notifyListeners();
    } catch (e) {
      // ignore: empty_catches
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      await _repository.clearSearchHistory();
      _recentSearches = [];
      notifyListeners();
    } catch (e) {
      setError('Failed to clear search history: $e');
    }
  }

  // Real-time search
  void startRealtimeSearch() {
    _searchSubscription?.cancel();
    _searchSubscription = _repository.streamSearchResults(_currentFilters).listen(
      (results) {
        _searchResults = results;
        notifyListeners();
      },
      onError: (error) {
        setError('Real-time search error: $error');
      },
    );
  }

  void stopRealtimeSearch() {
    _searchSubscription?.cancel();
    _searchSubscription = null;
  }

  // Helper methods
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSearch() {
    _currentQuery = '';
    _searchResults = [];
    _isSearching = false;
    _currentFilters = SearchFilters();
    notifyListeners();
  }

  // Get search statistics
  int get totalResults => _searchResults.length;

  // Get filtered results by category
  List<SearchResult> getResultsByCategory(String category) {
    return _searchResults.where((result) => result.category == category).toList();
  }

  // Get results within price range
  List<SearchResult> getResultsByPriceRange(double minPrice, double maxPrice) {
    return _searchResults.where((result) => 
      result.price >= minPrice && result.price <= maxPrice
    ).toList();
  }

  // Get results by condition
  List<SearchResult> getResultsByCondition(ProductCondition condition) {
    return _searchResults.where((result) => result.condition == condition).toList();
  }

  // Get results by location
  List<SearchResult> getResultsByLocation(String location) {
    return _searchResults.where((result) => result.location == location).toList();
  }

  // Get results within distance
  List<SearchResult> getResultsByDistance(double maxDistance) {
    return _searchResults.where((result) => result.distance <= maxDistance).toList();
  }

  // Sort results
  void sortResults(String sortBy) {
    switch (sortBy) {
      case 'date_new':
        _searchResults.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'date_old':
        _searchResults.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'distance':
        _searchResults.sort((a, b) => a.distance.compareTo(b.distance));
        break;
      case 'relevance':
      default:
        _searchResults.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
        break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
