import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'alert_store.dart';
import 'comparison_service.dart';

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

    // ── Standard alerts channel (existing) ──
    const standardChannel = AndroidNotificationChannel(
      'heatbubble_alerts',
      'Temperature Alerts',
      description: 'Notifies when your pocket temperature is unusual.',
      importance: Importance.defaultImportance,
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
    final absDiff = diff.abs().toStringAsFixed(1);
    if (diff > 0) {
      if (diff >= 6) return "🔥 You're $absDiff°C hotter than usual — drink water now.";
      return "🌡️ You're $absDiff°C warmer than usual — stay hydrated!";
    } else {
      if (diff <= -6) return "🧊 You're $absDiff°C colder than usual — are you outside?";
      return "❄️ You're $absDiff°C cooler than usual — somewhere chilly?";
    }
  }

  Future<void> _sendStandardNotification(String body) async {
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
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
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
    final title = _comparisonTitle(result.type);
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

  String _comparisonTitle(ComparisonType type) {
    switch (type) {
      case ComparisonType.hoursAgo:
        return 'HeatBubble — Hourly Check';
      case ComparisonType.yesterdaySameTime:
        return 'HeatBubble — Daily Compare';
      case ComparisonType.dailyAverage:
        return 'HeatBubble — Today\'s Trend';
      case ComparisonType.weekAverage:
        return 'HeatBubble — Weekly Insight';
    }
  }
}

