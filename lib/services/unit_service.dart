import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TempUnit { celsius, fahrenheit }

/// Global singleton ChangeNotifier for temperature unit.
/// All screens subscribe via ListenableBuilder — unit switches propagate
/// instantly app-wide with zero prop-drilling.
class UnitService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────
  static final UnitService instance = UnitService._();
  UnitService._();

  static const _prefKey = 'temp_unit';

  TempUnit _unit = TempUnit.celsius;

  // ── Getters ──────────────────────────────────────────
  TempUnit get unit => _unit;
  bool get isCelsius => _unit == TempUnit.celsius;
  bool get isFahrenheit => _unit == TempUnit.fahrenheit;
  String get symbol => _unit == TempUnit.celsius ? '°C' : '°F';
  String get unitName => _unit == TempUnit.celsius ? 'Celsius' : 'Fahrenheit';

  // ── Load from SharedPreferences ───────────────────────
  /// Call once at app startup (before runApp).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _unit = saved == 'fahrenheit' ? TempUnit.fahrenheit : TempUnit.celsius;
    // No notifyListeners — called before UI tree exists
  }

  // ── Toggle / set ──────────────────────────────────────
  Future<void> setUnit(TempUnit unit) async {
    if (_unit == unit) return;
    _unit = unit;
    notifyListeners(); // instantly updates all ListenableBuilder subscribers
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, unit.name);
  }

  Future<void> toggle() =>
      setUnit(_unit == TempUnit.celsius ? TempUnit.fahrenheit : TempUnit.celsius);

  // ── Conversion helpers ────────────────────────────────
  /// Convert a Celsius value to the currently selected unit.
  double convert(double celsius) =>
      _unit == TempUnit.celsius ? celsius : (celsius * 9 / 5) + 32;

  /// Format a Celsius value as a display string with unit symbol.
  String format(double celsius, {int decimals = 1}) =>
      '${convert(celsius).toStringAsFixed(decimals)}$symbol';

  /// Format just the numeric value (no symbol).
  String formatValue(double celsius, {int decimals = 1}) =>
      convert(celsius).toStringAsFixed(decimals);

  // ── Threshold helpers (for state detection) ───────────
  /// Always evaluate state in Celsius regardless of display unit.
  /// Normal body temp range: 35.0–39.9 °C
  bool isNormal(double celsius) => celsius >= 35.0 && celsius < 40.0;
  bool isElevated(double celsius) => celsius >= 40.0;
  bool isLow(double celsius) => celsius < 35.0;
}
