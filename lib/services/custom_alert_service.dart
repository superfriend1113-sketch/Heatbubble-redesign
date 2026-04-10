import 'package:isar/isar.dart';
import '../models/alert.dart';
import 'nudge_service.dart';

class CustomAlertService {
  static final CustomAlertService _instance = CustomAlertService._internal();

  factory CustomAlertService() {
    return _instance;
  }

  CustomAlertService._internal();

  late Isar _isar;
  final NudgeService _nudge = NudgeService();

  Future<void> init(Isar isar) async {
    _isar = isar;
  }

  /// Create new custom alert
  Future<void> createAlert({
    required String name,
    required double threshold,
    required String unit, // 'C', 'F', 'K'
    required String condition, // 'above', 'below'
  }) async {
    final alert = Alert(
      name: name,
      threshold: threshold,
      unit: unit,
      condition: condition,
      isActive: true,
    );

    await _isar.writeTxn(() async {
      await _isar.alerts.put(alert);
    });
  }

  /// Get all custom alerts
  Future<List<Alert>> getAllAlerts() async {
    return await _isar.alerts.where().findAll();
  }

  /// Get active alerts only
  Future<List<Alert>> getActiveAlerts() async {
    return await _isar.alerts.where().filter().isActiveEqualTo(true).findAll();
  }

  /// Update alert
  Future<void> updateAlert(Alert alert) async {
    await _isar.writeTxn(() async {
      await _isar.alerts.put(alert);
    });
  }

  /// Delete alert
  Future<void> deleteAlert(int id) async {
    await _isar.writeTxn(() async {
      await _isar.alerts.delete(id);
    });
  }

  /// Toggle alert active/inactive
  Future<void> toggleAlert(int id) async {
    final alert = await _isar.alerts.get(id);
    if (alert != null) {
      alert.isActive = !alert.isActive;
      await updateAlert(alert);
    }
  }

  /// Check if alert should trigger for current temperature
  /// Returns true if any alert was triggered
  Future<bool> checkAlerts(double currentTempCelsius) async {
    final activeAlerts = await getActiveAlerts();
    bool anyTriggered = false;

    for (final alert in activeAlerts) {
      if (alert.shouldTrigger(currentTempCelsius)) {
        // Check if we should trigger (avoid spam - only trigger once per 5 minutes)
        final lastTrigger = await _getLastTriggerTime(alert.id);
        final now = DateTime.now();
        
        if (lastTrigger == null || now.difference(lastTrigger).inMinutes >= 5) {
          await _triggerAlert(alert, currentTempCelsius);
          await _setLastTriggerTime(alert.id, now);
          anyTriggered = true;
        }
      }
    }
    
    return anyTriggered;
  }

  /// Trigger notification for alert
  Future<void> _triggerAlert(Alert alert, double currentTemp) async {
    // Increment trigger count
    alert.triggerCount = (alert.triggerCount ?? 0) + 1;
    await updateAlert(alert);

    // Convert temperature to alert's unit for display
    double displayTemp = currentTemp;
    if (alert.unit == 'F') {
      displayTemp = (currentTemp * 9 / 5) + 32;
    } else if (alert.unit == 'K') {
      displayTemp = currentTemp + 273.15;
    }

    // Send notification via nudge service
    final tempStr = '${displayTemp.toStringAsFixed(1)}°${alert.unit}';
    final thresholdStr = '${alert.threshold.toStringAsFixed(1)}°${alert.unit}';
    
    await _nudge.sendNotification(
      title: '🚨 ${alert.name}',
      body: 'Temperature is $tempStr (${alert.condition} $thresholdStr)',
    );
  }

  // Track last trigger times to avoid spam
  final Map<int, DateTime> _lastTriggerTimes = {};

  Future<DateTime?> _getLastTriggerTime(int alertId) async {
    return _lastTriggerTimes[alertId];
  }

  Future<void> _setLastTriggerTime(int alertId, DateTime time) async {
    _lastTriggerTimes[alertId] = time;
  }

  /// Get alert statistics
  Future<Map<String, dynamic>> getAlertStats() async {
    final alerts = await getAllAlerts();
    int totalTriggers = 0;
    
    for (final alert in alerts) {
      totalTriggers += alert.triggerCount ?? 0;
    }

    return {
      'total_alerts': alerts.length,
      'active_alerts': alerts.where((a) => a.isActive).length,
      'total_triggers': totalTriggers,
    };
  }

  /// Clear all trigger counts
  Future<void> clearTriggerCounts() async {
    final alerts = await getAllAlerts();
    for (final alert in alerts) {
      alert.triggerCount = 0;
      await updateAlert(alert);
    }
  }

  /// Preset alert thresholds (as suggested by client)
  static final Map<String, List<double>> presetThresholds = {
    'C': [0.0, 37.8],
    'F': [32.0, 100.0],
    'K': [273.15, 310.9],
  };
}
