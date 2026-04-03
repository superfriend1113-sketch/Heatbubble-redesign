import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'alert_store.dart';
import 'comparison_service.dart';
import 'unit_service.dart';

// ── Temperature thresholds (always in °C) ──────────────
//   0 °F  = −17.78 °C  →  extreme cold
// 105 °F  =  40.56 °C  →  extreme heat
const double _extremeColdCelsius = -17.78;
const double _extremeHeatCelsius = 40.56;

class NudgeService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Call once at app startup (and in background callbackDispatcher).
  static Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // ── Standard alerts channel (high priority for pop-up) ──
    const standardChannel = AndroidNotificationChannel(
      'heatbubble_alerts',
      'Temperature Alerts',
      description: 'Notifies when your pocket temperature is unusual.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // ── Extreme alerts channel v2 — max priority, bypasses cache ──
    const extremeChannel = AndroidNotificationChannel(
      'heatbubble_extreme_v2',
      'Extreme Temperature Alerts',
      description: 'Urgent alerts for dangerously hot or cold conditions.',
      importance: Importance.max,           // heads-up even on lock screen
      playSound: true,
      enableVibration: true,
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(standardChannel);
    await androidImpl?.createNotificationChannel(extremeChannel);

    _initialized = true;
  }

  // ─────────────────────────────────────────────────────
  // Extreme temperature check — fired every background cycle
  // ─────────────────────────────────────────────────────
  Future<void> checkExtremeTemp(double celsius) async {
    // Check if notifications and temperature alerts are enabled
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    final temperatureAlerts = prefs.getBool('temperature_alerts') ?? true;
    
    if (!notificationsEnabled || !temperatureAlerts) return;
    
    if (celsius <= _extremeColdCelsius) {
      const message = "🥶 Seek shelter — I hope you're dressed for the cold weather!";
      await _sendExtremeNotification(
        id: 2001,
        title: 'HeatBubble — Extreme Cold ❄️',
        body: message,
      );
      await AlertStore.save(AlertRecord(
        type: AlertType.extremeCold,
        message: message,
        timestamp: DateTime.now(),
      ));
    } else if (celsius >= _extremeHeatCelsius) {
      const message = '🌡️ Seek shelter or shade and stay hydrated!';
      await _sendExtremeNotification(
        id: 2002,
        title: 'HeatBubble — Extreme Heat 🔥',
        body: message,
      );
      await AlertStore.save(AlertRecord(
        type: AlertType.extremeHeat,
        message: message,
        timestamp: DateTime.now(),
      ));
    }
    // Mid-range: no notification
  }

  // ── Test helpers (called from Settings screen) ────────
  Future<void> testColdAlert() async {
    const message = "🥶 Seek shelter — I hope you're dressed for the cold weather!";
    await _sendExtremeNotification(id: 2001, title: 'HeatBubble — Extreme Cold ❄️', body: message);
    await AlertStore.save(AlertRecord(type: AlertType.extremeCold, message: message, timestamp: DateTime.now()));
  }

  Future<void> testHeatAlert() async {
    const message = '🌡️ Seek shelter or shade and stay hydrated!';
    await _sendExtremeNotification(id: 2002, title: 'HeatBubble — Extreme Heat 🔥', body: message);
    await AlertStore.save(AlertRecord(type: AlertType.extremeHeat, message: message, timestamp: DateTime.now()));
  }

  Future<void> _sendExtremeNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'heatbubble_extreme_v2',          // new channel ID — bypasses Android cache
        'Extreme Temperature Alerts',
        channelDescription: 'Urgent alerts for dangerously hot or cold conditions.',
        importance: Importance.max,        // MAX = guaranteed heads-up
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,            // shows even when screen is off / app open
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  // ─────────────────────────────────────────────────────
  // Existing relative-nudge logic (unchanged)
  // ─────────────────────────────────────────────────────
  Future<void> checkAndNudge({
    required double currentTemp,
    required double averageTemp,
  }) async {
    // Check if notifications and trend alerts are enabled
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    final trendAlerts = prefs.getBool('trend_alerts') ?? true;
    
    if (!notificationsEnabled || !trendAlerts) return;
    
    if (averageTemp == 0.0) return;
    final diff = currentTemp - averageTemp;
    if (diff.abs() < 3.0) return;

    final body = _buildMessage(diff);
    await _sendStandardNotification(body);

    // Persist to alert history
    await AlertStore.save(AlertRecord(
      type: diff > 0 ? AlertType.risingTrend : AlertType.fallingTrend,
      message: body,
      timestamp: DateTime.now(),
    ));
  }

  String _buildMessage(double diff) {
    final us = UnitService.instance;
    final absDiff = us.formatValue(diff.abs());
    
    if (diff > 0) {
      if (diff >= 6) return "🔥 You're $absDiff hotter than usual — drink water now.";
      return "🌡️ You're $absDiff warmer than usual — stay hydrated!";
    } else {
      if (diff <= -6) return "🧊 You're $absDiff colder than usual — are you outside?";
      return "❄️ You're $absDiff cooler than usual — somewhere chilly?";
    }
  }

  Future<void> _sendStandardNotification(String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'heatbubble_alerts',
        'Temperature Alerts',
        channelDescription: 'Notifies when your pocket temp is unusual.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      ),
    );
    await _plugin.show(1001, 'HeatBubble', body, details);
  }

  /// Send custom notification (used by custom alerts)
  Future<void> sendNotification({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'heatbubble_alerts',
        'Temperature Alerts',
        channelDescription: 'Notifies when your pocket temp is unusual.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      ),
    );
    // Use a unique ID based on time
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _plugin.show(id, title, body, details);
  }

  // ─────────────────────────────────────────────────────
  // Comparison-based notification (random interval)
  // ─────────────────────────────────────────────────────
  Future<void> sendComparisonNotification(ComparisonResult result) async {
    // Check if notifications and trend alerts are enabled
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    final trendAlerts = prefs.getBool('trend_alerts') ?? true;
    
    if (!notificationsEnabled || !trendAlerts) return;
    
    await _sendStandardNotification(result.message);

    final alertType = result.diff > 0 ? AlertType.risingTrend
                    : result.diff < -0.3 ? AlertType.fallingTrend
                    : AlertType.stable;

    await AlertStore.save(AlertRecord(
      type: alertType,
      message: result.message,
      timestamp: DateTime.now(),
    ));
  }

  // ─────────────────────────────────────────────────────
  // Daily Reminder - scheduled notification
  // ─────────────────────────────────────────────────────
  Future<void> scheduleDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    final dailyReminders = prefs.getBool('daily_reminders') ?? false;
    
    if (!notificationsEnabled || !dailyReminders) {
      // Cancel any existing daily reminder
      await _plugin.cancel(3000);
      return;
    }

    // Schedule daily notification at 9 AM
    await _plugin.zonedSchedule(
      3000, // Unique ID for daily reminder
      'HeatBubble Daily Reminder',
      '🌡️ Don\'t forget to check your temperature today!',
      _nextInstanceOf9AM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'heatbubble_alerts',
          'Temperature Alerts',
          channelDescription: 'Notifies when your pocket temp is unusual.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  tz.TZDateTime _nextInstanceOf9AM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}

