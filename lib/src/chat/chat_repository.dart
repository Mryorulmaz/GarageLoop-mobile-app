import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'chat_view_model.dart';
import '../core/services/notification_service.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Conversations (chats) collection
  static const String _chatsCollection = 'chats';
  static const String _messagesCollection = 'messages';

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Find existing conversation between two users without creating a new one
  Future<String?> findExistingConversation(String otherUserId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return null;
    }

    // Create conversation ID (sorted to ensure consistency)
    final participants = [currentUserId, otherUserId]..sort();
    final conversationId = participants.join('_');
    final legacyConversationId = '${currentUserId}_$otherUserId';
    final legacyConversationIdReversed = '${otherUserId}_$currentUserId';

    try {
      // Check if conversation exists (sorted format)
      // Use get() with GetOptions to handle permission errors gracefully
      try {
        final doc = await _firestore.collection(_chatsCollection).doc(conversationId).get();
        if (doc.exists) {
          return conversationId;
        }
      } catch (e) {
        // Permission denied or other error - conversation doesn't exist or can't access
        debugPrint('Error checking conversation $conversationId: $e');
      }
      
      // Check legacy formats
      try {
        final legacyDoc = await _firestore.collection(_chatsCollection).doc(legacyConversationId).get();
        if (legacyDoc.exists) {
          return legacyConversationId;
        }
      } catch (e) {
        debugPrint('Error checking legacy conversation $legacyConversationId: $e');
      }
      
      try {
        final legacyDocRev = await _firestore.collection(_chatsCollection).doc(legacyConversationIdReversed).get();
        if (legacyDocRev.exists) {
          return legacyConversationIdReversed;
        }
      } catch (e) {
        debugPrint('Error checking legacy conversation reversed $legacyConversationIdReversed: $e');
      }

      return null; // No existing conversation found
    } catch (e) {
      debugPrint('Error finding existing conversation: $e');
      return null;
    }
  }

  // Create or get conversation between two users
  Future<String> createOrGetConversation(String otherUserId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Create conversation ID (sorted to ensure consistency)
    final participants = [currentUserId, otherUserId]..sort();
    final conversationId = participants.join('_');
    final legacyConversationId = '${currentUserId}_$otherUserId';
    final legacyConversationIdReversed = '${otherUserId}_$currentUserId';

    try {
      // If a legacy conversation exists, prefer it (to surface old messages)
      final legacyDoc = await _firestore.collection(_chatsCollection).doc(legacyConversationId).get();
      if (legacyDoc.exists) {
        return legacyConversationId;
      }
      final legacyDocRev = await _firestore.collection(_chatsCollection).doc(legacyConversationIdReversed).get();
      if (legacyDocRev.exists) {
        return legacyConversationIdReversed;
      }

      // Check if conversation already exists
      try {
        final existingDoc = await _firestore.collection(_chatsCollection).doc(conversationId).get();
        if (existingDoc.exists) {
          // Conversation exists, return it
          return conversationId;
        }
      } catch (e) {
        // Permission denied or other error - will create new conversation
        debugPrint('Error checking existing conversation: $e');
      }

      // Prepare display names map for participants (prefer Firestore profile names)
      final String currentUserName = _auth.currentUser?.displayName ??
          (_auth.currentUser?.email?.split('@').first ?? 'User');
      String otherName = 'User';
      try {
        final otherDoc = await _firestore.collection('users').doc(otherUserId).get();
        final map = otherDoc.data();
        final dn = (map?['displayName'] as String?)?.trim();
        if (dn != null && dn.isNotEmpty) otherName = dn;
      } catch (_) {}

      // Create new conversation (use create instead of merge)
      await _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .set({
        'participants': participants,
        'displayNames': { currentUserId: currentUserName, otherUserId: otherName },
        'lastMessage': null,
        'lastMessageSenderId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      return conversationId;
    } catch (e) {
      throw Exception('Failed to create conversation: $e');
    }
  }

  // Stream conversations for current user
  Stream<List<ChatConversation>> streamConversations() {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_chatsCollection)
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatConversation.fromFirestore(doc.id, data);
      }).toList();
      items.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return items;
    });
  }

  // Stream messages for a conversation with performance optimizations
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _firestore
        .collection(_chatsCollection)
        .doc(conversationId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: true) // newest first for efficient limit
        .limit(20) // Reduced limit for better performance
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
      // Reverse to show oldest at top, newest at bottom in UI
      return items.reversed.toList();
    });
  }

  // Fetch older messages for pagination
  Future<List<ChatMessage>> fetchOlderMessages(
    String conversationId,
    DateTime before,
    {int limit = 50}
  ) async {
    final query = await _firestore
        .collection(_chatsCollection)
        .doc(conversationId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();

    final items = query.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
    return items.reversed.toList();
  }

  // Send message with enhanced support for different message types
  Future<void> sendMessage(
    String conversationId,
    String content,
    MessageType type, {
    String? imageUrl,
    GeoPoint? location,
    double? offerAmount,
    Map<String, dynamic>? meetingDetails,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final messageData = {
      'content': content,
      'senderId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.name,
      'isRead': false,
      'isDelivered': true, // Mesaj gönderildiğinde delivered olarak işaretle
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (location != null) 'location': location,
      if (offerAmount != null) 'offerAmount': offerAmount,
      if (meetingDetails != null) 'meetingDetails': meetingDetails,
    };

    try {
      // Use batch operations for better performance
      final batch = _firestore.batch();
      
      // Add message to conversation
      final messageRef = _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .doc(messageId);
      batch.set(messageRef, messageData);

      // Update conversation with last message
      final conversationRef = _firestore.collection(_chatsCollection).doc(conversationId);
      batch.set(conversationRef, {
        'lastMessage': content,
        'lastMessageSenderId': currentUserId,
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Commit batch first for immediate UI update
      await batch.commit();

      // Send notification and update unread count asynchronously
      _sendMessageNotification(conversationId, content, currentUserId).catchError((e) {
        debugPrint('Notification error: $e');
      });
      
      _updateUnreadCount(conversationId, currentUserId).catchError((e) {
        debugPrint('Unread count error: $e');
      });
      
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      // Delete the message
      await _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete();

      // Update conversation's last message after deletion
      await _updateConversationLastMessage(conversationId);
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // Update conversation's last message manually
  Future<void> updateConversationLastMessage(
    String conversationId,
    String content,
    String senderId,
    DateTime timestamp,
  ) async {
    try {
      await _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .update({
        'lastMessage': content,
        'lastMessageSenderId': senderId,
        'lastMessageAt': Timestamp.fromDate(timestamp),
      });
    } catch (e) {
      debugPrint('Failed to update conversation last message: $e');
    }
  }

  // Update conversation's last message after a message is deleted
  Future<void> _updateConversationLastMessage(String conversationId) async {
    try {
      // Get all remaining messages in the conversation
      final messagesSnapshot = await _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        // Update with the most recent message
        final lastMessage = messagesSnapshot.docs.first;
        final data = lastMessage.data();
        
        await _firestore
            .collection(_chatsCollection)
            .doc(conversationId)
            .update({
          'lastMessage': data['content'] ?? '',
          'lastMessageSenderId': data['senderId'] ?? '',
          'lastMessageAt': data['timestamp'] ?? FieldValue.serverTimestamp(),
        });
      } else {
        // No messages left, clear the conversation
        await _firestore
            .collection(_chatsCollection)
            .doc(conversationId)
            .update({
          'lastMessage': '',
          'lastMessageSenderId': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Failed to update conversation last message: $e');
    }
  }

  // Update unread count for other user
  Future<void> _updateUnreadCount(String conversationId, String currentUserId) async {
    try {
      final convSnap = await _firestore.collection(_chatsCollection).doc(conversationId).get();
      if (convSnap.exists) {
        final participants = List<String>.from(convSnap.data()?['participants'] ?? []);
        final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
        if (otherUserId.isNotEmpty) {
          await _firestore.collection(_chatsCollection).doc(conversationId).set({
            'unreadCounts': { otherUserId: FieldValue.increment(1) },
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Error updating unread count: $e');
    }
  }

  // Send notification for new message
  Future<void> _sendMessageNotification(
    String conversationId,
    String messageText,
    String senderId,
  ) async {
    try {
      // Get conversation data
      final conversationDoc = await _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return;

      final conversationData = conversationDoc.data()!;
      final participants = List<String>.from(conversationData['participants'] ?? []);
      
      // Get other participant ID
      final otherUserId = participants.firstWhere(
        (id) => id != senderId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) return;

      // Get sender info (optional)
      String senderName = 'Someone';
      try {
        final senderDoc = await _firestore.collection('users').doc(senderId).get();
        senderName = senderDoc.data()?['displayName'] ?? 'Someone';
      } catch (_) {}

      // Send notification (placeholder)
      await _sendNotificationToUser(
        userId: otherUserId,
        title: senderName,
        body: messageText,
        data: {
          'type': 'message',
          'conversationId': conversationId,
          'senderId': senderId,
        },
      );
    } catch (e) {
      debugPrint('Failed to send message notification: $e');
    }
  }

  // Send notification to user
  Future<void> _sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Delegate to NotificationService which knows how to call backend
      final service = NotificationService();
      await service.sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('Failed to send notification: $e');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) return;

    try {
      // İndeks gerektiren isNotEqualTo yerine, önce okunmamışları çekip client-side filtreleyelim
      final unreadSnapshot = await _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadSnapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;
        if (senderId != null && senderId != currentUserId) {
          batch.update(doc.reference, {'isRead': true});
        }
      }
      await batch.commit();

      // Reset unread counter for current user on the conversation
      await _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .set({ 'unreadCounts': { currentUserId: 0 } }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Get user info for conversation
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return null;
    }
  }

  // Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      final messages = await _firestore
          .collection(_chatsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(_firestore
          .collection(_chatsCollection)
          .doc(conversationId));

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete conversation: $e');
    }
  }
}

class ChatConversation {
  final String id;
  final List<String> participants;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String lastMessage;
  final String lastMessageSenderId;
  final String? productId;
  final String? productTitle;
  final Map<String, dynamic> displayNames;
  final Map<String, dynamic> unreadCounts;

  ChatConversation({
    required this.id,
    required this.participants,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessage,
    required this.lastMessageSenderId,
    this.productId,
    this.productTitle,
    this.displayNames = const {},
    this.unreadCounts = const {},
  });

  factory ChatConversation.fromFirestore(String id, Map<String, dynamic> data) {
    return ChatConversation(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      productId: data['productId'],
      productTitle: data['productTitle'],
      displayNames: Map<String, dynamic>.from(data['displayNames'] ?? {}),
      unreadCounts: Map<String, dynamic>.from(data['unreadCounts'] ?? {}),
    );
  }

  // Get other participant ID
  String? getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  // Check if current user is the last message sender
  bool isLastMessageFromCurrentUser(String currentUserId) {
    return lastMessageSenderId == currentUserId;
  }

  String? getDisplayNameFor(String userId) {
    final value = displayNames[userId];
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }
}
