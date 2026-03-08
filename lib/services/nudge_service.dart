import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NudgeService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Call once at app startup
  static Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    const channel = AndroidNotificationChannel(
      'heatbubble_alerts',
      'Temperature Alerts',
      description: 'Notifies when your pocket temperature is unusual.',
      importance: Importance.defaultImportance,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Core AI logic: compare current to 7-day average, nudge if ≥3°C off
  Future<void> checkAndNudge({
    required double currentTemp,
    required double averageTemp,
  }) async {
    if (averageTemp == 0.0) return; // not enough data yet

    final diff = currentTemp - averageTemp;

    if (diff.abs() < 3.0) return; // within normal range, no nudge

    final body = _buildMessage(diff);
    await _sendNotification(body);
  }

  String _buildMessage(double diff) {
    final absDiff = diff.abs().toStringAsFixed(1);
    if (diff > 0) {
      if (diff >= 6) {
        return "🔥 You're $absDiff°C hotter than usual — drink water now.";
      }
      return "🌡️ You're $absDiff°C warmer than usual — stay hydrated!";
    } else {
      if (diff <= -6) {
        return "🧊 You're $absDiff°C colder than usual — are you outside?";
      }
      return "❄️ You're $absDiff°C cooler than usual — somewhere chilly?";
    }
  }

  Future<void> _sendNotification(String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'heatbubble_alerts',
        'Temperature Alerts',
        channelDescription: 'Notifies when your pocket temp is unusual.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(1001, 'HeatBubble', body, details);
  }
}
