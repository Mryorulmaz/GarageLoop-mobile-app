import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/listing.dart';

class HomeRepository {
  static const String _collection = 'listings';

  Stream<List<Listing>> listenListings({String? state, String? city}) {
    try {
      Query query = FirebaseFirestore.instance
          .collection(_collection)
          .where('isActive', isEqualTo: true);
      
      // Add state filter if provided
      if (state != null && state.isNotEmpty) {
        query = query.where('state', isEqualTo: state);
      }
      
      // Add city filter if provided
      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }
      
      return query
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((QuerySnapshot snapshot) {
        return snapshot.docs.map((DocumentSnapshot doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Listing.fromFirestore(doc.id, data);
        }).toList();
      }).handleError((error) {
        debugPrint('Firestore query error: $error');
        return <Listing>[];
      });
    } catch (e) {
      debugPrint('Firestore initialization error: $e');
      return Stream.value(<Listing>[]);
    }
  }

  static double distanceMiles(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 3959; // miles
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    final double lat1Rad = _toRadians(lat1);
    final double lat2Rad = _toRadians(lat2);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180);
}


