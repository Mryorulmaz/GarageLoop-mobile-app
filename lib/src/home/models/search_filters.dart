import 'package:cloud_firestore/cloud_firestore.dart';
import 'listing.dart';

class SearchFilters {
  SearchFilters({
    this.query = '',
    this.category = 'All',
    this.minPrice = 0.0,
    this.maxPrice = 10000.0,
    this.condition,
    this.negotiationStatus,
    this.location = '',
    this.radius = 25.0, // miles
    this.userLocation,
    this.tags = const [],
    this.sortBy = SortBy.relevance,
    this.dateFilter = DateFilter.all,
    this.includeInactive = false,
    this.brand,
    this.year,
    this.sellerRating,
    this.isUsed,
  });

  final String query;
  final String category;
  final double minPrice;
  final double maxPrice;
  final ProductCondition? condition;
  final NegotiationStatus? negotiationStatus;
  final String location;
  final double radius;
  final GeoPoint? userLocation;
  final List<String> tags;
  final SortBy sortBy;
  final DateFilter dateFilter;
  final bool includeInactive;
  final String? brand;
  final int? year;
  final double? sellerRating;
  final bool? isUsed;

  SearchFilters copyWith({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    ProductCondition? condition,
    NegotiationStatus? negotiationStatus,
    String? location,
    double? radius,
    GeoPoint? userLocation,
    List<String>? tags,
    SortBy? sortBy,
    DateFilter? dateFilter,
    bool? includeInactive,
    String? brand,
    int? year,
    double? sellerRating,
    bool? isUsed,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      condition: condition ?? this.condition,
      negotiationStatus: negotiationStatus ?? this.negotiationStatus,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      userLocation: userLocation ?? this.userLocation,
      tags: tags ?? this.tags,
      sortBy: sortBy ?? this.sortBy,
      dateFilter: dateFilter ?? this.dateFilter,
      includeInactive: includeInactive ?? this.includeInactive,
      brand: brand ?? this.brand,
      year: year ?? this.year,
      sellerRating: sellerRating ?? this.sellerRating,
      isUsed: isUsed ?? this.isUsed,
    );
  }

  bool get hasActiveFilters {
    return query.isNotEmpty ||
        category != 'All' ||
        condition != null ||
        negotiationStatus != null ||
        location.isNotEmpty ||
        radius < 25 ||
        tags.isNotEmpty ||
        sortBy != SortBy.relevance ||
        dateFilter != DateFilter.all ||
        brand != null ||
        year != null ||
        sellerRating != null ||
        isUsed != null;
  }

  void clearFilters() {
    // This method is used for UI to reset filters
  }

  // Get filter summary for UI display
  String get filterSummary {
    final List<String> parts = [];
    
    if (query.isNotEmpty) {
      parts.add('"$query"');
    }
    
    if (category != 'All') {
      parts.add(category);
    }
    
    if (condition != null) {
      parts.add(condition!.conditionText);
    }
    
    if (negotiationStatus != null) {
      parts.add(negotiationStatus!.negotiationText);
    }
    
    if (location.isNotEmpty) {
      parts.add(location);
    }

    if (radius < 25) {
      parts.add('${radius.round()} miles');
    }
    
    if (tags.isNotEmpty) {
      parts.add('Tags: ${tags.join(', ')}');
    }
    
    return parts.isEmpty ? 'All items' : parts.join(' • ');
  }

  // Apply filters to Firestore query
  Query<Map<String, dynamic>> applyToQuery(Query<Map<String, dynamic>> baseQuery) {
    Query<Map<String, dynamic>> query = baseQuery;

    // debug: applying filters to Firestore query

    // Apply category filter
    if (category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    // Apply condition filter
    if (condition != null) {
      query = query.where('condition', isEqualTo: condition!.name);
    }

    // Apply negotiation status filter
    if (negotiationStatus != null) {
      query = query.where('negotiationStatus', isEqualTo: negotiationStatus!.name);
    }

    // Apply location filter
    if (location.isNotEmpty) {
      query = query.where('locality', isEqualTo: location);
    }

    // Apply tags filter
    if (tags.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: tags);
    }

    // Apply active status filter
    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }

    // Apply brand filter
    if (brand != null) {
      query = query.where('brand', isEqualTo: brand);
    }

    // Apply year filter
    if (year != null) {
      query = query.where('year', isEqualTo: year);
    }

    // Apply sorting
    switch (sortBy) {
      case SortBy.newest:
        query = query.orderBy('createdAt', descending: true);
        break;
      case SortBy.oldest:
        query = query.orderBy('createdAt', descending: false);
        break;
      case SortBy.mostViewed:
        query = query.orderBy('views', descending: true);
        break;
      case SortBy.mostFavorited:
        query = query.orderBy('favorites', descending: true);
        break;
      case SortBy.nearest:
      case SortBy.relevance:
        // For nearest and relevance, we'll sort by date as default
        query = query.orderBy('createdAt', descending: true);
        break;
    }

