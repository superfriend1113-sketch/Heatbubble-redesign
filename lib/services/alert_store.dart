import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple persistent store for fired temperature alerts.
/// Saved as a JSON list in SharedPreferences — no Isar schema needed.
class AlertStore {
  static const _key = 'heatbubble_alert_history';
  static const _maxAlerts = 20; // keep latest 20

  // ── Save a new alert ─────────────────────────────────
  static Future<void> save(AlertRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _loadList(prefs);
    list.insert(0, record); // newest first
    if (list.length > _maxAlerts) list.removeLast();
    await prefs.setString(_key, jsonEncode(list.map((r) => r.toJson()).toList()));
  }

  // ── Load all alerts (newest first) ───────────────────
  static Future<List<AlertRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadList(prefs);
  }

  static Future<List<AlertRecord>> _loadList(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => AlertRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

// ── Alert types ───────────────────────────────────────
enum AlertType { extremeCold, extremeHeat, risingTrend, fallingTrend, stable }

class AlertRecord {
  final AlertType type;
  final String message;
  final DateTime timestamp;

  const AlertRecord({
    required this.type,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AlertRecord.fromJson(Map<String, dynamic> json) => AlertRecord(
        type: AlertType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AlertType.stable,
        ),
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'less than a minute ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
