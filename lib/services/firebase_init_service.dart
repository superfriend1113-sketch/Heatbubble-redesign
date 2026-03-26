import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firebase_auth_service.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 [FCM] Background message: ${message.messageId}');
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
      debugPrint('⚠️  [Firebase] Already initialized');
      return;
    }

    try {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔥 [Firebase] Initializing Firebase...');
      
      // Initialize Firebase Core
      await Firebase.initializeApp();
      debugPrint('✅ [Firebase] Core initialized');

      // Initialize Firebase Cloud Messaging
      await _initializeMessaging();

      // Set up auth state listener
      _setupAuthListener();

      _isInitialized = true;
      debugPrint('✅ [Firebase] All services initialized');
      debugPrint('═══════════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('❌ [Firebase] Initialization failed');
      debugPrint('   Error: $e');
      
      // Check if it's a configuration error
      if (e.toString().contains('firebase_options') || 
          e.toString().contains('google-services.json') ||
          e.toString().contains('No Firebase App')) {
        debugPrint('');
        debugPrint('⚠️  FIREBASE NOT CONFIGURED');
        debugPrint('   This is normal if you haven\'t set up Firebase yet.');
        debugPrint('   The app will work without Firebase features.');
        debugPrint('');
        debugPrint('   To enable Firebase:');
        debugPrint('   1. Run: flutterfire configure');
        debugPrint('   2. Download google-services.json');
        debugPrint('   3. Place in android/app/');
        debugPrint('   4. Restart the app');
        debugPrint('');
      } else {
        debugPrint('   Stack trace: $stackTrace');
      }
      debugPrint('═══════════════════════════════════════════════════════');
      
      // Don't rethrow - allow app to continue without Firebase
    }
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeMessaging() async {
    try {
      debugPrint('📬 [FCM] Initializing Cloud Messaging...');

      final messaging = FirebaseMessaging.instance;

      // Request permission for notifications
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('📬 [FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        _fcmToken = await messaging.getToken();
        debugPrint('📬 [FCM] Token: $_fcmToken');

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          debugPrint('📬 [FCM] Token refreshed: $newToken');
          // TODO: Send token to your backend
        });

        // Set up message handlers
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📬 [FCM] Foreground message: ${message.messageId}');
          debugPrint('   Title: ${message.notification?.title}');
          debugPrint('   Body: ${message.notification?.body}');
          // TODO: Show local notification
        });

        // Handle notification tap (app opened from notification)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('📬 [FCM] Notification tapped: ${message.messageId}');
          // TODO: Navigate to specific screen
        });

        debugPrint('✅ [FCM] Cloud Messaging initialized');
      } else {
        debugPrint('⚠️  [FCM] Notification permission denied');
      }
    } catch (e) {
      debugPrint('❌ [FCM] Initialization failed: $e');
      // Don't rethrow - FCM is optional
    }
  }

  /// Set up authentication state listener
  void _setupAuthListener() {
    final auth = FirebaseAuthService();
    
    auth.authStateChanges.listen((user) {
      if (user != null) {
        debugPrint('👤 [Auth] User signed in: ${user.uid}');
        debugPrint('   Email: ${user.email}');
        debugPrint('   Display Name: ${user.displayName}');
        // TODO: Sync user data, subscription status, etc.
      } else {
        debugPrint('👤 [Auth] User signed out');
      }
    });
  }

  /// Send FCM token to backend (for push notifications)
  Future<void> sendTokenToBackend(String userId) async {
    if (_fcmToken == null) {
      debugPrint('⚠️  [FCM] No token available');
      return;
    }

    try {
      debugPrint('📤 [FCM] Sending token to backend for user: $userId');
      // TODO: Implement your backend API call
      // Example:
      // await http.post(
      //   Uri.parse('https://your-backend.com/api/fcm-token'),
      //   body: {'userId': userId, 'token': _fcmToken},
      // );
      debugPrint('✅ [FCM] Token sent to backend');
    } catch (e) {
      debugPrint('❌ [FCM] Failed to send token: $e');
    }
  }

  /// Subscribe to topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      debugPrint('📬 [FCM] Subscribing to topic: $topic');
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('✅ [FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ [FCM] Subscribe to topic failed: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      debugPrint('📬 [FCM] Unsubscribing from topic: $topic');
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('✅ [FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ [FCM] Unsubscribe from topic failed: $e');
    }
  }
}
