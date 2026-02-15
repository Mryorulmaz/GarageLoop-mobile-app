
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../profile/models/user_profile.dart';
import '../profile/repositories/user_profile_repository.dart';
import 'chat_repository.dart';

enum MessageType {
  text,
  image,
  location,
  offer,
  meetingRequest,
  system,
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.imageUrl,
    this.location,
    this.offerAmount,
    this.meetingDetails,
    this.isRead = false,
    this.isDelivered = false,
  });

  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? imageUrl;
  final GeoPoint? location;
  final double? offerAmount;
  final Map<String, dynamic>? meetingDetails;
  final bool isRead;
  final bool isDelivered;

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: _parseMessageType(data['type'] ?? 'text'),
      imageUrl: data['imageUrl'],
      location: data['location'] as GeoPoint?,
      offerAmount: (data['offerAmount'] as num?)?.toDouble(),
      meetingDetails: data['meetingDetails'] as Map<String, dynamic>?,
      isRead: data['isRead'] ?? false,
      isDelivered: data['isDelivered'] ?? false,
    );
  }

  static MessageType _parseMessageType(String type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'location':
        return MessageType.location;
      case 'offer':
        return MessageType.offer;
      case 'meetingRequest':
        return MessageType.meetingRequest;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.name,
      'imageUrl': imageUrl,
      'location': location,
      'offerAmount': offerAmount,
      'meetingDetails': meetingDetails,
      'isRead': isRead,
      'isDelivered': isDelivered,
    };
  }
}

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    ChatRepository? repository,
    UserProfileRepository? userRepository,
  }) : _repository = repository ?? ChatRepository(),
       _userRepository = userRepository ?? UserProfileRepository();

  final ChatRepository _repository;
  final UserProfileRepository _userRepository;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentConversationId;
  String? _otherUserId;
  String? _otherUserName;
  List<ChatMessage> _messages = [];
  bool _isLoadingMore = false;
  bool _isLoading = false;
  bool _isSendingMessage = false;
  String? _error;
  String? _info;
  UserProfile? _currentUserProfile;
  UserProfile? _otherUserProfile;
  final Map<String, UserProfile> _userCache = {};
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  bool _isDisposed = false;

  // Quick message templates
  static const List<String> quickMessages = [
    'Is this still available?',
    'Can you hold this for me?',
    'Can I pick it up today?',
    'Can I see more photos?',
    'When are you available to meet?',
    'Where would you like to meet?',
    'What time works for pickup?',
    'What\'s the condition like?',
    'Do you have the receipt?',
    'Can you deliver?',
  ];

  // Getters
  String? get currentConversationId => _currentConversationId;
  String? get otherUserId => _otherUserId;
  String? get otherUserName => _otherUserName;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSendingMessage => _isSendingMessage;
  String? get error => _error;
  String? get info => _info;
  UserProfile? get currentUserProfile => _currentUserProfile;
  UserProfile? get otherUserProfile => _otherUserProfile;

  Future<void> initialize(String otherUserId, String otherUserName, [String? initialMessage]) async {
    _otherUserId = otherUserId;
    _otherUserName = otherUserName;
    _isLoading = true;
    _error = null;
    _info = null;
    _notify();

    try {
      await _loadCurrentUserProfile();
      await _loadOtherUserProfile();
      
      // Only load existing conversation, don't create one yet
      await _loadExistingConversation();
      
      // If conversation exists, load messages
      if (_currentConversationId != null) {
        await _loadMessages();
      }
      
      // Send initial message if provided - this will create the conversation if needed
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500)); // Wait for chat to be ready
        await sendMessage(initialMessage);
      }
    } catch (e) {
      _error = 'Failed to initialize chat: $e';
      debugPrint('Chat initialization error: $e');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserProfile = await _userRepository.getUserProfile(user.uid);
      }
    } catch (e) {
      debugPrint('Error loading current user profile: $e');
    }
  }

  Future<void> _loadOtherUserProfile() async {
    if (_otherUserId == null || _otherUserId!.trim().isEmpty) return;
    
    try {
      _otherUserProfile = await _userRepository.getUserProfile(_otherUserId!);
      _userCache[_otherUserId!] = _otherUserProfile!;
    } catch (e) {
      debugPrint('Error loading other user profile: $e');
      // Create fallback profile
      _otherUserProfile = UserProfile(
        id: _otherUserId!,
        displayName: _otherUserName ?? 'Unknown User',
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
    }
  }

  Future<void> _loadExistingConversation() async {
    if (_otherUserId == null) return;

    try {
      // Try to find existing conversation without creating a new one
      _currentConversationId = await _repository.findExistingConversation(_otherUserId!);
    } catch (e) {
      debugPrint('Error loading existing conversation: $e');
      // Don't rethrow - it's okay if no conversation exists yet
    }
  }
  
  Future<void> _loadOrCreateConversation() async {
    if (_otherUserId == null) return;

    try {
      _currentConversationId = await _repository.createOrGetConversation(_otherUserId!);
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      rethrow;
    }
  }
  
  // Ensure conversation exists before sending any message
  Future<bool> _ensureConversationExists() async {
    if (_currentConversationId != null) return true;
    
    try {
      await _loadOrCreateConversation();
      // Start listening to messages for the new conversation
      if (_currentConversationId != null) {
        await _loadMessages();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Failed to create conversation: $e';
      debugPrint('Error creating conversation: $e');
      _notify();
      return false;
    }
  }

  Future<void> _loadMessages() async {
    if (_currentConversationId == null) return;

    try {
      // Cancel existing subscription to prevent memory leaks
      await _messagesSubscription?.cancel();
      _messagesSubscription = null;
      
      _messagesSubscription = _repository.streamMessages(_currentConversationId!).listen(
        (messages) {
          final tempMessages = _messages.where((m) => m.id.startsWith('temp_')).toList();
          final merged = [...messages];
          for (final temp in tempMessages) {
            final alreadyInStream = messages.any((m) => m.content == temp.content && m.senderId == temp.senderId);
            if (!alreadyInStream) {
              merged.add(temp);
            }
          }
          merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _messages = merged;
          _notify();
          // Mark others' messages as read when stream updates
          if (_currentConversationId != null) {
            _repository.markMessagesAsRead(_currentConversationId!);
          }
        },
        onError: (error) {
          _error = 'Failed to load messages: $error';
          debugPrint('Error loading messages: $error');
          _notify();
        },
      );
    } catch (e) {
      _error = 'Failed to load messages: $e';
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> loadOlderMessages() async {
    if (_currentConversationId == null || _messages.isEmpty || _isLoadingMore) return;
    _isLoadingMore = true;
    _notify();
    try {
      final oldest = _messages.first.timestamp;
      final older = await _repository.fetchOlderMessages(
        _currentConversationId!,
        oldest,
        limit: 50,
      );
      if (older.isNotEmpty) {
        _messages = [...older, ..._messages];
      }
    } catch (e) {
      debugPrint('Error loading older messages: $e');
    } finally {
      _isLoadingMore = false;
      _notify();
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isSendingMessage) return;

    final trimmedContent = content.trim();
    final currentUserId = _currentUserProfile?.id ?? FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Optimistic UI update - add message immediately to UI
    final optimisticMessage = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUserId,
      content: trimmedContent,
      timestamp: DateTime.now(),
      type: MessageType.text,
    );
    
    _messages.add(optimisticMessage);
    _isSendingMessage = true;
    _error = null;
    _notify();

    try {
      // Charge only for the first message to a new seller
      if (_currentConversationId == null) {
        if (_otherUserId == null || _otherUserId!.isEmpty) {
          throw Exception('Missing chat recipient.');
        }
        final existing = await _repository.findExistingConversation(_otherUserId!);
        if (existing != null) {
          _currentConversationId = existing;
          await _loadMessages();
        } else {
        final chargeResult = await _chargeForNewConversation();
          if (chargeResult == _ChargeResult.insufficient) {
            throw Exception('Not enough credits to send the first message.');
          }
          if (chargeResult == _ChargeResult.error) {
            throw Exception('Credit charge failed. Please try again.');
          }
        _info = '-5 credits for first message';
        }
      }

      // Create conversation if it doesn't exist yet (only when first message is sent)
      if (!await _ensureConversationExists()) {
        throw Exception('Failed to create conversation.');
      }

      await _repository.sendMessage(
        _currentConversationId!,
        trimmedContent,
        MessageType.text,
      );
      
      // Message sent successfully - the real message will come through the stream
      // Remove the optimistic message
      _messages.removeWhere((msg) => msg.id == optimisticMessage.id);
      
    } catch (e) {
      // Remove optimistic message on error
      _messages.removeWhere((msg) => msg.id == optimisticMessage.id);
      
      _error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('Error sending message: $e');
    } finally {
      _isSendingMessage = false;
      _notify();
    }
  }

  Future<_ChargeResult> _chargeForNewConversation() async {
    try {
      if (_otherUserId == null || _otherUserId!.isEmpty) {
        return _ChargeResult.error;
      }
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return _ChargeResult.error;
      final userRef = _firestore.collection('users').doc(userId);
      final otherUserId = _otherUserId!;
      final result = await _firestore.runTransaction<_ChargeResult>((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) return _ChargeResult.error;
        final data = snap.data() ?? {};
        final unlocks = Map<String, dynamic>.from(data['chatUnlocks'] ?? {});
        if (unlocks[otherUserId] == true) {
          return _ChargeResult.success;
        }
        final currentCredits = (data['credits'] as num?)?.toInt() ?? 0;
        if (currentCredits < 5) {
          return _ChargeResult.insufficient;
        }
        unlocks[otherUserId] = true;
        tx.update(userRef, {
          'credits': currentCredits - 5,
          'chatUnlocks': unlocks,
          'lastCreditReason': 'chat_unlock',
        });
        return _ChargeResult.success;
      });
      return result;
    } catch (_) {
      return _ChargeResult.error;
    }
  }

  Future<void> sendImage() async {
    if (!await _ensureConversationExists()) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadAndSendImage(image);
      }
    } catch (e) {
      _error = 'Failed to send image: $e';
      debugPrint('Error sending image: $e');
      _notify();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (_currentConversationId == null) return;

    // Don't try to delete temporary messages
    if (messageId.startsWith('temp_')) {
      _messages.removeWhere((msg) => msg.id == messageId);
      _notify();
      return;
    }

    try {
      await _repository.deleteMessage(_currentConversationId!, messageId);
      
      // Remove message from local list
      _messages.removeWhere((msg) => msg.id == messageId);
      
      // Update conversation's last message after deletion
      await _updateConversationAfterMessageDeletion();
      
      _notify();
      
    } catch (e) {
      _error = 'Failed to delete message. Please try again.';
      debugPrint('Error deleting message: $e');
      _notify();
    }
  }

  // Update conversation after message deletion
  Future<void> _updateConversationAfterMessageDeletion() async {
    if (_currentConversationId == null || _messages.isEmpty) return;

    try {
      // Get the most recent message
      final lastMessage = _messages.last;
      
      // Update conversation with new last message
      await _repository.updateConversationLastMessage(
        _currentConversationId!,
        lastMessage.content,
        lastMessage.senderId,
        lastMessage.timestamp,
      );
    } catch (e) {
      debugPrint('Error updating conversation after message deletion: $e');
    }
  }

  Future<void> takeAndSendPhoto() async {
    if (!await _ensureConversationExists()) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadAndSendImage(image);
      }
    } catch (e) {
      _error = 'Failed to take photo: $e';
      debugPrint('Error taking photo: $e');
      _notify();
    }
  }

  Future<void> _uploadAndSendImage(XFile image) async {
    try {
      // Upload image to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final ref = _storage.ref().child('chat_images/$fileName');
      
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(image.path));
      }
      
      final imageUrl = await ref.getDownloadURL();
      
      // Send message with image URL
      await _repository.sendMessage(
        _currentConversationId!,
        'Image',
        MessageType.image,
        imageUrl: imageUrl,
      );
    } catch (e) {
      _error = 'Failed to upload image: $e';
      debugPrint('Error uploading image: $e');
      _notify();
    }
  }

  Future<void> sendLocation() async {
    if (!await _ensureConversationExists()) return;

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _error = 'Location permission denied';
        notifyListeners();
        return;
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address
      String address = 'Current Location';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          address = '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      // Send location message
      await _repository.sendMessage(
        _currentConversationId!,
        address,
        MessageType.location,
        location: GeoPoint(position.latitude, position.longitude),
      );
    } catch (e) {
      _error = 'Failed to send location: $e';
      debugPrint('Error sending location: $e');
      _notify();
    }
  }

  Future<void> sendOffer(double amount) async {
    if (!await _ensureConversationExists()) return;

    try {
      await _repository.sendMessage(
        _currentConversationId!,
        'Offer: \$${amount.toStringAsFixed(2)}',
        MessageType.offer,
        offerAmount: amount,
      );
    } catch (e) {
      _error = 'Failed to send offer: $e';
      debugPrint('Error sending offer: $e');
      notifyListeners();
    }
  }

  Future<void> sendMeetingRequest({
    required DateTime dateTime,
    required String location,
    String? notes,
  }) async {
    if (!await _ensureConversationExists()) return;

    try {
      final meetingDetails = {
        'dateTime': Timestamp.fromDate(dateTime),
        'location': location,
        'notes': notes,
      };

      await _repository.sendMessage(
        _currentConversationId!,
        'Meeting Request: ${dateTime.toString().substring(0, 16)} at $location',
        MessageType.meetingRequest,
        meetingDetails: meetingDetails,
      );
    } catch (e) {
      _error = 'Failed to send meeting request: $e';
      debugPrint('Error sending meeting request: $e');
      notifyListeners();
    }
  }

  Future<void> sendQuickMessage(String message) async {
    await sendMessage(message);
  }

  Future<UserProfile> getUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final profile = await _userRepository.getUserProfile(userId);
      if (profile != null) {
        _userCache[userId] = profile;
        return profile;
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
    }
    
    // Return fallback profile
    final fallbackProfile = UserProfile(
      id: userId,
      displayName: 'User $userId',
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
    return fallbackProfile;
  }

  String getInitials(String userId) {
    if (userId == FirebaseAuth.instance.currentUser?.uid) {
      final profileName = _currentUserProfile?.displayName.trim();
      if (profileName != null && profileName.isNotEmpty) {
        return _getInitialsFromName(profileName);
      }
      final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
      if (authName != null && authName.isNotEmpty) {
        return _getInitialsFromName(authName);
      }
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      if (email.isNotEmpty) {
        return _getInitialsFromName(email.split('@').first);
      }
      return 'U';
    } else {
      return _otherUserProfile?.displayName.isNotEmpty == true
          ? _getInitialsFromName(_otherUserProfile!.displayName)
          : 'U';
    }
  }

  String _getInitialsFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r"\s+")).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  void markMessageAsRead(String messageId) {
    // Implementation for marking messages as read
    // This would typically update Firestore
  }

  void clearError() {
    _error = null;
    _notify();
  }

  void clearInfo() {
    _info = null;
    _notify();
  }

  @override
  void dispose() {
    // Cancel all subscriptions to prevent memory leaks
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    
    // Clear caches
    _userCache.clear();
    _messages.clear();
    
    _isDisposed = true;
    super.dispose();
  }

  void _notify() {
    if (_isDisposed) return;
    try {
      notifyListeners();
    } catch (_) {}
  }
}

enum _ChargeResult { success, insufficient, error }


