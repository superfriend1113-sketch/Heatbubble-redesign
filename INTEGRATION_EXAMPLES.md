/**
 * INTEGRATION EXAMPLE
 * 
 * This file shows how to integrate the push notification system
 * into your existing screens
 */

// Example 1: Set up notification callbacks in AppShell
// In your app.dart or main app widget:

import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'utils/notification_handler.dart';

class AppShellExample extends StatefulWidget {
  @override
  State<AppShellExample> createState() => _AppShellExampleState();
}

class _AppShellExampleState extends State<AppShellExample>
    with NotificationHandlerMixin {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    // Set up notification handling after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupNotificationCallbacks();
      _setupNotificationNavigation();
    });
  }

  void _setupNotificationNavigation() {
    final notificationService = NotificationService();
    
    // Handle notification taps
    notificationService.onNotificationTapped = (notificationId) {
      if (notificationId == null) return;
      
      debugPrint('🔔 Notification tapped: $notificationId');
      
      // Route to appropriate screen
      switch (notificationId) {
        case 'temperature_alert':
        case 'home':
          _navigatorKey.currentState?.pushNamed('/home');
          break;
        case 'custom_alerts':
          _navigatorKey.currentState?.pushNamed('/custom_alerts');
          break;
        case 'paywall':
          _navigatorKey.currentState?.pushNamed('/paywall');
          break;
        default:
          debugPrint('⚠️  Unknown notification action: $notificationId');
      }
    };
  }

  @override
  void handleNotificationAction(String? action) {
    _setupNotificationNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      // Your navigation setup here
    );
  }
}

// Example 2: Add notification badge to bottom navigation
class NotificationBadgeExample extends StatefulWidget {
  @override
  State<NotificationBadgeExample> createState() =>
      _NotificationBadgeExampleState();
}

class _NotificationBadgeExampleState extends State<NotificationBadgeExample> {
  late Future<int> _unreadCount;

  @override
  void initState() {
    super.initState();
    _unreadCount = NotificationUtils.getUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Stack(
          children: [
            // Your icon here
            Icon(Icons.notifications),
            
            // Badge with count
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Example 3: Display notification list
class NotificationListExample extends StatefulWidget {
  @override
  State<NotificationListExample> createState() =>
      _NotificationListExampleState();
}

class _NotificationListExampleState extends State<NotificationListExample> {
  late Future<List<Map<String, dynamic>>> _notifications;

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
  }

  void _refreshNotifications() {
    setState(() {
      _notifications = NotificationUtils.getNotificationList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _notifications,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Center(
            child: Text('No notifications yet'),
          );
        }

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            
            return ListTile(
              title: Text(notif['title'] as String),
              subtitle: Text(notif['body'] as String),
              trailing: notif['isRead'] == false
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
              onTap: () async {
                await NotificationUtils.markNotificationRead(
                  notif['id'] as String,
                );
                _refreshNotifications();
              },
            );
          },
        );
      },
    );
  }
}

// Example 4: Handle app initialization from notification
// In your main.dart:

import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> handleInitialNotification() async {
  final messaging = FirebaseMessaging.instance;
  
  // If app was launched from notification
  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    debugPrint(
      '🔔 App launched from notification: ${initialMessage.messageId}',
    );
    
    // Handle the initial message (navigate, etc.)
    // This is typically handled by NotificationService.handleInitialMessage()
  }
}

// Example 5: Send local notification from within app
Future<void> sendLocalNotificationExample() async {
  final service = NotificationService();
  
  // Note: NotificationService is designed for FCM messages
  // For local notifications from your app, use NudgeService:
  
  // Or use Flutter Local Notifications directly
  // import 'package:flutter_local_notifications/flutter_local_notifications.dart';
}

// Example 6: Subscribe to topics for broadcast notifications
import 'services/firebase_init_service.dart';

void setupTopicSubscriptions() {
  final firebaseService = FirebaseInitService();
  
  // Subscribe to topics based on user preferences
  firebaseService.subscribeToTopic('all_users');
  firebaseService.subscribeToTopic('android_users');
  firebaseService.subscribeToTopic('premium_users'); // If user is premium
}

// Example 7: Handle notification in custom alert matching
// In your CustomAlertService or wherever you check conditions:

void checkCustomAlertAndNotify(double currentTemp, Alert alert) {
  bool triggersAlert = _checkAlertCondition(currentTemp, alert);
  
  if (triggersAlert) {
    // Option 1: Use NudgeService for local notifications
    // (These also appear as remote notifications if sent from server)
    
    // Option 2: You could also send to your backend to trigger FCM
    // This is useful for cross-device notifications
  }
}
