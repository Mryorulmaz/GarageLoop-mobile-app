import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/search_filters.dart';

class SearchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collection = 'listings';

  // Search listings with filters
  Future<List<SearchResult>> searchListings(SearchFilters filters) async {
    try {
      // starting search with filters
      
      Query<Map<String, dynamic>> query = _firestore.collection(_collection);
      
      // Apply filters to query
      query = filters.applyToQuery(query);

      // executing Firestore query
      // Get results
      final snapshot = await query.limit(50).get();
      // found ${snapshot.docs.length} documents
      
      List<SearchResult> results = [];

      for (final doc in snapshot.docs) {
        
        double relevanceScore = 0.0;
        double distance = 0.0;

        // Calculate relevance score if query is provided
        if (filters.query.isNotEmpty) {
          relevanceScore = _calculateRelevanceScore(doc.data(), filters.query);
        }

        // Calculate distance if user location is provided
        if (filters.userLocation != null) {
          final listingLocation = doc.data()['location'] as GeoPoint?;
          if (listingLocation != null) {
            distance = _calculateDistance(
              filters.userLocation!.latitude,
              filters.userLocation!.longitude,
              listingLocation.latitude,
              listingLocation.longitude,
            );
          }
        }

        results.add(SearchResult.fromFirestore(
          doc,
          relevanceScore: relevanceScore,
          distance: distance,
        ));
      }

      // Sort by relevance if query is provided (lightweight)
      if (filters.query.isNotEmpty) {
        results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      }

      // Note: Price filtering is now handled server-side in SearchFilters.applyToQuery()
      // Distance filtering will be handled server-side when geo index is added

      // final results count: ${results.length}
      return results;
    } catch (e) {
      if (kDebugMode) {
        // Search failed
      }
      return [];
    }
  }

  // Search with text query
  Future<List<SearchResult>> searchByText(String query) async {
    try {
      // Simple text search - in a real app, you'd use Algolia or similar
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      List<SearchResult> results = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final title = (data['title'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        final category = (doc.data()['category'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();

        // Check if query matches title, description, or category
        if (title.contains(searchQuery) ||
            description.contains(searchQuery) ||
            category.contains(searchQuery)) {
          
          final relevanceScore = _calculateRelevanceScore(data, query);
          results.add(SearchResult.fromFirestore(doc, relevanceScore: relevanceScore));
        }
      }

      // Sort by relevance
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return results;
    } catch (e) {
      if (kDebugMode) {
        // Text search failed
      }
      return [];
    }
  }

  // Get trending searches
  Future<List<String>> getTrendingSearches() async {
    try {
      // In a real app, you'd track search analytics
      // For now, return some popular categories
      return [
        'Electronics',
        'Furniture',
        'Clothing',
        'Books',
        'Sports',
        'Toys',
        'Home & Garden',
        'Automotive',
      ];
    } catch (e) {
      if (kDebugMode) {
        // Failed to get trending searches
      }
      return [];
    }
  }

  // Get search suggestions
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      if (query.isEmpty) return [];

      // Get recent searches from user's history
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('search_history')
            .where('query', isGreaterThanOrEqualTo: query)
          .where('query', isLessThan: '$query\uf8ff')
            .orderBy('query')
            .limit(5)
            .get();

        return snapshot.docs.map((doc) => doc.data()['query'] as String).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        // Failed to get search suggestions
      }
      return [];
    }
  }

  // Save search to history
  Future<void> saveSearchToHistory(String query) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null && query.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('search_history')
            .add({
          'query': query,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        // Failed to save search to history
      }
    }
  }

  // Get recent searches
  Future<List<String>> getRecentSearches() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('search_history')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => doc.data()['query'] as String).toList();
    } catch (e) {
      if (kDebugMode) {
        // Failed to get recent searches
      }
      return [];
    }
  }

  // Clear search history
  Future<void> clearSearchHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('search_history')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        // Failed to clear search history
      }
    }
  }

  // Get user's current location
  Future<GeoPoint?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      if (kDebugMode) {
        // Failed to get current location
      }
      return null;
    }
  }

  // Calculate relevance score for search results
  double _calculateRelevanceScore(Map<String, dynamic> data, String query) {
    final title = (data['title'] ?? '').toString().toLowerCase();
    final description = (data['description'] ?? '').toString().toLowerCase();
    final category = (data['category'] ?? '').toString().toLowerCase();
    final tags = List<String>.from(data['tags'] ?? []);
    final searchQuery = query.toLowerCase();

    double score = 0.0;

    // Title match (highest weight)
    if (title.contains(searchQuery)) {
      score += 10.0;
      // Exact match bonus
      if (title == searchQuery) score += 5.0;
    }

    // Description match
    if (description.contains(searchQuery)) {
      score += 3.0;
    }

    // Category match
    if (category.contains(searchQuery)) {
      score += 2.0;
    }

    // Tags match
    for (final tag in tags) {
      if (tag.toLowerCase().contains(searchQuery)) {
        score += 1.0;
      }
    }

    // Recency bonus (newer items get higher score)
    final createdAt = data['createdAt'] as Timestamp?;
    if (createdAt != null) {
      final daysSinceCreation = DateTime.now().difference(createdAt.toDate()).inDays;
      if (daysSinceCreation <= 7) {
        score += 2.0;
      } else if (daysSinceCreation <= 30) {
        score += 1.0;
      }
    }

    return score;
  }

  // Calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  // Stream search results for real-time updates
  Stream<List<SearchResult>> streamSearchResults(SearchFilters filters) {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(_collection);
      query = filters.applyToQuery(query);

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          double relevanceScore = 0.0;
          double distance = 0.0;

          if (filters.query.isNotEmpty) {
            relevanceScore = _calculateRelevanceScore(doc.data(), filters.query);
          }

          if (filters.userLocation != null) {
            final listingLocation = doc.data()['location'] as GeoPoint?;
            if (listingLocation != null) {
              distance = _calculateDistance(
                filters.userLocation!.latitude,
                filters.userLocation!.longitude,
                listingLocation.latitude,
                listingLocation.longitude,
              );
            }
          }

          return SearchResult.fromFirestore(
            doc,
            relevanceScore: relevanceScore,
            distance: distance,
          );
        }).toList();
      });
    } catch (e) {
      if (kDebugMode) {
        // Failed to stream search results
      }
      return Stream.value([]);
    }
  }
}