    return query;
  }

  @override
  String toString() {
    return 'SearchFilters(query: $query, category: $category, minPrice: $minPrice, maxPrice: $maxPrice, condition: $condition, negotiationStatus: $negotiationStatus, location: $location, radius: $radius, tags: $tags, sortBy: $sortBy, dateFilter: $dateFilter, brand: $brand, year: $year, sellerRating: $sellerRating, isUsed: $isUsed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilters &&
        other.query == query &&
        other.category == category &&
        other.minPrice == minPrice &&
        other.maxPrice == maxPrice &&
        other.condition == condition &&
        other.negotiationStatus == negotiationStatus &&
        other.location == location &&
        other.radius == radius &&
        other.userLocation == userLocation &&
        other.tags.length == tags.length &&
        other.tags.every((tag) => tags.contains(tag)) &&
        other.sortBy == sortBy &&
        other.dateFilter == dateFilter &&
        other.includeInactive == includeInactive &&
        other.brand == brand &&
        other.year == year &&
        other.sellerRating == sellerRating &&
        other.isUsed == isUsed;
  }

  @override
  int get hashCode {
    return Object.hash(
      query,
      category,
      minPrice,
      maxPrice,
      condition,
      negotiationStatus,
      location,
      radius,
      userLocation,
      Object.hashAll(tags),
      sortBy,
      dateFilter,
      includeInactive,
      brand,
      year,
      sellerRating,
      isUsed,
    );
  }
}

enum SortBy {
  relevance,
  newest,
  oldest,
  nearest,
  mostViewed,
  mostFavorited;

  String get name {
    switch (this) {
      case SortBy.relevance:
        return 'relevance';
      case SortBy.newest:
        return 'date_new';
      case SortBy.oldest:
        return 'date_old';
      case SortBy.nearest:
        return 'nearest';
      case SortBy.mostViewed:
        return 'most_viewed';
      case SortBy.mostFavorited:
        return 'most_favorited';
    }
  }
}

enum DateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  lastWeek,
  lastMonth,
}

// Search result model
class SearchResult {
  final String id;
  final String title;
  final String description;
  final double price;
  final List<String> images;
  final String category;
  final ProductCondition condition;
  final NegotiationStatus negotiationStatus;
  final String location;
  final DateTime createdAt;
  final String sellerId;
  final String sellerName;
  final double relevanceScore;
  final double distance; // miles from user location
  final int views;
  final int favorites;
  final String? brand;
  final String? model;
  final int? year;
  final List<String> tags;

  // Getters for backward compatibility
  String get imageUrl => images.isNotEmpty ? images.first : '';
  bool get isUsed => condition == ProductCondition.used;
  
  // Additional getters for UI
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  SearchResult({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.category,
    required this.condition,
    required this.negotiationStatus,
    required this.location,
    required this.createdAt,
    required this.sellerId,
    required this.sellerName,
    this.relevanceScore = 0.0,
    this.distance = 0.0,
    this.views = 0,
    this.favorites = 0,
    this.brand,
    this.model,
    this.year,
    this.tags = const [],
  });

  factory SearchResult.fromFirestore(DocumentSnapshot doc, {double relevanceScore = 0.0, double distance = 0.0}) {
    final data = doc.data() as Map<String, dynamic>;
    return SearchResult(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      images: List<String>.from(data['images'] ?? [data['imageUrl'] ?? '']),
      category: data['category'] ?? '',
      condition: _parseCondition(data['condition'] as String?),
      negotiationStatus: _parseNegotiation(data['negotiationStatus'] as String?),
      location: data['locality'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'Unknown',
      relevanceScore: relevanceScore,
      distance: distance,
      views: (data['views'] as int?) ?? 0,
      favorites: (data['favorites'] as int?) ?? 0,
      brand: data['brand'] as String?,
      model: data['model'] as String?,
      year: data['year'] as int?,
      tags: List<String>.from(data['tags'] ?? []),
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

  factory SearchResult.fromListing(Listing listing, {double relevanceScore = 0.0, double distance = 0.0}) {
    return SearchResult(
      id: listing.id,
      title: listing.title,
      description: listing.description,
      price: listing.price,
      images: listing.images,
      category: listing.category,
      condition: listing.condition,
      negotiationStatus: listing.negotiationStatus,
      location: listing.locality ?? '',
      createdAt: listing.createdAt,
      sellerId: listing.sellerId,
      sellerName: listing.sellerName,
      relevanceScore: relevanceScore,
      distance: distance,
      views: listing.views,
      favorites: listing.favorites,
      brand: listing.brand,
      model: listing.model,
      year: listing.year,
      tags: listing.tags,
    );
  }

  // Get formatted price
  String get formattedPrice => 'Free';

  // Get formatted date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else {
      return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    }
  }

  // Get distance text
  String get distanceText {
    if (distance < 0.1) {
      return '${(distance * 10).toStringAsFixed(1)} miles away';
    } else if (distance < 1) {
      return '${distance.toStringAsFixed(2)} miles away';
    } else if (distance < 10) {
      return '${distance.toStringAsFixed(1)} miles away';
    } else {
      return '${distance.round()} miles away';
    }
  }

  // Get condition text
  String get conditionText => condition.conditionText;

  // Get negotiation text
  String get negotiationText => negotiationStatus.negotiationText;

  // Check if matches date filter
  bool matchesDateFilter(DateFilter filter) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    switch (filter) {
      case DateFilter.today:
        return difference.inDays == 0;
      case DateFilter.thisWeek:
        return difference.inDays <= 7;
      case DateFilter.thisMonth:
        return difference.inDays <= 30;
      case DateFilter.lastWeek:
        return difference.inDays > 7 && difference.inDays <= 14;
      case DateFilter.lastMonth:
        return difference.inDays > 30 && difference.inDays <= 60;
      case DateFilter.all:
        return true;
    }
  }
}

