import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/notification_model.dart';

/// Manages notification storage and history
class NotificationStore {
  static const String _notificationsKey = 'heatbubble_notifications';
  static const int _maxNotifications = 100; // Store last 100 notifications

  late SharedPreferences _prefs;

  /// Initialize the store
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save a notification
  Future<void> saveNotification(NotificationModel notification) async {
    try {
      final notifications = await getNotifications(limit: 200); // Get more to check limit
      
      // Add new notification at the beginning
      notifications.insert(0, notification);
      
      // Keep only last 100 notifications
      final trimmed = notifications.take(_maxNotifications).toList();
      
      // Save to storage
      final jsonList = trimmed.map((n) => json.encode(n.toJson())).toList();
      await _prefs.setStringList(_notificationsKey, jsonList);
    } catch (e) {
      debugPrint('❌ [NotificationStore] Failed to save notification: $e');
    }
  }

  /// Get all notifications
  Future<List<NotificationModel>> getNotifications({int limit = 50}) async {
    try {
      final jsonList = _prefs.getStringList(_notificationsKey) ?? [];
      
      return jsonList
          .take(limit)
          .map((jsonStr) {
            try {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              return NotificationModel.fromJson(json);
            } catch (e) {
              debugPrint('⚠️  [NotificationStore] Failed to parse notification: $e');
              return null;
            }
          })
          .whereType<NotificationModel>()
          .toList();
    } catch (e) {
      debugPrint('❌ [NotificationStore] Failed to get notifications: $e');
      return [];
    }
  }

  /// Get unread notifications
  Future<List<NotificationModel>> getUnreadNotifications() async {
    try {
      final notifications = await getNotifications(limit: 200);
      return notifications.where((n) => !n.isRead).toList();
    } catch (e) {
      debugPrint('❌ [NotificationStore] Failed to get unread notifications: $e');
      return [];
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final notifications = await getNotifications(limit: 200);
      
      // Find and update notification
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(isRead: true);
        
        // Save updated list
        final jsonList = notifications.map((n) => json.encode(n.toJson())).toList();
        await _prefs.setStringList(_notificationsKey, jsonList);
      }
    } catch (e) {
      debugPrint('❌ [NotificationStore] Failed to mark as read: $e');
    }
  }

  /// Get count of unread notifications
  Future<int> getUnreadCount() async {
    try {
      final notifications = await getUnreadNotifications();
      return notifications.length;
    } catch (e) {
      debugPrint('❌ [NotificationStore] Failed to get unread count: $e');
      return 0;
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    try {
      await _prefs.remove(_notificationsKey);
    } catch (e) {
      debugPrint('❌ [NotificationStore] Failed to clear notifications: $e');
    }
  }

  /// Delete a specific notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final notifications = await getNotifications(limit: 200);
      notifications.removeWhere((n) => n.id == notificationId);
      
      final jsonList = notifications.map((n) => json.encode(n.toJson())).toList();
      await _prefs.setStringList(_notificationsKey, jsonList);
    } catch (e) {
      debugPrint('❌ [NotificationStore] Failed to delete notification: $e');
    }
  }
}
