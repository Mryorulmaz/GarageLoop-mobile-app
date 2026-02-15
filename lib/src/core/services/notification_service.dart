import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../main.dart';
import '../../chat/chat_screen.dart';

// Top-level background handler required by Firebase Messaging (iOS/Android)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('BG message: ${message.messageId}');
  }
  await NotificationService._updateBadgeCountInBackground();
}

class NotificationService extends ChangeNotifier {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;
  bool _isInitialized = false;
  int _badgeCount = 0;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  int get badgeCount => _badgeCount;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _requestPermission();
      await _getFCMToken();
      _setupMessageHandlers();
      _setupTokenRefreshListener();
      _isInitialized = true;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('NotificationService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize NotificationService: $e');
      }
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('Notification permission status: ${settings.authorizationStatus}');
    }
  }

  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      
      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
        if (kDebugMode) {
          debugPrint('FCM Token: $_fcmToken');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get FCM token: $e');
      }
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .doc('fcm')
          .set({
        'token': token,
        'platform': defaultTargetPlatform.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to save token to Firestore: $e');
      }
    }
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      await _saveTokenToFirestore(newToken);
      notifyListeners();
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Foreground message received: ${message.data}');
    }
    _updateBadgeCount();
    _showLocalNotification(message);
    notifyListeners();
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('Background message received: ${message.data}');
    }
    await _updateBadgeCountInBackground();
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Notification tapped: ${message.data}');
    }
    _navigateToScreen(message.data);
  }

  void _showLocalNotification(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Showing local notification: ${message.notification?.title}');
    }
  }

  void _navigateToScreen(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('Navigate to screen with data: $data');
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;

    final type = data['type'];
    if (type == 'message') {
      final otherUserId = data['senderId'] ?? '';
      final conversationId = data['conversationId'] ?? '';
      // We can push ChatScreen with otherUserId; name will be resolved inside
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            otherUserId: otherUserId,
            otherUserName: 'Chat',
          ),
          settings: RouteSettings(name: '/chat/$conversationId'),
        ),
      );
    }
  }

  Future<void> _updateBadgeCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _badgeCount = prefs.getInt('badge_count') ?? 0;
      _badgeCount++;
      await prefs.setInt('badge_count', _badgeCount);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update badge count: $e');
      }
    }
  }

  static Future<void> _updateBadgeCountInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int badgeCount = prefs.getInt('badge_count') ?? 0;
      badgeCount++;
      await prefs.setInt('badge_count', badgeCount);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update badge count in background: $e');
      }
    }
  }

  Future<void> clearBadgeCount() async {
    try {
      _badgeCount = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('badge_count', 0);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to clear badge count: $e');
      }
    }
  }

  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Call backend with userId; backend will look up token securely
      await _sendNotificationViaBackend(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to send notification: $e');
      }
    }
  }

  Future<void> _sendNotificationViaBackend({
    String? token,
    String? userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Configure these via remote config or .env in production
    const String endpoint = String.fromEnvironment('NOTIFY_ENDPOINT', defaultValue: '');
    const String apiKey = String.fromEnvironment('NOTIFY_API_KEY', defaultValue: '');

    if (endpoint.isEmpty || apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('Notification backend not configured. Skipping send.');
      }
      return;
    }

    try {
      final uri = Uri.parse(endpoint);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode({
          if (token != null) 'token': token,
          if (userId != null) 'userId': userId,
          'title': title,
          'body': body,
          'data': data ?? <String, dynamic>{},
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) debugPrint('Notification sent via backend');
      } else {
        if (kDebugMode) debugPrint('Notification backend error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Notification backend exception: $e');
    }
  }

  

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        debugPrint('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to subscribe to topic: $e');
      }
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        debugPrint('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to unsubscribe from topic: $e');
      }
    }
  }

  Future<NotificationSettings> getNotificationSettings() async {
    return await _messaging.getNotificationSettings();
  }
}
