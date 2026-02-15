import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_repository.dart';
import '../profile/models/user_profile.dart';

class ChatListViewModel extends ChangeNotifier {
  ChatListViewModel() {
    _loadConversations();
  }

  // State
  bool _isLoading = true;
  String? _error;
  List<ChatConversation> _conversations = [];
  List<ChatConversation> _filteredConversations = [];
  String _searchQuery = '';
  StreamSubscription? _conversationsSubscription;

  // Repository
  final ChatRepository _repository = ChatRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Getter for current user ID
  String? get currentUserId => _repository.currentUserId;
  
  // User cache
  final Map<String, UserProfile> _userCache = {};
  
  // Stream subscriptions for real-time updates
  final Map<String, StreamSubscription> _userProfileSubscriptions = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ChatConversation> get conversations => List.unmodifiable(_filteredConversations);
  String get searchQuery => _searchQuery;

  Future<void> _loadConversations() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Listen to real-time conversations
      _conversationsSubscription = _repository
          .streamConversations()
          .listen((conversations) {
        _conversations = conversations;
        _filteredConversations = conversations;
        
        // Load user profiles for all conversations
        _loadAllUserProfiles();
        
        _isLoading = false;
        notifyListeners();
      }, onError: (error) {
        final isPermissionDenied = error.toString().contains('permission-denied') ||
            error.toString().contains('permission_denied');
        if (isPermissionDenied) {
          _conversations = [];
          _filteredConversations = [];
          _error = null;
        } else {
          _error = 'Failed to load conversations: $error';
          _handleError(error);
        }
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = 'Failed to load conversations: $e';
      _isLoading = false;
      notifyListeners();
      
      // Handle error with ErrorService
      _handleError(e);
    }
  }
  
  void _loadAllUserProfiles() {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) return;
    
