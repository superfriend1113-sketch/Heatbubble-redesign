import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SensorService {
  static const _channel = MethodChannel('heatbubble/temperature');

  // ── Calibration ─────────────────────────────────────
  static const double _defaultOffset = -6.0;
  static const String _calibrationKey = 'calibration_offset';

  Future<double> getCalibrationOffset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_calibrationKey) ?? _defaultOffset;
  }

  Future<void> saveCalibrationOffset(double offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_calibrationKey, offset);
  }

  Future<bool> hasCustomCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_calibrationKey);
  }

  // ── Charging state ───────────────────────────────────
  Future<bool> isCharging() async {
    try {
      return await _channel.invokeMethod('isCharging') as bool;
    } catch (_) {
      return false;
    }
  }

  // ── Single raw reading ────────────────────────────────
  Future<double?> _getRawTemp() async {
    try {
      final double raw = await _channel.invokeMethod('getBatteryTemp');
      return raw;
    } on PlatformException {
      return null;
    }
  }

  // ── Multi-sample averaged reading ─────────────────────
  /// Takes [samples] readings 800ms apart, drops the highest outlier,
  /// and returns the averaged calibrated result.
  /// OPTIMIZED: Runs in background to avoid blocking main thread
  Future<SensorResult> getCurrentTemp({int samples = 5}) async {
    final offset = await getCalibrationOffset();
    final charging = await isCharging();

    // Collect samples in background
    final rawList = <double>[];
    for (int i = 0; i < samples; i++) {
      final r = await _getRawTemp();
      if (r != null) rawList.add(r);
      if (i < samples - 1) {
        // Use shorter delay to reduce total blocking time
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (rawList.isEmpty) {
      return SensorResult(
        raw: 0,
        calibrated: 0,
        source: 'battery',
        success: false,
        isCharging: charging,
        isStable: false,
        sampleCount: 0,
        error: 'No sensor readings available',
      );
    }

    // Compute statistics in background isolate for heavy calculations
    final result = await _computeStatistics(rawList, offset, charging);
    return result;
  }

  /// Compute statistics in background to avoid blocking UI
  static Future<SensorResult> _computeStatistics(
    List<double> rawList,
    double offset,
    bool charging,
  ) async {
    // For small datasets, compute directly (isolate overhead not worth it)
    if (rawList.length < 5) {
      return _computeStatisticsSync(rawList, offset, charging);
    }

    // For larger datasets, use compute (background isolate)
    try {
      return await Isolate.run(() => _computeStatisticsSync(rawList, offset, charging));
    } catch (_) {
      // Fallback to sync if isolate fails
      return _computeStatisticsSync(rawList, offset, charging);
    }
  }

  /// Synchronous statistics computation (runs in isolate or main thread)
  static SensorResult _computeStatisticsSync(
    List<double> rawList,
    double offset,
    bool charging,
  ) {
    // Drop highest outlier when we have 3+ samples
    final working = List<double>.from(rawList)..sort();
    if (working.length >= 3) working.removeLast();

    final rawAvg = working.reduce((a, b) => a + b) / working.length;

    // Stability = std dev < 0.3°C
    final variance = working
            .map((s) => (s - rawAvg) * (s - rawAvg))
            .reduce((a, b) => a + b) /
        working.length;
    final isStable = variance < 0.09;

    return SensorResult(
      raw: rawAvg,
      calibrated: rawAvg + offset,
      source: 'battery',
      success: true,
      isCharging: charging,
      isStable: isStable,
      sampleCount: working.length,
    );
  }

  Future<bool> hasAmbientSensor() async {
    try {
      return await _channel.invokeMethod('hasAmbientSensor') as bool;
    } catch (_) {
      return false;
    }
  }
}

// ── Result model ─────────────────────────────────────
class SensorResult {
  final double raw;
  final double calibrated;
  final String source;
  final bool success;
  final bool isCharging;
  final bool isStable;
  final int sampleCount;
  final String? error;

  const SensorResult({
    required this.raw,
    required this.calibrated,
    required this.source,
    required this.success,
    required this.isCharging,
    required this.isStable,
    required this.sampleCount,
    this.error,
  });
}
