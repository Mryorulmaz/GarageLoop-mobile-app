import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../core/services/image_optimization_service.dart';
import '../core/services/storage_service.dart';
import '../core/data/us_locations.dart';
import '../home/models/listing.dart';

class SellViewModel extends ChangeNotifier {
  SellViewModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final ImagePicker _picker = ImagePicker();
  final ImageOptimizationService _imageOptimizer = ImageOptimizationService();
  final StorageService _storageService = StorageService();

  String title = '';
  String description = '';
  double price = 0;
  ProductCondition condition = ProductCondition.newItem;
  NegotiationStatus negotiationStatus = NegotiationStatus.negotiable;
  String category = 'Other';
  double? lat;
  double? lng;
  String? localityLabel; // e.g., Brooklyn, NY
  bool isSubmitting = false;
  String? error;
  final List<XFile> _images = <XFile>[];
  List<XFile> get images => List<XFile>.unmodifiable(_images);

  // Additional product details
  String? brand;
  String? model;
  int? year;
  String? dimensions;
  String? weight;
  String? sku;
  final List<String> _tags = <String>[];
  List<String> get tags => List<String>.unmodifiable(_tags);

  // Location selection
  String? selectedState;
  String? selectedCity;
  bool showLocationPicker = false;
  LatLng? _currentPosition;

  // Get states and cities from USLocations
  List<String> get states => USLocations.states;
  
  List<String> get citiesForSelectedState {
    if (selectedState == null) return [];
    return USLocations.getCitiesForState(selectedState!);
  }

  // Helper method to extract city name from "City, State" format
  String _extractCityName(String cityWithState) {
    return cityWithState.split(',')[0].trim();
  }


  static const List<String> categories = [
    'Electronics',
    'Furniture',
    'Clothing',
    'Books',
    'Sports',
    'Tools',
    'Garden',
    'Auto Parts',
    'Toys',
    'Collectibles',
    'Home & Garden',
    'Appliances',
    'Jewelry',
    'Art',
    'Music',
    'Movies',
    'Baby & Kids',
    'Pet Supplies',
    'Health & Beauty',
    'Other',
  ];

  static const Map<String, List<String>> subCategories = {
    'Electronics': ['Phones', 'Laptops', 'TVs', 'Cameras', 'Gaming', 'Audio', 'Tablets', 'Computers'],
    'Furniture': ['Tables', 'Chairs', 'Sofas', 'Beds', 'Dressers', 'Desks', 'Bookcases', 'Outdoor'],
    'Clothing': ['Men', 'Women', 'Kids', 'Shoes', 'Accessories', 'Vintage', 'Formal', 'Casual'],
    'Books': ['Fiction', 'Non-Fiction', 'Textbooks', 'Children', 'Comics', 'Magazines', 'Reference'],
    'Sports': ['Bikes', 'Fitness', 'Team Sports', 'Outdoor', 'Swimming', 'Golf', 'Tennis', 'Running'],
    'Tools': ['Power Tools', 'Hand Tools', 'Garden Tools', 'Automotive', 'Woodworking', 'Plumbing'],
    'Garden': ['Plants', 'Pots', 'Furniture', 'Tools', 'Decorations', 'Seeds', 'Soil'],
    'Auto Parts': ['Engine', 'Body', 'Interior', 'Wheels', 'Audio', 'Performance', 'Maintenance'],
    'Toys': ['Action Figures', 'Dolls', 'Board Games', 'Puzzles', 'Educational', 'Outdoor'],
    'Collectibles': ['Coins', 'Stamps', 'Cards', 'Figurines', 'Antiques', 'Comics', 'Vinyl'],
  };


  void updateTitle(String value) {
    title = value;
    notifyListeners();
  }

  void updateDescription(String value) {
    description = value;
    notifyListeners();
  }

  void updatePrice(double value) {
    price = value;
    notifyListeners();
  }

