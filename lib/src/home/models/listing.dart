import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductCondition {
  newItem,
  likeNew,
  used, // Bu "Good" olarak gösterilecek
}

extension ProductConditionExtension on ProductCondition {
  String get conditionText {
    switch (this) {
      case ProductCondition.newItem:
        return 'New';
      case ProductCondition.likeNew:
        return 'Like New';
      case ProductCondition.used:
        return 'Good';
    }
  }
}

enum NegotiationStatus {
  firm,
  negotiable,
  bestOffer,
}

extension NegotiationStatusExtension on NegotiationStatus {
  String get negotiationText {
    switch (this) {
      case NegotiationStatus.firm:
        return 'Pickup time set';
      case NegotiationStatus.negotiable:
        return 'Pickup time flexible';
      case NegotiationStatus.bestOffer:
        return 'Best pickup time';
    }
  }
}

class Listing {
  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.condition,
    required this.category,
    required this.images,
    required this.createdAt,
    required this.lat,
    required this.lng,
    required this.sellerId,
    required this.sellerName,
    required this.negotiationStatus,
    this.brand,
    this.model,
    this.year,
    this.dimensions,
    this.weight,
    this.sku,
    this.tags = const [],
    this.views = 0,
    this.favorites = 0,
    this.isActive = true,
    this.locality,
    this.city,
    this.state,
    this.fullAddress,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final ProductCondition condition;
  final String category;
  final List<String> images;
  final DateTime createdAt;
  final double lat;
  final double lng;
  final String sellerId;
  final String sellerName;
  final NegotiationStatus negotiationStatus;
  final String? brand;
  final String? model;
  final int? year;
  final String? dimensions;
  final String? weight;
  final String? sku;
  final List<String> tags;
  final int views;
  final int favorites;
  final bool isActive;
  final String? locality;
  final String? city;
  final String? state;
  final String? fullAddress;

  // Getters for backward compatibility
  bool get isUsed => condition == ProductCondition.used;
  String get imageUrl => images.isNotEmpty ? images.first : '';

  String get conditionText {
    switch (condition) {
      case ProductCondition.newItem:
        return 'New';
      case ProductCondition.likeNew:
        return 'Like New';
      case ProductCondition.used:
        return 'Good';
    }
  }

  String get negotiationText {
    switch (negotiationStatus) {
      case NegotiationStatus.firm:
        return 'Pickup time set';
      case NegotiationStatus.negotiable:
        return 'Pickup time flexible';
      case NegotiationStatus.bestOffer:
        return 'Best pickup time';
    }
  }

  factory Listing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final GeoPoint? gp = data['location'] as GeoPoint?;
    
