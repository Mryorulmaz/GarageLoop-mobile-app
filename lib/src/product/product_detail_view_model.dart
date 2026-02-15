import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class ProductDetailViewModel extends ChangeNotifier {
  ProductDetailViewModel({required this.productId}) {
    _loadProduct();
  }

  final String productId;

  String? _mapCondition(String? condition) {
    if (condition == null || condition.isEmpty) return 'New';
    switch (condition.toLowerCase()) {
      case 'new':
      case 'newitem':
      case 'brandnew':
        return 'New';
      case 'like new':
      case 'likenew':
        return 'Like New';
      case 'good':
      case 'used':
      case 'fair':
      case 'forparts':
        return 'Good';
      default:
        return 'New';
    }
  }
  
  bool _isLoading = true;
  String? _error;
  ProductDetail? _product;
  bool _isFavorite = false;
  SharedPreferences? _prefs;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  ProductDetail? get product => _product;
  bool get isFavorite => _isFavorite;

  Future<void> _loadProduct() async {
    try {
      _isLoading = true;
      _error = null;
      if (!_isDisposed) notifyListeners();

      _prefs = await SharedPreferences.getInstance();
      if (_isDisposed) return;
      
      // Firestore'dan gerçek veriyi çek
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(productId)
          .get();
      
      // View count'u artır
      await _incrementViewCount();
      if (_isDisposed) return;
      
      if (doc.exists) {
        final data = doc.data()!;
        
        // Get user location and calculate distance
        double distanceMiles = 0.0;
        double? latitude, longitude;
        
        // Get location from GeoPoint or individual lat/lng fields
        final GeoPoint? location = data['location'] as GeoPoint?;
        if (location != null) {
          latitude = location.latitude;
          longitude = location.longitude;
        } else {
          latitude = data['latitude']?.toDouble();
          longitude = data['longitude']?.toDouble();
        }
        
        if (latitude != null && longitude != null) {
          try {
            // Try to get current user location
            Position? userPosition;
            try {
              userPosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
              );
            } catch (e) {
              debugPrint('Failed to get user location: $e');
              userPosition = null;
            }
            
            if (userPosition != null && !_isDisposed) {
              distanceMiles = Geolocator.distanceBetween(
                userPosition.latitude,
                userPosition.longitude,
                latitude,
                longitude,
              ) * 0.000621371; // Convert meters to miles
            }
          } catch (e) {
            debugPrint('Error calculating distance: $e');
            distanceMiles = 0.0;
          }
        }
        if (_isDisposed) return;
        
        // Address with neighborhood if possible
        String? address = data['address'] ?? data['fullAddress'] ?? data['locality'];
        if (latitude != null && longitude != null) {
          try {
            final placemarks = await geocoding.placemarkFromCoordinates(latitude, longitude);
            if (_isDisposed) return;
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              final neighborhood = p.subLocality?.trim();
              final city = (p.locality ?? '').trim();
              final state = (p.administrativeArea ?? '').trim();
              final parts = <String>[
                if (neighborhood != null && neighborhood.isNotEmpty) neighborhood,
                if (city.isNotEmpty) city,
                if (state.isNotEmpty) state,
              ];
              if (parts.isNotEmpty) {
                address = parts.join(', ');
              }
            }
          } catch (_) {
            // ignore geocoding errors
          }
        }

        // Get seller information from users collection
        SellerInfo sellerInfo = SellerInfo(
          id: data['sellerId'] ?? '',
          name: data['sellerName'] ?? 'Unknown Giver',
          memberSince: '2024',
          salesCount: 0,
        );

        if (data['sellerId'] != null) {
          try {
            final sellerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['sellerId'])
                .get();
            if (_isDisposed) return;
            
            if (sellerDoc.exists) {
              final sellerData = sellerDoc.data()!;
              final memberSince = (sellerData['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now();
              
              sellerInfo = SellerInfo(
                id: data['sellerId'] ?? '',
                name: sellerData['displayName'] ?? data['sellerName'] ?? 'Unknown Giver',
                memberSince: memberSince.year.toString(),
                salesCount: sellerData['totalSales'] ?? 0,
              );
            }
          } catch (e) {
            debugPrint('Error loading seller info: $e');
          }
        }

        // Debug: Firebase'den gelen condition değerini logla
        final rawCondition = data['condition'] as String?;
        final mappedCondition = _mapCondition(rawCondition);
        debugPrint('🔥 Firebase condition: $rawCondition -> Mapped: $mappedCondition');
        
        _product = ProductDetail(
          id: doc.id,
          title: data['title'] ?? 'Unknown Product',
          price: (data['price'] ?? 0).toDouble(),
          description: data['description'] ?? 'No description available',
          images: List<String>.from(data['images'] ?? []),
          distanceMiles: distanceMiles,
          condition: mappedCondition,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          latitude: latitude,
          longitude: longitude,
          address: address,
          seller: sellerInfo,
          favoritesCount: (data['favorites'] as int?) ?? 0,
        );
      } else {
        _error = 'Product not found';
      }
      
      if (!_isDisposed) {
        await _checkFavoriteStatus();
      }
      
    } catch (e) {
      if (!_isDisposed) {
        _error = 'Failed to load product: $e';
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }



  Future<void> _checkFavoriteStatus() async {
    try {
      if (_isDisposed) return;
      
      final favoritesJson = _prefs?.getString('favorites');
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = jsonDecode(favoritesJson);
        _isFavorite = favoritesList.contains(productId);
      } else {
        _isFavorite = false;
      }
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      if (!_isDisposed) {
        _isFavorite = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleFavorite() async {
    try {
      // Misafir kullaniciysa, yazma islemi yapma
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Sadece lokal favoris listesi ile calis (UI icin yeterli)
        final favoritesJson = _prefs?.getString('favorites');
        List<dynamic> favoritesList = favoritesJson != null ? jsonDecode(favoritesJson) : <dynamic>[];

        if (_isFavorite) {
          favoritesList.remove(productId);
          _isFavorite = false;
        } else {
          favoritesList.add(productId);
          _isFavorite = true;
        }
        await _prefs?.setString('favorites', jsonEncode(favoritesList));
        if (!_isDisposed) notifyListeners();
        return;
      }
      final favoritesJson = _prefs?.getString('favorites');
      List<dynamic> favoritesList = [];
      
      if (favoritesJson != null) {
        favoritesList = jsonDecode(favoritesJson);
      }

      if (_isDisposed) return;
      
      if (_isFavorite) {
        // Beğeniyi kaldır
        favoritesList.remove(productId);
        _isFavorite = false;
        
        // Firestore'da favorites sayısını azalt
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(productId)
            .update({
          'favorites': FieldValue.increment(-1),
        });
        
        // Local state'i güncelle
        if (_product != null) {
          _product = ProductDetail(
            id: _product!.id,
            title: _product!.title,
            price: _product!.price,
            description: _product!.description,
            images: _product!.images,
            distanceMiles: _product!.distanceMiles,
            condition: _product!.condition,
            seller: _product!.seller,
            createdAt: _product!.createdAt,
            favoritesCount: (_product!.favoritesCount - 1).clamp(0, double.infinity).toInt(),
            latitude: _product!.latitude,
            longitude: _product!.longitude,
            address: _product!.address,
          );
        }
      } else {
        // Beğeniyi ekle
        favoritesList.add(productId);
        _isFavorite = true;
        
        // Firestore'da favorites sayısını artır
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(productId)
            .update({
          'favorites': FieldValue.increment(1),
        });
        
        // Local state'i güncelle
        if (_product != null) {
          _product = ProductDetail(
            id: _product!.id,
            title: _product!.title,
            price: _product!.price,
            description: _product!.description,
            images: _product!.images,
            distanceMiles: _product!.distanceMiles,
            condition: _product!.condition,
            seller: _product!.seller,
            createdAt: _product!.createdAt,
            favoritesCount: _product!.favoritesCount + 1,
            latitude: _product!.latitude,
            longitude: _product!.longitude,
            address: _product!.address,
          );
        }
      }

      await _prefs?.setString('favorites', jsonEncode(favoritesList));
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        _error = 'Failed to update favorite: $e';
        notifyListeners();
      }
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      // Misafir kullaniciysa yazma yapma (Firestore kurallari geregi reddedilir)
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return;
      }
      // View count'u artır (sadece bir kez per session)
      final String key = 'viewed_$productId';
      final bool alreadyViewed = _prefs?.getBool(key) ?? false;
      
      if (!alreadyViewed) {
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(productId)
            .update({
          'views': FieldValue.increment(1),
        });
        
        // Bu session'da görüldü olarak işaretle
        await _prefs?.setBool(key, true);
        
        if (kDebugMode) {
          debugPrint('View count incremented for product: $productId');
        }
      }
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

class ProductDetail {
  final String id;
  final String title;
  final double price;
  final String description;
  final List<String> images;
  final double distanceMiles;
  final String? condition;
  final SellerInfo seller;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final int favoritesCount;

  ProductDetail({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.images,
    required this.distanceMiles,
    this.condition,
    required this.seller,
    required this.createdAt,
    required this.favoritesCount,
    this.latitude,
    this.longitude,
    this.address,
  });
}

class SellerInfo {
  final String id;
  final String name;
  final String memberSince;
  final int salesCount;

  SellerInfo({
    required this.id,
    required this.name,
    required this.memberSince,
    this.salesCount = 0,
  });
}