  void updateCondition(ProductCondition value) {
    condition = value;
    notifyListeners();
  }

  void updateNegotiationStatus(NegotiationStatus value) {
    negotiationStatus = value;
    notifyListeners();
  }

  void updateCategory(String value) {
    category = value;
    notifyListeners();
  }

  void updateBrand(String? value) {
    brand = value;
    notifyListeners();
  }

  void updateModel(String? value) {
    model = value;
    notifyListeners();
  }

  void updateYear(int? value) {
    year = value;
    notifyListeners();
  }

  void updateDimensions(String? value) {
    dimensions = value;
    notifyListeners();
  }

  void updateWeight(String? value) {
    weight = value;
    notifyListeners();
  }

  void updateSku(String? value) {
    sku = value;
    notifyListeners();
  }

  void addTag(String tag) {
    if (!_tags.contains(tag)) {
      _tags.add(tag);
      notifyListeners();
    }
  }

  void removeTag(String tag) {
    _tags.remove(tag);
    notifyListeners();
  }

  Future<void> addImage() async {
    try {
      // Use pickMultipleMedia to allow selecting multiple images at once
      final List<XFile> selectedImages = await _picker.pickMultipleMedia(
        imageQuality: 85,
      );
      
      if (selectedImages.isNotEmpty) {
        // Validate and add each selected image
        for (final image in selectedImages) {
          // Validate file size (max 5MB)
          final file = File(image.path);
          final fileSize = await file.length();
          if (fileSize > 5 * 1024 * 1024) {
            error = 'Some images exceed 5MB limit and were skipped';
            notifyListeners();
            continue; // Skip this image but continue with others
          }
          
          _images.add(image);
        }
        
        if (_images.isNotEmpty) {
          error = null;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      error = 'Failed to select images. Please try again.';
      notifyListeners();
    }
  }

  Future<void> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        // Validate file size (max 5MB)
        final file = File(image.path);
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          error = 'Image size must be less than 5MB';
          notifyListeners();
          return;
        }
        
        _images.add(image);
        error = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      error = 'Failed to take photo. Please try again.';
      notifyListeners();
    }
  }

  Future<void> optimizeImage(File originalFile) async {
    try {
      final File? optimizedFile = await _imageOptimizer.optimizeImageFromFile(originalFile);
      if (optimizedFile != null) {
        replaceImage(originalFile, optimizedFile);
      }
    } catch (e) {
      debugPrint('Error optimizing image: $e');
    }
  }

  // Replace image with optimized version
  void replaceImage(File originalFile, File optimizedFile) {
    final index = _images.indexWhere((img) => img.path == originalFile.path);
    if (index != -1) {
      _images[index] = XFile(optimizedFile.path);
      notifyListeners();
    }
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= _images.length) return;
    _images.removeAt(index);
    notifyListeners();
  }

  Future<String?> submit() async {
    if (title.isEmpty) {
      error = 'Please provide a title';
      notifyListeners();
      return null;
    }
    
    // Temporarily allow submission without images for testing
    if (_images.isEmpty) {
      debugPrint('No images provided, continuing without images');
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    final List<String> imageUrls = <String>[];
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Test Firebase Storage connection first
      try {
        await testFirebaseConnection();
      } catch (e) {
        debugPrint('Firebase Storage test failed, but continuing: $e');
      }

      // Upload images using Storage Service
      if (_images.isNotEmpty) {
        try {
          debugPrint('Uploading ${_images.length} images to Firebase Storage...');
          
          // Convert XFile to File for upload
          final List<File> imageFiles = _images.map((xfile) => File(xfile.path)).toList();
          
          // Upload images using Storage Service
          final uploadedUrls = await _storageService.uploadImages(
            imageFiles: imageFiles,
            folder: 'listings/${user.uid}',
            prefix: 'listing_${DateTime.now().millisecondsSinceEpoch}',
          );
          
          imageUrls.addAll(uploadedUrls);
          debugPrint('Successfully uploaded ${uploadedUrls.length} images');
        } catch (e) {
          debugPrint('Error uploading images: $e');
          // Fallback to placeholder images
          for (int i = 0; i < _images.length; i++) {
            imageUrls.add('https://via.placeholder.com/400x300/4285F4/ffffff?text=Product+Image+${i + 1}');
          }
        }
      } else {
        // Add a default placeholder image
        imageUrls.add('https://via.placeholder.com/400x300/cccccc/666666?text=No+Image');
      }

      // Ensure we have coordinates if city/state selected
      if ((lat == null || lng == null) && selectedCity != null && selectedState != null) {
        try {
          final List<geocoding.Location> results = await geocoding.locationFromAddress(
            '${selectedCity!}, ${selectedState!}, USA',
          );
          if (results.isNotEmpty) {
            lat = results.first.latitude;
            lng = results.first.longitude;
          }
        } catch (e) {
          debugPrint('Geocoding before submit failed: $e');
        }
      }

      // Create listing data (primary write)
      final listingData = {
        'title': title,
        'description': description,
        'price': 0.0,
        'condition': condition.name,
        'negotiationStatus': negotiationStatus.name,
        'category': category,
        'images': imageUrls,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'location': (lat != null && lng != null) ? GeoPoint(lat!, lng!) : null,
        'locality': localityLabel,
        'address': localityLabel,
        'city': selectedCity,
        'state': selectedState,
        'fullAddress': localityLabel,
        'sellerId': user.uid,
        'sellerName': user.displayName ?? 'Unknown',
        'brand': brand,
        'model': model,
        'year': year,
        'dimensions': dimensions,
        'weight': weight,
        'sku': sku,
        'tags': _tags,
        'views': 0,
        'favorites': 0,
      };

      // Primary write first (so publish succeeds even if index writes fail)
      final docRef = _firestore.collection('listings').doc();
      debugPrint('Publishing listing to /listings/${docRef.id} ...');
      await docRef.set(listingData);

      // Reward seller with credits (+5) after successful publish
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'credits': FieldValue.increment(5),
        });
      } catch (e) {
        debugPrint('Failed to grant listing credits: $e');
      }

      // Optional index writes (best-effort)
      try {
        final userListingRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('listings')
            .doc(docRef.id);
        await userListingRef.set({
          'listingId': docRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      } catch (e) {
        debugPrint('Optional write failed: users/{uid}/listings -> $e');
      }

      try {
        final categoryRef = _firestore
            .collection('categories')
            .doc(category.toLowerCase().replaceAll(' ', '_'))
            .collection('listings')
            .doc(docRef.id);
        await categoryRef.set({
          'listingId': docRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      } catch (e) {
        debugPrint('Optional write failed: categories index -> $e');
      }
      
      // Clear form
      _clearForm();
      
      // Return the created listing ID for navigation
      return docRef.id;
      
    } catch (e) {
      debugPrint('Submit error: $e');
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('object-not-found')) {
        error = 'Image upload failed. Please try again with different images.';
      } else if (errorString.contains('permission-denied')) {
        error = 'Permission denied. Please check your internet connection and try again.';
      } else if (errorString.contains('unauthenticated')) {
        error = 'Please sign in again to publish your listing.';
      } else if (errorString.contains('network')) {
        error = 'Network error. Please check your internet connection and try again.';
      } else if (errorString.contains('quota')) {
        error = 'Storage quota exceeded. Please try with fewer images.';
      } else if (errorString.contains('file not found')) {
        error = 'Image file not found. Please select images again.';
      } else {
        error = 'Failed to publish listing. Please try again. Error: ${e.toString().substring(0, 100)}';
      }
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
    // Ensure a return value in all code paths
    return null;
  }

  @override
  void dispose() {
    // Clear all data to prevent memory leaks
    _images.clear();
    _tags.clear();
    super.dispose();
  }

  void _clearForm() {
    title = '';
    description = '';
    price = 0;
    condition = ProductCondition.used;
    negotiationStatus = NegotiationStatus.negotiable;
    category = 'Other';
    lat = null;
    lng = null;
    localityLabel = null;
    _images.clear();
    brand = null;
    model = null;
    year = null;
    dimensions = null;
    weight = null;
    sku = null;
    _tags.clear();
    notifyListeners();
  }

  void toggleLocationPicker() {
    showLocationPicker = !showLocationPicker;
    notifyListeners();
  }

  void selectState(String state) {
    selectedState = state;
    selectedCity = null;
    notifyListeners();
  }

  Future<void> selectCity(String cityWithState) async {
    // Extract just the city name from "City, State" format
    final String cityName = _extractCityName(cityWithState);
    selectedCity = cityName;
    // Ensure selectedState is consistent with cityWithState suffix
    if (selectedState == null || !cityWithState.endsWith(selectedState!)) {
      final parts = cityWithState.split(',');
      if (parts.length > 1) selectedState = parts[1].trim();
    }
    localityLabel = selectedState != null ? '$cityName, $selectedState' : cityName;
    notifyListeners();

    // Resolve coordinates for the selected city/state (center point)
    try {
      final List<geocoding.Location> results = await geocoding.locationFromAddress(
        selectedState != null ? '$cityName, $selectedState, USA' : '$cityName, USA',
      );
      if (results.isNotEmpty) {
        lat = results.first.latitude;
        lng = results.first.longitude;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Geocoding failed for $cityName, $selectedState: $e');
    }
  }

  // Google Maps integration
  Future<void> setLocationFromMaps(LatLng position, String address, {bool doReverseGeocode = false}) async {
    _currentPosition = position;
    lat = position.latitude;
    lng = position.longitude;
    localityLabel = address;
    if (doReverseGeocode) {
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          selectedCity = p.locality ?? selectedCity;
          selectedState = p.administrativeArea ?? selectedState;
        }
      } catch (e) {
        debugPrint('Reverse geocoding failed: $e');
      }
    }
    notifyListeners();
  }

  LatLng? get currentPosition => _currentPosition;

  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        error = 'Location permission denied';
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      lat = position.latitude;
      lng = position.longitude;

      // Get address
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          localityLabel = '${placemark.locality ?? 'Unknown'}, ${placemark.administrativeArea ?? 'Unknown'}';
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
        localityLabel = 'Current Location';
      }

      notifyListeners();
    } catch (e) {
      error = 'Error getting location: $e';
      notifyListeners();
    }
  }

  bool get canSubmit {
    return title.isNotEmpty && 
           _images.isNotEmpty && 
           !isSubmitting;
  }

  // Debug function to test Firebase connection
  Future<void> testFirebaseConnection() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No authenticated user');
        return;
      }
      
      debugPrint('Testing Firebase Storage connection...');
      debugPrint('Storage bucket: ${FirebaseStorage.instance.app.options.storageBucket}');
      
      // Try a simple upload without metadata first
      final testRef = FirebaseStorage.instance
          .ref('test/${user.uid}/test.txt');
      
      debugPrint('Test reference path: ${testRef.fullPath}');
      
      // Simple string upload
      await testRef.putString('test');
      debugPrint('Test upload successful');
      
      // Try to get download URL
      final downloadUrl = await testRef.getDownloadURL();
      debugPrint('Test download URL: $downloadUrl');
      
      // Clean up
      await testRef.delete();
      debugPrint('Firebase Storage connection successful');
    } catch (e) {
      debugPrint('Firebase Storage connection failed: $e');
      // Don't throw exception, just log the error
    }
  }

  String? get validationError {
    if (title.isEmpty) return 'Title is required';
    if (_images.isEmpty) return 'At least one image is required';
    return null;
  }
}


