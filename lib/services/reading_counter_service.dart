import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to track temperature readings and trigger upgrade prompts
class ReadingCounterService {
  static final ReadingCounterService _instance = ReadingCounterService._internal();
  factory ReadingCounterService() => _instance;
  ReadingCounterService._internal();

  static const String _countKey = 'reading_count';
  static const String _lastPromptKey = 'last_upgrade_prompt';
  static const int _promptInterval = 10; // Show prompt every 10 readings

  int _count = 0;
  DateTime? _lastPromptTime;

  /// Initialize the counter from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _count = prefs.getInt(_countKey) ?? 0;
    
    final lastPromptStr = prefs.getString(_lastPromptKey);
    if (lastPromptStr != null) {
      _lastPromptTime = DateTime.tryParse(lastPromptStr);
    }
    
  }

  /// Increment reading count
  Future<void> increment() async {
    _count++;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, _count);
    
  }

  /// Check if upgrade prompt should be shown
  bool shouldShowUpgradePrompt() {
    // Show every 10 readings
    if (_count % _promptInterval != 0) {
      return false;
    }

    // Don't show if already shown in last 5 minutes
    if (_lastPromptTime != null) {
      final minutesSinceLastPrompt = DateTime.now().difference(_lastPromptTime!).inMinutes;
      if (minutesSinceLastPrompt < 5) {
        return false;
      }
    }

    return true;
  }

  /// Mark that upgrade prompt was shown
  Future<void> markPromptShown() async {
    _lastPromptTime = DateTime.now();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPromptKey, _lastPromptTime!.toIso8601String());
    
  }

  /// Reset counter (e.g., after upgrade)
  Future<void> reset() async {
    _count = 0;
    _lastPromptTime = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey);
    await prefs.remove(_lastPromptKey);
    
  }

  /// Get current count
  int get count => _count;
}
