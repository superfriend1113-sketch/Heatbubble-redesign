/**
 * PUSH NOTIFICATION IMPLEMENTATION GUIDE
 * 
 * This document describes how push notifications work in HeatBubble
 * and how they function when the app is not running.
 */

# Production-Ready Push Notification System

## Overview

The HeatBubble app now has a complete push notification system that works seamlessly:
- ✅ When app is open (foreground)
- ✅ When app is in background (minimized)
- ✅ When app is closed/terminated
- ✅ Notification history and management
- ✅ Deep linking to specific screens
- ✅ Local fallback notifications

## Architecture

### Components

1. **NotificationService** (`services/notification_service.dart`)
   - Main notification handler
   - Manages local notifications
   - Handles foreground/background messages
   - Provides deep linking support

2. **NotificationStore** (`services/notification_store.dart`)
   - Persistent notification storage using SharedPreferences
   - Stores up to 100 most recent notifications
   - Tracks read/unread status
   - Efficient for quick access without database overhead

3. **NotificationModel** (`models/notification_model.dart`)
   - Data class for notifications
   - Supports JSON serialization
   - Contains metadata for deep linking

4. **FirebaseInitService** (`services/firebase_init_service.dart`)
   - Firebase Cloud Messaging setup
   - Background message handler
   - Token management
   - Topic subscriptions

## How It Works

### Notification States

#### 1. App is Open (Foreground)
```
FCM → FirebaseMessaging.onMessage
     → NotificationService.handleForegroundMessage()
     → Show local notification immediately
     → User sees notification in-app
```

#### 2. App is Background
```
FCM → FirebaseMessaging.onMessageOpenedApp
     → NotificationService.handleInitialMessage()
     → Navigate to appropriate screen
     → User taps notification → opens app
```

#### 3. App is Closed/Terminated
```
FCM → _firebaseMessagingBackgroundHandler() (top-level)
     → Initialize Firebase
     → Initialize NotificationService
     → NotificationService.handleRemoteMessage()
     → Show local notification via Android system
     → Store in local database
     → When user taps: app launches → handles initial message
```

### Key Features

**Background Message Handling**
- Uses `@pragma('vm:entry-point')` for background handler
- Initializes Firebase in background isolate
- Shows notifications even when app is killed
- Stores notification in device database

**Notification Storage**
- Last 100 notifications stored locally
- Accessible via NotificationService.getNotifications()
- Supports filtering by read/unread
- Efficient SharedPreferences-based storage

**Deep Linking**
- Notifications include action data
- Automatically navigates to relevant screen on tap
- Supported actions:
  - `temperature_alert` → Home screen
  - `comparison_result` → Home screen
  - `custom_alert` → Custom Alerts screen
  - `subscription_offer` → Paywall screen

## Setting Up Firebase Cloud Messaging

### Prerequisites
1. Firebase project with FCM enabled
2. `google-services.json` in `android/app/`
3. Notification permissions configured

### Payload Format

Send FCM messages with this format:

```json
{
  "notification": {
    "title": "🔥 High Temperature Alert",
    "body": "Your temperature jumped 5°C - stay hydrated!"
  },
  "data": {
    "type": "temperature_alert",
    "action": "temperature_alert",
    "severity": "high"
  },
  "android": {
    "priority": "high",
    "notification": {
      "channel_id": "heatbubble_alerts"
    }
  },
  "webpush": {
    "headers": {
      "TTL": "86400"
    }
  }
}
```

### Notification Types

**1. Temperature Alert**
```json
"type": "temperature_alert"
"action": "temperature_alert"
```

**2. Extreme Temperature**
```json
"type": "extreme_temperature"
"channel_id": "heatbubble_extreme"
```

**3. Custom Alert**
```json
"type": "custom_alert"
"action": "custom_alerts"
```

**4. Subscription Offer**
```json
"type": "subscription"
"action": "subscription_offer"
```

## Android Notification Channels

The app creates three notification channels:

1. **heatbubble_alerts** (High priority)
   - For temperature alerts and comparisons
   - Shows heads-up notification

2. **heatbubble_extreme** (Max priority)
   - For extreme temperature warnings
   - Shows full-screen intent
   - Vibration + Sound

3. **heatbubble_general** (Default)
   - General app notifications
   - Silent notification

## Testing

### Simulate Foreground Message
```dart
// Send via Firebase Console
// App must be open to see impact
```

### Simulate Background Message
1. Open app, grant notification permission
2. Minimize app (don't close)
3. Send test notification from Firebase Console
4. Notification appears in system tray
5. Tap notification to see deep linking

### Simulate Killed App
1. Open app, grant notification permission
2. Force close app (long press → Force Stop)
3. Send test notification from Firebase Console
4. Notification appears in system tray
5. Tap notification to see app launch and navigation

## Notification History

Access notification history in your screen:

```dart
class NotifScreen extends StatefulWidget {
  @override
  State<NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends State<NotifScreen> {
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
  }

  Future<void> _loadNotifications() async {
    final notifications = await _notificationService.getNotifications();
    setState(() {
      // Update UI with notifications
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadNotifications(),
      builder: (context, snapshot) {
        // Display notifications
      },
    );
  }
}
```

## Production Checklist

- [ ] Firebase project created and configured
- [ ] `google-services.json` added to `android/app/`
- [ ] FCM enabled in Firebase Console
- [ ] Notification permissions requested
- [ ] Backend sending FCM messages with proper payload
- [ ] Track FCM tokens server-side
- [ ] Test all notification scenarios
- [ ] Implement notification analytics
- [ ] Handle opt-out/muting preferences

## Handling Notification Taps in UI

Set up in your main app widget or root screen:

```dart
final notificationService = NotificationService();
notificationService.onNotificationTapped = (action) {
  // Handle navigation based on action
  if (action == 'temperature_alert') {
    Navigator.pushNamed(context, '/home');
  } else if (action == 'custom_alerts') {
    Navigator.pushNamed(context, '/custom_alerts');
  }
};
```

## Troubleshooting

### Notifications Not Appearing When App is Closed
1. Check FCM token is being sent to backend
2. Verify notification permission granted
3. Check Battery Saver mode (may delay notifications)
4. Ensure notification channel is created on first launch

### Notifications Not Appearing When App is Open
1. Check `FirebaseMessaging.onMessage` listener is registered
2. Verify `NotificationService.handleForegroundMessage()` is called
3. Check notification permission status
4. Verify notification channel ID matches

### Deep Linking Not Working
1. Check `onNotificationTapped` callback is set
2. Verify action data in FCM payload
3. Check Navigator routes exist
4. Test with print statements to debug

## Advanced Usage

### Custom Notification Sounds
Place sound file in `android/app/src/main/res/raw/notification_sound.mp3`
Then reference in channel:
```dart
soundSource: RawResourceAndroidNotificationSound('notification_sound')
```

### Grouping Notifications
Use `summary_id` in Android notification:
```dart
AndroidNotificationDetails(
  // ...
  groupKey: 'heatbubble_alerts',
  setAsGroupSummary: true,
)
```

### Action Buttons
Add buttons to notifications:
```dart
actions: [
  const AndroidNotificationAction('id_1', 'Reply'),
  const AndroidNotificationAction('id_2', 'Dismiss'),
]
```

## Resources

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [Flutter FCM Plugin](https://pub.dev/packages/firebase_messaging)
- [Local Notifications Plugin](https://pub.dev/packages/flutter_local_notifications)
- [Android Notification Docs](https://developer.android.com/guide/topics/ui/notifiers/notifications)
