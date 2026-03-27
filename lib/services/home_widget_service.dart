import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'unit_service.dart';

/// Pushes live temperature readings to the Android home screen widget.
///
/// Storage: "HomeWidgetPreferences" file, raw keys (no prefix).
/// Keys read by HeatBubbleWidget.kt:
///   hw_temperature  → e.g. "36.7°C"
///   hw_trend        → "Rising" | "Stable" | "Falling"
///   hw_alert        → "true" | "false"
///   hw_updated      → "18:32"
///   hw_status       → "Normal" | "Warm" | "Elevated" | "Fever Alert"
///   hw_is_premium   → "true" | "false"  ← gates widget content on the native side
class HomeWidgetService {
  static const String _appGroupId        = 'group.com.example.heatbubble';
  static const String _androidWidgetName = 'HeatBubbleWidget';

  static const String _keyTemp      = 'hw_temperature';
  static const String _keyTrend     = 'hw_trend';
  static const String _keyAlert     = 'hw_alert';
  static const String _keyUpdated   = 'hw_updated';
  static const String _keyStatus    = 'hw_status';
  static const String _keyIsPremium = 'hw_is_premium';

  /// Saves temperature data and triggers an Android widget refresh.
  /// [isPremium] controls whether the widget shows temp data or a lock screen.
  Future<void> updateWidget({
    required double temperature,
    required String trend,
    required TempUnit unit,
    required bool isPremium,
  }) async {
    try {
      final formatted = temperature > 0
          ? UnitService.instance.format(temperature)
          : '--';
      final isAlert = isPremium && trend == 'Rising' && temperature > 37.5;
      final status  = isPremium ? _statusLabel(temperature) : 'Premium';
      final now     = _timeString();

      await HomeWidget.saveWidgetData<String>(_keyTemp,      formatted);
      await HomeWidget.saveWidgetData<String>(_keyTrend,     trend);
      await HomeWidget.saveWidgetData<String>(_keyAlert,     isAlert.toString());
      await HomeWidget.saveWidgetData<String>(_keyUpdated,   now);
      await HomeWidget.saveWidgetData<String>(_keyStatus,    status);
      await HomeWidget.saveWidgetData<String>(_keyIsPremium, isPremium.toString());

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'com.example.heatbubble.$_androidWidgetName',
      );

      debugPrint('📱 [HomeWidget] $formatted | $trend | $status | premium=$isPremium');
    } catch (e) {
      debugPrint('⚠️  [HomeWidget] updateWidget failed: $e');
    }
  }

  String _statusLabel(double tempC) {
    if (tempC <= 0)   return 'No data';
    if (tempC < 34.0) return 'Cool';
    if (tempC < 35.5) return 'Normal';
    if (tempC < 37.0) return 'Warm';
    if (tempC < 37.5) return 'Elevated';
    return 'Fever Alert';
  }

  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      debugPrint('📱 [HomeWidget] Initialized');
    } catch (e) {
      debugPrint('⚠️  [HomeWidget] init failed: $e');
    }
  }

  String _timeString() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
