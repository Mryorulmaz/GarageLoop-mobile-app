import 'package:cloud_firestore/cloud_firestore.dart';

enum VerificationStatus {
  unverified,
  emailVerified,
  phoneVerified,
  idVerified,
  fullyVerified,
}

enum TrustLevel {
  newUser,
  trusted,
  verified,
  premium,
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.bio,
    required this.location,
    required this.rating,
    required this.totalSales,
    required this.credits,
    required this.isPremium,
    required this.memberSince,
    required this.verificationStatus,
    required this.trustLevel,
    this.profileImageUrl,
    this.phoneNumber,
    this.dateOfBirth,
    this.preferredContactMethod,
    this.safetyPreferences = const {},
    this.blockedUsers = const [],
    this.reportedCount = 0,
    this.lastActive,
    this.isOnline = false,
    this.preferredMeetingSpots = const [],
    this.responseTime,
    this.completionRate = 0.0,
    this.positiveReviews = 0,
    this.neutralReviews = 0,
    this.negativeReviews = 0,
    this.premiumExpiresAt,
  });

  final String id;
  final String displayName;
  final String email;
  final String bio;
  final String location;
  final double rating;
  final int totalSales;
  final int credits;
  final bool isPremium;
  final DateTime memberSince;
  final VerificationStatus verificationStatus;
  final TrustLevel trustLevel;
  final String? profileImageUrl;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final String? preferredContactMethod;
  final Map<String, dynamic> safetyPreferences;
  final List<String> blockedUsers;
  final int reportedCount;
  final DateTime? lastActive;
  final bool isOnline;
  final List<String> preferredMeetingSpots;
  final Duration? responseTime;
  final double completionRate;
  final int positiveReviews;
  final int neutralReviews;
  final int negativeReviews;
  final DateTime? premiumExpiresAt;

  // Computed properties
  int get totalReviews => positiveReviews + neutralReviews + negativeReviews;
  
  double get positiveReviewPercentage {
    if (totalReviews == 0) return 0.0;
    return (positiveReviews / totalReviews) * 100;
  }

  String get verificationBadge {
    switch (verificationStatus) {
      case VerificationStatus.unverified:
        return '';
      case VerificationStatus.emailVerified:
        return '✓ Email';
      case VerificationStatus.phoneVerified:
        return '✓ Phone';
      case VerificationStatus.idVerified:
        return '✓ ID Verified';
      case VerificationStatus.fullyVerified:
        return '✓ Fully Verified';
    }
  }

  String get trustBadge {
    switch (trustLevel) {
      case TrustLevel.newUser:
        return 'New User';
      case TrustLevel.trusted:
        return 'Trusted';
      case TrustLevel.verified:
        return 'Verified';
      case TrustLevel.premium:
        return 'Premium';
    }
  }

  bool get isVerified => verificationStatus != VerificationStatus.unverified;
  bool get isFullyVerified => verificationStatus == VerificationStatus.fullyVerified;
  bool get isTrusted => trustLevel != TrustLevel.newUser;

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserProfile(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      location: data['location'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalSales: data['totalSales'] ?? 0,
      credits: data['credits'] ?? 0,
      isPremium: data['isPremium'] ?? false,
      memberSince: (data['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verificationStatus: _parseVerificationStatus(data['verificationStatus']),
      trustLevel: _parseTrustLevel(data['trustLevel']),
      profileImageUrl: data['profileImageUrl'],
      phoneNumber: data['phoneNumber'],
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
      preferredContactMethod: data['preferredContactMethod'],
      safetyPreferences: Map<String, dynamic>.from(data['safetyPreferences'] ?? {}),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      reportedCount: data['reportedCount'] ?? 0,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      isOnline: data['isOnline'] ?? false,
      preferredMeetingSpots: List<String>.from(data['preferredMeetingSpots'] ?? []),
      responseTime: data['responseTime'] != null 
          ? Duration(minutes: data['responseTime']) 
          : null,
      completionRate: (data['completionRate'] ?? 0.0).toDouble(),
      positiveReviews: data['positiveReviews'] ?? 0,
      neutralReviews: data['neutralReviews'] ?? 0,
      negativeReviews: data['negativeReviews'] ?? 0,
      premiumExpiresAt: (data['premiumExpiresAt'] as Timestamp?)?.toDate(),
    );
  }

  static VerificationStatus _parseVerificationStatus(String? status) {
    switch (status) {
      case 'emailVerified':
        return VerificationStatus.emailVerified;
      case 'phoneVerified':
        return VerificationStatus.phoneVerified;
      case 'idVerified':
        return VerificationStatus.idVerified;
      case 'fullyVerified':
        return VerificationStatus.fullyVerified;
      default:
        return VerificationStatus.unverified;
    }
  }

  static TrustLevel _parseTrustLevel(String? level) {
    switch (level) {
      case 'trusted':
        return TrustLevel.trusted;
      case 'verified':
        return TrustLevel.verified;
      case 'premium':
        return TrustLevel.premium;
      default:
        return TrustLevel.newUser;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'location': location,
      'rating': rating,
      'totalSales': totalSales,
      'credits': credits,
      'isPremium': isPremium,
      'memberSince': Timestamp.fromDate(memberSince),
      'verificationStatus': verificationStatus.name,
      'trustLevel': trustLevel.name,
      'profileImageUrl': profileImageUrl,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'preferredContactMethod': preferredContactMethod,
      'safetyPreferences': safetyPreferences,
      'blockedUsers': blockedUsers,
      'reportedCount': reportedCount,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'isOnline': isOnline,
      'preferredMeetingSpots': preferredMeetingSpots,
      'responseTime': responseTime?.inMinutes,
      'completionRate': completionRate,
      'positiveReviews': positiveReviews,
      'neutralReviews': neutralReviews,
      'negativeReviews': negativeReviews,
      'premiumExpiresAt': premiumExpiresAt != null ? Timestamp.fromDate(premiumExpiresAt!) : null,
    };
  }

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? bio,
    String? location,
    double? rating,
    int? totalSales,
    int? credits,
    bool? isPremium,
    DateTime? memberSince,
    VerificationStatus? verificationStatus,
    TrustLevel? trustLevel,
    String? profileImageUrl,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? preferredContactMethod,
    Map<String, dynamic>? safetyPreferences,
    List<String>? blockedUsers,
    int? reportedCount,
    DateTime? lastActive,
    bool? isOnline,
    List<String>? preferredMeetingSpots,
    Duration? responseTime,
    double? completionRate,
    int? positiveReviews,
    int? neutralReviews,
    int? negativeReviews,
    DateTime? premiumExpiresAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      totalSales: totalSales ?? this.totalSales,
      credits: credits ?? this.credits,
      isPremium: isPremium ?? this.isPremium,
      memberSince: memberSince ?? this.memberSince,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      trustLevel: trustLevel ?? this.trustLevel,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredContactMethod: preferredContactMethod ?? this.preferredContactMethod,
      safetyPreferences: safetyPreferences ?? this.safetyPreferences,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      reportedCount: reportedCount ?? this.reportedCount,
      lastActive: lastActive ?? this.lastActive,
      isOnline: isOnline ?? this.isOnline,
      preferredMeetingSpots: preferredMeetingSpots ?? this.preferredMeetingSpots,
      responseTime: responseTime ?? this.responseTime,
      completionRate: completionRate ?? this.completionRate,
      positiveReviews: positiveReviews ?? this.positiveReviews,
      neutralReviews: neutralReviews ?? this.neutralReviews,
      negativeReviews: negativeReviews ?? this.negativeReviews,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, displayName: $displayName, email: $email, rating: $rating, verificationStatus: $verificationStatus, trustLevel: $trustLevel)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