    return Listing(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      price: ((data['price'] as num?) ?? 0).toDouble(),
      condition: _parseCondition(data['condition'] as String?),
      category: (data['category'] as String?) ?? 'Other',
      images: List<String>.from(data['images'] ?? [data['imageUrl'] ?? '']),
      createdAt: ((data['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      lat: gp?.latitude ?? (data['lat'] as num?)?.toDouble() ?? 0,
      lng: gp?.longitude ?? (data['lng'] as num?)?.toDouble() ?? 0,
      sellerId: (data['sellerId'] as String?) ?? '',
      sellerName: (data['sellerName'] as String?) ?? 'Unknown',
      negotiationStatus: _parseNegotiation(data['negotiationStatus'] as String?),
      brand: data['brand'] as String?,
      model: data['model'] as String?,
      year: data['year'] as int?,
      dimensions: data['dimensions'] as String?,
      weight: data['weight'] as String?,
      sku: data['sku'] as String?,
      tags: List<String>.from(data['tags'] ?? []),
      views: (data['views'] as int?) ?? 0,
      favorites: (data['favorites'] as int?) ?? 0,
      isActive: (data['isActive'] as bool?) ?? true,
      locality: data['locality'] as String?,
      city: data['city'] as String?,
      state: data['state'] as String?,
      fullAddress: data['fullAddress'] as String?,
    );
  }

  factory Listing.fromFirestore(String id, Map<String, dynamic> data) {
    final GeoPoint? gp = data['location'] as GeoPoint?;
    
    return Listing(
      id: id,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      price: ((data['price'] as num?) ?? 0).toDouble(),
      condition: _parseCondition(data['condition'] as String?),
      category: (data['category'] as String?) ?? 'Other',
      images: List<String>.from(data['images'] ?? [data['imageUrl'] ?? '']),
      createdAt: ((data['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      lat: gp?.latitude ?? (data['lat'] as num?)?.toDouble() ?? 0,
      lng: gp?.longitude ?? (data['lng'] as num?)?.toDouble() ?? 0,
      sellerId: (data['sellerId'] as String?) ?? '',
      sellerName: (data['sellerName'] as String?) ?? 'Unknown',
      negotiationStatus: _parseNegotiation(data['negotiationStatus'] as String?),
      brand: data['brand'] as String?,
      model: data['model'] as String?,
      year: data['year'] as int?,
      dimensions: data['dimensions'] as String?,
      weight: data['weight'] as String?,
      sku: data['sku'] as String?,
      tags: List<String>.from(data['tags'] ?? []),
      views: (data['views'] as int?) ?? 0,
      favorites: (data['favorites'] as int?) ?? 0,
      isActive: (data['isActive'] as bool?) ?? true,
      locality: data['locality'] as String?,
      city: data['city'] as String?,
      state: data['state'] as String?,
      fullAddress: data['fullAddress'] as String?,
    );
  }

  static ProductCondition _parseCondition(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'new':
      case 'brandnew':
      case 'newitem':
        return ProductCondition.newItem;
      case 'likenew':
        return ProductCondition.likeNew;
      case 'good':
      case 'used':
      case 'fair':
      case 'forparts':
      default:
        return ProductCondition.used; // Tüm diğer durumlar "Good" olarak gösterilecek
    }
  }

  static NegotiationStatus _parseNegotiation(String? negotiation) {
    switch (negotiation?.toLowerCase()) {
      case 'firm':
        return NegotiationStatus.firm;
      case 'bestoffer':
        return NegotiationStatus.bestOffer;
      case 'negotiable':
      default:
        return NegotiationStatus.negotiable;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'condition': condition.name,
      'category': category,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'location': GeoPoint(lat, lng),
      'sellerId': sellerId,
      'sellerName': sellerName,
      'negotiationStatus': negotiationStatus.name,
      'brand': brand,
      'model': model,
      'year': year,
      'dimensions': dimensions,
      'weight': weight,
      'sku': sku,
      'tags': tags,
      'views': views,
      'favorites': favorites,
      'isActive': isActive,
      'locality': locality,
      'city': city,
      'state': state,
      'fullAddress': fullAddress,
    };
  }

  Listing copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    ProductCondition? condition,
    String? category,
    List<String>? images,
    DateTime? createdAt,
    double? lat,
    double? lng,
    String? sellerId,
    String? sellerName,
    NegotiationStatus? negotiationStatus,
    String? brand,
    String? model,
    int? year,
    String? dimensions,
    String? weight,
    String? sku,
    List<String>? tags,
    int? views,
    int? favorites,
    bool? isActive,
    String? locality,
    String? city,
    String? state,
    String? fullAddress,
  }) {
    return Listing(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      condition: condition ?? this.condition,
      category: category ?? this.category,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      negotiationStatus: negotiationStatus ?? this.negotiationStatus,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      dimensions: dimensions ?? this.dimensions,
      weight: weight ?? this.weight,
      sku: sku ?? this.sku,
      tags: tags ?? this.tags,
      views: views ?? this.views,
      favorites: favorites ?? this.favorites,
      isActive: isActive ?? this.isActive,
      locality: locality ?? this.locality,
      city: city ?? this.city,
      state: state ?? this.state,
      fullAddress: fullAddress ?? this.fullAddress,
    );
  }
}


