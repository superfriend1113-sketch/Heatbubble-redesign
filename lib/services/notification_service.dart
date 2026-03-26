import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import 'notification_store.dart';

/// Production-ready notification service that handles:
/// - Remote (FCM) notifications
/// - Local notifications
/// - Background message handling
/// - Deep linking and navigation
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _notificationStore = NotificationStore();
  
  // Callbacks for navigation/actions
  Function(String?)? onNotificationTapped;
  
  bool _initialized = false;
  static const int _foregroundNotificationDelay = 500; // ms

  bool get isInitialized => _initialized;

  /// Initialize notification service (call once at app startup)
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️  [Notifications] Already initialized');
      return;
    }

    try {
      debugPrint('📬 [Notifications] Initializing notification service...');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Initialize notification store
      await _notificationStore.init();
      
      _initialized = true;
      debugPrint('✅ [Notifications] Service initialized');
    } catch (e) {
      debugPrint('❌ [Notifications] Initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Create notification channels for Android
    await _createAndroidNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createAndroidNotificationChannels() async {
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl == null) return;

    // High priority channel for temperature alerts
    const temperatureChannel = AndroidNotificationChannel(
      'heatbubble_alerts',
      'Temperature Alerts',
      description: 'Alerts for temperature readings and comparisons',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Max priority channel for extreme temperatures
    const extremeChannel = AndroidNotificationChannel(
      'heatbubble_extreme',
      'Extreme Temperature Alerts',
      description: 'Urgent alerts for extreme temperature conditions',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // General notifications channel
    const generalChannel = AndroidNotificationChannel(
      'heatbubble_general',
      'General Notifications',
      description: 'General app notifications',
      importance: Importance.defaultImportance,
    );

    await Future.wait([
      androidImpl.createNotificationChannel(temperatureChannel),
      androidImpl.createNotificationChannel(extremeChannel),
      androidImpl.createNotificationChannel(generalChannel),
    ]);

    debugPrint('✅ [Notifications] Android channels created');
  }

  /// Handle FCM remote message (called in background)
  Future<void> handleRemoteMessage(RemoteMessage message) async {
    debugPrint('📬 [Notifications] Remote message received (Background)');
    debugPrint('   Message ID: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    try {
      // Store notification
      final notification = NotificationModel(
        id: message.messageId ?? DateTime.now().toString(),
        title: message.notification?.title ?? 'HeatBubble',
        body: message.notification?.body ?? '',
        type: _getNotificationType(message.data),
        data: message.data,
        timestamp: DateTime.now(),
        isRead: false,
      );
      
      await _notificationStore.saveNotification(notification);
      
      // Show local notification
      await _showLocalNotification(notification);
      
      // Handle special data actions
      if (message.data.containsKey('action')) {
        _handleAction(message.data['action']!, message.data);
      }
    } catch (e) {
      debugPrint('❌ [Notifications] Failed to handle remote message: $e');
    }
  }

  /// Handle FCM foreground message
  void handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 [Notifications] Remote message received (Foreground)');
    debugPrint('   Message ID: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');

    try {
      // Delay slightly to ensure app is ready
      Future.delayed(Duration(milliseconds: _foregroundNotificationDelay), () async {
        final notification = NotificationModel(
          id: message.messageId ?? DateTime.now().toString(),
          title: message.notification?.title ?? 'HeatBubble',
          body: message.notification?.body ?? '',
          type: _getNotificationType(message.data),
          data: message.data,
          timestamp: DateTime.now(),
          isRead: false,
        );
        
        await _notificationStore.saveNotification(notification);
        await _showLocalNotification(notification);
      });
    } catch (e) {
      debugPrint('❌ [Notifications] Failed to handle foreground message: $e');
    }
  }

  /// Handle notification tap/interaction
  Future<void> handleInitialMessage(RemoteMessage? message) async {
    if (message == null) return;

    debugPrint('📬 [Notifications] Initial message (App launched from notification)');
    debugPrint('   Message ID: ${message.messageId}');
    
    try {
      // Mark as read
      if (message.messageId != null) {
        await _notificationStore.markAsRead(message.messageId!);
      }

      // Navigate based on data
      _handleAction(message.data['action'], message.data);
    } catch (e) {
      debugPrint('❌ [Notifications] Failed to handle initial message: $e');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(NotificationModel notification) async {
    try {
      final androidDetails = _getAndroidNotificationDetails(notification.type);
      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        details,
        payload: notification.id,
      );

      debugPrint('✅ [Notifications] Local notification shown: ${notification.title}');
    } catch (e) {
      debugPrint('❌ [Notifications] Failed to show local notification: $e');
    }
  }

  /// Get Android notification details based on type
  AndroidNotificationDetails _getAndroidNotificationDetails(String type) {
    switch (type) {
      case 'extreme_temperature':
        return const AndroidNotificationDetails(
          'heatbubble_extreme',
          'Extreme Temperature Alerts',
          importance: Importance.max,
          autoCancel: true,
          playSound: true,
          enableVibration: true,
        );
      case 'temperature_alert':
        return const AndroidNotificationDetails(
          'heatbubble_alerts',
          'Temperature Alerts',
          importance: Importance.high,
          autoCancel: true,
          playSound: true,
          enableVibration: true,
        );
      default:
        return const AndroidNotificationDetails(
          'heatbubble_general',
          'General Notifications',
          importance: Importance.defaultImportance,
          autoCancel: true,
        );
    }
  }

  /// Handle notification response
  void _handleNotificationResponse(NotificationResponse response) {
    debugPrint('📬 [Notifications] Notification tapped');
    debugPrint('   Payload: ${response.payload}');
    
    try {
      if (response.payload != null) {
        onNotificationTapped?.call(response.payload);
        _notificationStore.markAsRead(response.payload!);
      }
    } catch (e) {
      debugPrint('❌ [Notifications] Failed to handle notification response: $e');
    }
  }

  /// Determine notification type from data
  String _getNotificationType(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    return type ?? 'general';
  }

  /// Handle special actions from notification data
  void _handleAction(String? action, Map<String, dynamic> data) {
    if (action == null) return;

    debugPrint('🔄 [Notifications] Handling action: $action');

    switch (action) {
      case 'temperature_alert':
        onNotificationTapped?.call('temperature_alert');
        break;
      case 'comparison_result':
        onNotificationTapped?.call('home');
        break;
      case 'custom_alert':
        onNotificationTapped?.call('custom_alerts');
        break;
      case 'subscription_offer':
        onNotificationTapped?.call('paywall');
        break;
      default:
        debugPrint('⚠️  [Notifications] Unknown action: $action');
    }
  }

  /// Get notification history
  Future<List<NotificationModel>> getNotifications({int limit = 50}) async {
    return _notificationStore.getNotifications(limit: limit);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    return _notificationStore.markAsRead(notificationId);
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    return _notificationStore.clearAll();
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    return _notificationStore.getUnreadCount();
  }
}
