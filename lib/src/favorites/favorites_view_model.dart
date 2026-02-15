import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesViewModel extends ChangeNotifier {
  FavoritesViewModel() {
    _initializeFavorites();
  }

  // State
  bool _isLoading = true;
  String? _error;
  List<FavoriteProduct> _favorites = [];
  SharedPreferences? _prefs;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<FavoriteProduct> get favorites => List.unmodifiable(_favorites);

  Future<void> _initializeFavorites() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadFavorites();
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing favorites: $e');
      _loadDemoFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final favoritesJson = _prefs?.getString('favorites');
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = jsonDecode(favoritesJson);
        final productIds = favoritesList.cast<String>().toList();
        
        if (productIds.isNotEmpty) {
          _favorites = await _getProductsFromFirestore(productIds);
        } else {
          _favorites = [];
        }
      } else {
        _favorites = [];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load favorites: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadDemoFavorites() {
    // No demo favorites - only real data
    _favorites = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<List<FavoriteProduct>> _getProductsFromFirestore(List<String> ids) async {
    try {
      final List<FavoriteProduct> favorites = [];
      
      for (final id in ids) {
        final doc = await FirebaseFirestore.instance
            .collection('listings')
            .doc(id)
            .get();
            
        if (doc.exists) {
          final data = doc.data()!;
          favorites.add(FavoriteProduct(
            id: doc.id,
            title: data['title'] ?? 'Unknown Product',
            price: (data['price'] ?? 0).toDouble(),
            imageUrl: (data['images'] as List?)?.isNotEmpty == true 
                ? (data['images'] as List).first 
                : 'https://via.placeholder.com/400x300/cccccc/666666?text=No+Image',
            distanceMiles: 0.0, // Will be calculated based on user location
          ));
        } else {
        }
      }
      
      return favorites;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading favorites from Firestore: $e');
      return [];
    }
  }

  // Removed unused demo method _getProductsByIds

  Future<void> removeFavorite(String productId) async {
    try {
      _favorites.removeWhere((product) => product.id == productId);
      final favoritesJson = _prefs?.getString('favorites');
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = jsonDecode(favoritesJson);
        favoritesList.remove(productId);
        await _prefs?.setString('favorites', jsonEncode(favoritesList));
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove favorite: $e';
      notifyListeners();
    }
  }

  Future<void> clearAllFavorites() async {
    try {
      _favorites.clear();
      await _prefs?.remove('favorites');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear favorites: $e';
      notifyListeners();
    }
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _loadFavorites();
  }
}

class FavoriteProduct {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final double distanceMiles;

  FavoriteProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.distanceMiles,
  });
}

