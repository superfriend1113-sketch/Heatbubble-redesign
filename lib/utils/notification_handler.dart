import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Mixin to handle notification tap callbacks and deep linking
/// Use this in your main app shell or home screen
mixin NotificationHandlerMixin {
  /// Get named route from notification action
  /// Override this in your screen to implement navigation
  void handleNotificationAction(String? action) {
    if (action == null) return;
    
    debugPrint('🔔 [NotificationHandler] Handling action: $action');
    
    // Route to appropriate screen based on action
    // This should be implemented in the widget using this mixin
  }
  
  /// Set up notification callbacks
  void setupNotificationCallbacks() {
    final notificationService = NotificationService();
    
    // Listen for notification taps
    notificationService.onNotificationTapped = (notificationId) {
      debugPrint('🔔 [NotificationHandler] Notification tapped: $notificationId');
      handleNotificationAction(notificationId);
    };
  }
}

/// Helper to mark notifications as read
class NotificationUtils {
  static Future<void> markNotificationRead(String notificationId) async {
    final service = NotificationService();
    await service.markAsRead(notificationId);
  }
  
  static Future<List<Map<String, dynamic>>> getNotificationList() async {
    final service = NotificationService();
    final notifications = await service.getNotifications();
    
    return notifications
        .map((n) => {
          'id': n.id,
          'title': n.title,
          'body': n.body,
          'type': n.type,
          'timestamp': n.timestamp,
          'isRead': n.isRead,
        })
        .toList();
  }
  
  static Future<int> getUnreadCount() async {
    final service = NotificationService();
    return service.getUnreadCount();
  }
  
  static Future<void> clearAll() async {
    final service = NotificationService();
    await service.clearAll();
  }
}
