import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../../core/services/image_optimization_service.dart';

class UserProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImageOptimizationService _imageOptimizer = ImageOptimizationService();

  static const String _collection = 'users';

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    if (userId.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('Failed to get user profile: Invalid argument(s): A document path must be a non-empty string');
      }
      return null;
    }
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get user profile: $e');
      }
      return null;
    }
  }

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return await getUserProfile(userId);
  }

  // Create user profile
  Future<UserProfile?> createUserProfile({
    required String displayName,
    required String email,
    String? profileImageUrl,
    String? bio,
    String? location,
    DateTime? dateOfBirth,
    String? gender,
    List<String>? interests,
    Map<String, dynamic>? preferences,
  }) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final now = DateTime.now();
      final profile = UserProfile(
        id: userId,
        displayName: displayName,
        email: email,
        bio: bio ?? '',
        location: location ?? '',
        rating: 0.0,
        totalSales: 0,
        credits: 3,
        isPremium: false,
        memberSince: now,
        verificationStatus: VerificationStatus.unverified,
        trustLevel: TrustLevel.newUser,
        profileImageUrl: profileImageUrl,
        dateOfBirth: dateOfBirth,
      );

      await _firestore
          .collection(_collection)
          .doc(userId)
          .set(profile.toFirestore());

      return profile;
    } catch (e) {
      debugPrint('Failed to create user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<UserProfile?> updateUserProfile({
    String? displayName,
    String? email,
    String? profileImageUrl,
    String? bio,
    String? location,
    DateTime? dateOfBirth,
    String? gender,
    List<String>? interests,
    Map<String, dynamic>? preferences,
  }) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final currentProfile = await getUserProfile(userId);
      if (currentProfile == null) return null;

      final updatedProfile = currentProfile.copyWith(
        displayName: displayName,
        email: email,
        profileImageUrl: profileImageUrl,
        bio: bio,
        location: location,
        dateOfBirth: dateOfBirth,
      );

      await _firestore
          .collection(_collection)
          .doc(userId)
          .update(updatedProfile.toFirestore());

      return updatedProfile;
    } catch (e) {
      debugPrint('Failed to update user profile: $e');
      return null;
    }
  }

  // Upload profile photo
  Future<String?> uploadProfilePhoto(File imageFile) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      // Optimize image
      final optimizedFile = await _imageOptimizer.optimizeImageFromFile(imageFile);
      if (optimizedFile == null) return null;

      // Upload to Firebase Storage
      final path = 'profile_photos/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(path);
      
      await ref.putFile(optimizedFile);
      final downloadUrl = await ref.getDownloadURL();

      // Update profile with new photo URL
      await updateUserProfile(profileImageUrl: downloadUrl);

      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload profile photo: $e');
      return null;
    }
  }

  // Delete profile photo
  Future<bool> deleteProfilePhoto() async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await updateUserProfile(profileImageUrl: null);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to delete profile photo: $e');
      }
      return false;
    }
  }

  // Update user preferences
  Future<bool> updatePreferences(Map<String, dynamic> preferences) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await _firestore
          .collection(_collection)
          .doc(userId)
          .update({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update preferences: $e');
      }
      return false;
    }
  }

  // Add interest
  Future<bool> addInterest(String interest) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await _firestore
          .collection(_collection)
          .doc(userId)
          .update({
        'interests': FieldValue.arrayUnion([interest]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to add interest: $e');
      }
      return false;
    }
  }

  // Remove interest
  Future<bool> removeInterest(String interest) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await _firestore
          .collection(_collection)
          .doc(userId)
          .update({
        'interests': FieldValue.arrayRemove([interest]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to remove interest: $e');
      }
      return false;
    }
  }

  // Update user stats
  Future<bool> updateUserStats({
    int? totalListings,
    int? totalSales,
    int? rating,
    int? totalReviews,
  }) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (totalListings != null) updates['totalListings'] = totalListings;
      if (totalSales != null) updates['totalSales'] = totalSales;
      if (rating != null) updates['rating'] = rating;
      if (totalReviews != null) updates['totalReviews'] = totalReviews;

      await _firestore
          .collection(_collection)
          .doc(userId)
          .update(updates);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update user stats: $e');
      }
      return false;
    }
  }

  // Search users
  Future<List<UserProfile>> searchUsers({
    String? query,
    String? location,
    List<String>? interests,
    int limit = 20,
  }) async {
    try {
      Query queryRef = _firestore.collection(_collection);

      if (query != null && query.isNotEmpty) {
        queryRef = queryRef.where('displayName', isGreaterThanOrEqualTo: query)
                          .where('displayName', isLessThan: '$query\uf8ff');
      }

      if (location != null && location.isNotEmpty) {
        queryRef = queryRef.where('location', isEqualTo: location);
      }

      if (interests != null && interests.isNotEmpty) {
        queryRef = queryRef.where('interests', arrayContainsAny: interests);
      }

      final snapshot = await queryRef.limit(limit).get();
      return snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
      debugPrint('Failed to search users: $e');
      }
      return [];
    }
  }

  // Delete user profile
  Future<bool> deleteUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await _firestore.collection(_collection).doc(userId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to delete user profile: $e');
      }
      return false;
    }
  }
}