    for (final conversation in _conversations) {
      final otherUserId = conversation.getOtherParticipantId(currentUserId);
      if (otherUserId != null && otherUserId.isNotEmpty) {
        loadUserProfile(otherUserId);
      }
    }
  }

  void _handleError(dynamic error) {
    if (kDebugMode) {
      debugPrint('ChatList Error: $error');
    }
  }

  void markAsRead(String conversationId) {
    _repository.markMessagesAsRead(conversationId);
  }

  // Get conversation title
  String getConversationTitle(ChatConversation conversation) {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) return 'Unknown User';
    
    final otherUserId = conversation.getOtherParticipantId(currentUserId);
    if (otherUserId == null || otherUserId.isEmpty) return 'Unknown User';
    
    // Always prefer cached user profile (real-time data)
    final cachedProfile = _userCache[otherUserId];
    if (cachedProfile != null) return cachedProfile.displayName;

    // Fallback to display name from conversation document if present
    final nameFromDoc = conversation.getDisplayNameFor(otherUserId);
    if (nameFromDoc != null) return nameFromDoc;

    // Final fallback: sade bir isim göster
    return 'User';
  }

  // Get other participant ID for a conversation
  String? getOtherParticipantId(ChatConversation conversation) {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) return null;
    return conversation.getOtherParticipantId(currentUserId);
  }
  
  Future<void> loadUserProfile(String userId) async {
    // Eğer zaten stream dinliyorsak, tekrar yükleme
    if (_userProfileSubscriptions.containsKey(userId)) return;
    
    try {
      if (kDebugMode) {
        debugPrint('Loading user profile for: $userId');
      }

      // Firestore'dan gerçek zamanlı stream dinle
      _userProfileSubscriptions[userId] = _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final profile = UserProfile(
            id: userId,
            displayName: data['displayName'] ?? 'User',
            email: data['email'] ?? '',
            bio: data['bio'] ?? '',
            location: data['location'] ?? '',
            rating: (data['rating'] ?? 0.0).toDouble(),
            totalSales: data['totalSales'] ?? 0,
            credits: data['credits'] ?? 0,
            isPremium: data['isPremium'] ?? false,
            memberSince: (data['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
            verificationStatus: VerificationStatus.unverified,
            trustLevel: TrustLevel.newUser,
            profileImageUrl: data['profileImageUrl'],
            premiumExpiresAt: (data['premiumExpiresAt'] as Timestamp?)?.toDate(),
          );
          
          if (kDebugMode) {
            debugPrint('User profile updated: ${profile.displayName}');
          }
          _userCache[userId] = profile;
          notifyListeners(); // Update UI with real names
        } else {
          if (kDebugMode) {
            debugPrint('User profile not found for: $userId, creating fallback');
          }
          final fallbackProfile = UserProfile(
            id: userId,
            displayName: 'User ${userId.length > 8 ? userId.substring(0, 8) : userId}',
            email: '',
            bio: '',
            location: '',
            rating: 0.0,
            totalSales: 0,
            credits: 0,
            isPremium: false,
            memberSince: DateTime.now(),
            verificationStatus: VerificationStatus.unverified,
            trustLevel: TrustLevel.newUser,
          );
          _userCache[userId] = fallbackProfile;
          notifyListeners();
        }
      }, onError: (error) {
        if (kDebugMode) {
          debugPrint('Failed to load user profile for $userId: $error');
        }
        
        // Hata durumunda da fallback oluştur
        final fallbackProfile = UserProfile(
          id: userId,
          displayName: 'User ${userId.length > 8 ? userId.substring(0, 8) : userId}',
          email: '',
          bio: '',
          location: '',
          rating: 0.0,
          totalSales: 0,
          credits: 0,
          isPremium: false,
          memberSince: DateTime.now(),
          verificationStatus: VerificationStatus.unverified,
          trustLevel: TrustLevel.newUser,
        );
        _userCache[userId] = fallbackProfile;
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load user profile for $userId: $e');
      }
      
      // Hata durumunda da fallback oluştur
      final fallbackProfile = UserProfile(
        id: userId,
        displayName: 'User ${userId.length > 8 ? userId.substring(0, 8) : userId}',
        email: '',
        bio: '',
        location: '',
        rating: 0.0,
        totalSales: 0,
        credits: 0,
        isPremium: false,
        memberSince: DateTime.now(),
        verificationStatus: VerificationStatus.unverified,
        trustLevel: TrustLevel.newUser,
      );
      _userCache[userId] = fallbackProfile;
      notifyListeners();
    }
  }

  // Get unread count for conversation
  int getUnreadCount(ChatConversation conversation) {
    final uid = currentUserId;
    if (uid == null) return 0;
    final raw = conversation.unreadCounts[uid];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  // Search functionality
  void searchConversations(String query) {
    _searchQuery = query.toLowerCase();
    
    if (_searchQuery.isEmpty) {
      _filteredConversations = _conversations;
    } else {
      _filteredConversations = _conversations.where((conversation) {
        // Find the other user ID (not the current user)
        final currentUserId = this.currentUserId;
        final otherUserId = conversation.participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => conversation.participants.isNotEmpty 
              ? conversation.participants.first 
              : '',
        );
        
        final userProfile = _userCache[otherUserId];
        final userName = userProfile?.displayName ?? 'Unknown User';
        
        return userName.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    
    notifyListeners();
  }
  
  void clearSearch() {
    _searchQuery = '';
    _filteredConversations = _conversations;
    notifyListeners();
  }

  // Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      _error = null;
      notifyListeners();
      
      // Optimistically remove from local lists first for better UX
      _conversations.removeWhere((conv) => conv.id == conversationId);
      _filteredConversations.removeWhere((conv) => conv.id == conversationId);
      notifyListeners();
      
      // Then delete from Firestore
      await _repository.deleteConversation(conversationId);
      
    } catch (e, stackTrace) {
      debugPrint('Error deleting conversation: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to delete conversation: ${e.toString()}';
      
      // Reload conversations to restore correct state
      _loadConversations();
      
      // Handle error with ErrorService
      _handleError(e);
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions to prevent memory leaks
    _conversationsSubscription?.cancel();
    _conversationsSubscription = null;
    
    // Cancel user profile subscriptions
    for (final subscription in _userProfileSubscriptions.values) {
      subscription.cancel();
    }
    _userProfileSubscriptions.clear();
    
    // Clear caches and data
    _userCache.clear();
    _conversations.clear();
    _filteredConversations.clear();
    
    super.dispose();
  }
}


