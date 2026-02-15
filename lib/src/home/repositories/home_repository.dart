import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import '../models/home_product.dart';
import '../../core/data/us_state_codes.dart';

class HomeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Position? _userPosition;

  // Optional filters (server-side where conditions)
  String? _stateFilter; // e.g., "New York"
  String? _cityFilter;  // e.g., "Buffalo"
  GeoPoint? _center;    // optional geo center
  double _radiusMiles = 15.0; // optional radius for bounding box

  Stream<List<HomeProduct>> listenListings() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('listings')
        .where('isActive', isEqualTo: true)
        .limit(50); // fetch a bit more to be safe

    // Apply normalized state/city filters when available
    if (_stateFilter != null && _stateFilter!.trim().isNotEmpty) {
      final String stateName = _stateFilter!.trim();
      final String? stateCode = USStateCodes.toCode(stateName);
      final List<String> allowedStates = stateCode == null
          ? <String>[stateName]
          : <String>[stateName, stateCode];
      // Support both full name and 2-letter code
      query = query.where('state', whereIn: allowedStates.length > 1 ? allowedStates : null, isEqualTo: allowedStates.length == 1 ? stateName : null);
    }
    // Şehir alanı bazı kayıtlarda eksik olabildiği için server-side şehir eşitliğini zorlamıyoruz.
    // City eşleşmesini client-side’da locality/address üzerinden yapacağız.

    // Optional geo bounding box (approx rectangle)
    if (_center != null) {
      final _Bounds b = _computeBoundingBox(_center!, _radiusMiles);
      query = query
          .where('location', isGreaterThanOrEqualTo: GeoPoint(b.swLat, b.swLng))
          .where('location', isLessThanOrEqualTo: GeoPoint(b.neLat, b.neLng));
    }

    return query.snapshots().map((snapshot) {
      final List<HomeProduct> items = snapshot.docs.map((doc) {
        final data = doc.data();

        // Read lat/lng if any
        double? productLat, productLng;
        final GeoPoint? location = data['location'] as GeoPoint?;
        if (location != null) {
          productLat = location.latitude;
          productLng = location.longitude;
        } else {
          productLat = (data['latitude'] as num?)?.toDouble();
          productLng = (data['longitude'] as num?)?.toDouble();
        }

        final String? locality = data['locality'] as String? ?? data['address'] as String?;

        return HomeProduct(
          id: doc.id,
          title: (data['title'] as String?) ?? '',
          price: ((data['price'] as num?) ?? 0).toDouble(),
          priceText: 'Free',
          imageUrl: (data['images'] is List && (data['images'] as List).isNotEmpty)
              ? (data['images'] as List).first as String
              : 'https://via.placeholder.com/400x300/cccccc/666666?text=No+Image',
          distanceMiles: _calculateDistance(productLat, productLng),
          isUsed: data['condition'] == 'used',
          category: (data['category'] as String?) ?? 'Other',
          createdAt: (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(0),
          sellerName: data['sellerName'] as String?,
          condition: data['condition'] as String?,
          locality: locality,
        );
      }).toList();

      // Client-side city fallback: if _cityFilter is set but server-side didn't filter (due to missing field),
      // then filter by either 'city' field or containment in 'locality/address'.
      if (_cityFilter != null && _cityFilter!.trim().isNotEmpty) {
        final String target = _cityFilter!.toLowerCase();
        items.retainWhere((p) {
          final String loc = (p.locality ?? '').toLowerCase();
          return loc.contains(target);
        });
      }
      // Client-side sort to avoid Firestore composite index requirements when combined with where filters
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  // Set normalized state/city filters
  void setStateCityFilter({String? state, String? city}) {
    _stateFilter = state;
    _cityFilter = city;
  }

  // Set optional geo center + radius
  void setGeoFilter({required GeoPoint center, double radiusMiles = 15.0}) {
    _center = center;
    _radiusMiles = radiusMiles;
  }

  void clearLocationFilters() {
    _stateFilter = null;
    _cityFilter = null;
    _center = null;
  }

  Future<void> setUserLocation(Position position) async {
    _userPosition = position;
  }

  double _calculateDistance(double? productLat, double? productLng) {
    if (_userPosition == null || productLat == null || productLng == null) {
      return 0.0;
    }
    final distance = Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          productLat,
          productLng,
        ) * 0.000621371; // meters -> miles
    return distance;
  }

  // One-off maintenance: fill missing city/state/location fields for listings
  Future<int> normalizeLocationFields({int limit = 200}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('listings')
        .limit(limit)
        .get();

    int updated = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();

      String? city = data['city'] as String?;
      String? state = data['state'] as String?;
      GeoPoint? loc = data['location'] as GeoPoint?;

      // Try to derive from address/locality if missing
      if ((city == null || city.isEmpty) || (state == null || state.isEmpty)) {
        final String? addr = (data['address'] as String?) ?? (data['locality'] as String?);
        if (addr != null && addr.contains(',')) {
          final parts = addr.split(',');
          if (parts.isNotEmpty) {
            city ??= parts.first.trim();
          }
          if (parts.length > 1) {
            state ??= parts[1].trim();
          }
        }
      }

      // If still missing and we have lat/lng fields, construct GeoPoint
      loc ??= data['location'] as GeoPoint?;
      loc ??= ((data['latitude'] != null && data['longitude'] != null)
          ? GeoPoint((data['latitude'] as num).toDouble(), (data['longitude'] as num).toDouble())
          : null);

      // If still missing city/state, try reverse geocoding
      if ((city == null || state == null) && loc != null) {
        try {
          final placemarks = await geocoding.placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            city ??= p.locality;
            state ??= p.administrativeArea;
          }
        } catch (_) {
          // ignore
        }
      }

      final Map<String, Object?> updates = <String, Object?>{};
      if (loc != null && data['location'] == null) {
        updates['location'] = loc;
      }
      if (city != null && city.isNotEmpty && data['city'] != city) {
        updates['city'] = city;
      }
      if (state != null && state.isNotEmpty && data['state'] != state) {
        updates['state'] = state;
      }

      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
        updated++;
      }
    }

    return updated;
  }
}

class _Bounds {
  _Bounds({required this.swLat, required this.swLng, required this.neLat, required this.neLng});
  final double swLat;
  final double swLng;
  final double neLat;
  final double neLng;
}

_Bounds _computeBoundingBox(GeoPoint center, double radiusMiles) {
  const double milesPerDegreeLat = 69.0; // approx
  final double latDelta = radiusMiles / milesPerDegreeLat;
  final double cosLat = math.cos(center.latitude * math.pi / 180.0).abs();
  final double milesPerDegreeLng = (cosLat < 0.1 ? 0.1 : cosLat) * 69.0;
  final double lngDelta = radiusMiles / milesPerDegreeLng;

  final double swLat = center.latitude - latDelta;
  final double swLng = center.longitude - lngDelta;
  final double neLat = center.latitude + latDelta;
  final double neLng = center.longitude + lngDelta;
  return _Bounds(swLat: swLat, swLng: swLng, neLat: neLat, neLng: neLng);
}
