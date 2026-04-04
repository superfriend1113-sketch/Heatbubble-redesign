import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firebase_auth_service.dart';
import 'notification_service.dart';

/// Background message handler (must be top-level function)
/// Called when app is killed/terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // Initialize notification service for background handling
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.handleRemoteMessage(message);
}

class FirebaseInitService {
  static final FirebaseInitService _instance = FirebaseInitService._internal();
  factory FirebaseInitService() => _instance;
  FirebaseInitService._internal();

  bool _isInitialized = false;
  String? _fcmToken;

  bool get isInitialized => _isInitialized;
  String? get fcmToken => _fcmToken;

  /// Initialize Firebase services
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      
      // Initialize Firebase Core
      await Firebase.initializeApp();

      // Initialize Firebase Cloud Messaging
      await _initializeMessaging();

      // Set up auth state listener
      _setupAuthListener();

      _isInitialized = true;
    } catch (e, stackTrace) {
      
      // Check if it's a configuration error
      if (e.toString().contains('firebase_options') || 
          e.toString().contains('google-services.json') ||
          e.toString().contains('No Firebase App')) {
      } else {
      }
      
      // Don't rethrow - allow app to continue without Firebase
    }
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeMessaging() async {
    try {

      final messaging = FirebaseMessaging.instance;

      // Request permission for notifications
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
      );


      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await messaging.getToken();

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          // Send to your backend to update device token
          _sendTokenToBackend(newToken);
        });

        // Set up message handlers
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Initialize notification service
        final notificationService = NotificationService();
        await notificationService.initialize();

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          notificationService.handleForegroundMessage(message);
        });

        // Handle notification tap (app opened from notification or resumed)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          notificationService.handleInitialMessage(message);
        });

        // Handle initial message (app launched from notification)
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          notificationService.handleInitialMessage(initialMessage);
        }

        // Subscribe to default topics for broadcast notifications
        await messaging.subscribeToTopic('all_users');

      } else {
      }
    } catch (e) {
      // Don't rethrow - FCM is optional
    }
  }

  /// Set up authentication state listener
  void _setupAuthListener() {
    final auth = FirebaseAuthService();
    
    auth.authStateChanges.listen((user) {
      if (user != null) {
      } else {
      }
    });
  }

  /// Internal method to send token to backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      // TODO: Implement your backend API call here
      // Example:
      // await http.post(
      //   Uri.parse('https://your-backend.com/api/fcm-token'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({'token': token, 'platform': 'android'}),
      // );
    } catch (e) {
    }
  }

  /// Send FCM token to backend (for push notifications)
  Future<void> sendTokenToBackend(String userId) async {
    if (_fcmToken == null) {
      return;
    }

    try {
      await _sendTokenToBackend(_fcmToken!);
    } catch (e) {
    }
  }

  /// Subscribe to topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (e) {
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
    }
  }
}
