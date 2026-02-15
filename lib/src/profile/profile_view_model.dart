import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'models/user_profile.dart';
import 'repositories/user_profile_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  // Profile state management
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;
  UserProfile? _userProfile;
  List<UserListing> _userListings = [];
  List<UserFavorite> _userFavorites = [];
  List<UserTransaction> _userTransactions = [];

  // Repository
  final UserProfileRepository _repository = UserProfileRepository();
  final ImagePicker _picker = ImagePicker();

  // Settings
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'USD';

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  UserProfile? get userProfile => _userProfile;
  List<UserListing> get userListings => List.unmodifiable(_userListings);
  List<UserFavorite> get userFavorites => List.unmodifiable(_userFavorites);
  List<UserTransaction> get userTransactions => List.unmodifiable(_userTransactions);
  
  // Settings getters
  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationEnabled => _locationEnabled;
  bool get darkModeEnabled => _darkModeEnabled;
  String get selectedLanguage => _selectedLanguage;
  String get selectedCurrency => _selectedCurrency;

  ProfileViewModel() {
    _initializeProfile();
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

  Future<void> _initializeProfile() async {
    try {
      setLoading(true);
      
      // Get current user
      _currentUser ??= FirebaseAuth.instance.currentUser;
      if (_currentUser == null) {
        setError('No user logged in');
        return;
      }

      // Load user profile
      await _loadUserProfile();
      
      // Load user listings
      await _loadUserListings();
      
      // Load user favorites
      await _loadUserFavorites();
      
      // Load user transactions
      await _loadUserTransactions();
      
      // Load settings
      await _loadSettings();
      
    } catch (e) {
      setError('Failed to load profile: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      _userProfile = await _repository.getCurrentUserProfile();
      
      _userProfile ??= await _repository.createUserProfile(
        displayName: _currentUser!.displayName ?? 'User',
        email: _currentUser!.email ?? '',
        profileImageUrl: _currentUser!.photoURL,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadUserListings() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('userId', isEqualTo: _currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _userListings = snapshot.docs
          .map((doc) => UserListing.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user listings: $e');
    }
  }

  Future<void> _loadUserFavorites() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: _currentUser!.uid)
          .orderBy('addedAt', descending: true)
          .get();

      _userFavorites = snapshot.docs
          .map((doc) => UserFavorite.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user favorites: $e');
    }
  }

  Future<void> _loadUserTransactions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('buyerId', isEqualTo: _currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _userTransactions = snapshot.docs
          .map((doc) => UserTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user transactions: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _locationEnabled = prefs.getBool('location_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
      _selectedCurrency = prefs.getString('selected_currency') ?? 'USD';
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('location_enabled', _locationEnabled);
      await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
      await prefs.setString('selected_language', _selectedLanguage);
      await prefs.setString('selected_currency', _selectedCurrency);
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving settings: $e');
    }
  }

  // Profile photo methods
  Future<void> uploadProfilePhoto() async {
    try {
      setLoading(true);
      setError(null);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final photoUrl = await _repository.uploadProfilePhoto(file);
        
        if (photoUrl != null) {
          _userProfile = _userProfile?.copyWith(profileImageUrl: photoUrl);
          notifyListeners();
        } else {
          setError('Failed to upload profile photo');
        }
      }
    } catch (e) {
      setError('Failed to upload profile photo: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> takeProfilePhoto() async {
    try {
      setLoading(true);
      setError(null);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final photoUrl = await _repository.uploadProfilePhoto(file);
        
        if (photoUrl != null) {
          _userProfile = _userProfile?.copyWith(profileImageUrl: photoUrl);
          notifyListeners();
        } else {
          setError('Failed to upload profile photo');
        }
      }
    } catch (e) {
      setError('Failed to take profile photo: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> deleteProfilePhoto() async {
    try {
      setLoading(true);
      setError(null);

      final success = await _repository.deleteProfilePhoto();
      
      if (success) {
        _userProfile = _userProfile?.copyWith(profileImageUrl: null);
        notifyListeners();
      } else {
        setError('Failed to delete profile photo');
      }
    } catch (e) {
      setError('Failed to delete profile photo: $e');
    } finally {
      setLoading(false);
    }
  }

  // Update profile methods
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? location,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    try {
      setLoading(true);
      setError(null);

      final updatedProfile = await _repository.updateUserProfile(
        displayName: displayName,
        bio: bio,
        location: location,
        dateOfBirth: dateOfBirth,
        gender: gender,
      );

      if (updatedProfile != null) {
        _userProfile = updatedProfile;
        notifyListeners();
      } else {
        setError('Failed to update profile');
      }
    } catch (e) {
      setError('Failed to update profile: $e');
    } finally {
      setLoading(false);
    }
  }

  // Settings methods
  Future<void> toggleNotifications() async {
    _notificationsEnabled = !_notificationsEnabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleLocation() async {
    _locationEnabled = !_locationEnabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _darkModeEnabled = !_darkModeEnabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _selectedLanguage = language;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    _selectedCurrency = currency;
    await _saveSettings();
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    try {
      setLoading(true);
      await FirebaseAuth.instance.signOut();
      _currentUser = null;
      _userProfile = null;
      _userListings.clear();
      _userFavorites.clear();
      _userTransactions.clear();
    } catch (e) {
      setError('Failed to logout: $e');
    } finally {
      setLoading(false);
    }
  }

  // Refresh data
  Future<void> refresh() async {
    await _initializeProfile();
  }
}

// User Listing Model
class UserListing {
  final String id;
  final String title;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final int views;

  UserListing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.isActive,
    required this.createdAt,
    required this.views,
  });

  UserListing copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    int? views,
  }) {
    return UserListing(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      views: views ?? this.views,
    );
  }

  factory UserListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserListing(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? '',
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      views: data['views'] ?? 0,
    );
  }
}

// User Favorite Model
class UserFavorite {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final DateTime addedAt;

  UserFavorite({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.addedAt,
  });

  factory UserFavorite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserFavorite(
      id: doc.id,
      title: data['title'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// User Transaction Model
class UserTransaction {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final String sellerId;
  final String buyerId;
  final String sellerName;
  final String buyerName;
  final DateTime createdAt;
  final String status;

  UserTransaction({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
    required this.buyerId,
    required this.sellerName,
    required this.buyerName,
    required this.createdAt,
    required this.status,
  });

  bool get isPurchase => buyerId == FirebaseAuth.instance.currentUser?.uid;
  bool get isSale => sellerId == FirebaseAuth.instance.currentUser?.uid;

  factory UserTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserTransaction(
      id: doc.id,
      title: data['title'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      sellerId: data['sellerId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      sellerName: data['sellerName'] ?? '',
      buyerName: data['buyerName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }
}
