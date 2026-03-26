/// Model for in-app notifications
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // e.g., 'temperature_alert', 'extreme_temperature', 'custom_alert'
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;
  final String? actionUrl; // For deep linking

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.timestamp,
    required this.isRead,
    this.actionUrl,
  });

  /// Create a copy with modified fields
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    String? actionUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'actionUrl': actionUrl,
    };
  }

  /// Create from JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      actionUrl: json['actionUrl'] as String?,
    );
  }
}
