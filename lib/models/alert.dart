import 'package:isar/isar.dart';

part 'alert.g.dart';

@collection
class Alert {
  Id id = Isar.autoIncrement;

  late String name; // e.g., "Office too hot"
  late double threshold; // Temperature value
  late String unit; // 'C', 'F', or 'K'
  late String condition; // 'above' or 'below'
  
  @Index()
  late DateTime createdAt;
  
  late bool isActive;
  late int? triggerCount; // How many times triggered

  Alert({
    required this.name,
    required this.threshold,
    required this.unit,
    required this.condition,
    this.isActive = true,
    this.triggerCount = 0,
  }) {
    createdAt = DateTime.now();
  }

  /// Convert threshold to Celsius for comparison
  double get thresholdInCelsius {
    if (unit == 'C') return threshold;
    if (unit == 'F') return (threshold - 32) * 5 / 9;
    // Kelvin
    return threshold - 273.15;
  }

  /// Check if alert should trigger
  bool shouldTrigger(double currentTempCelsius) {
    if (!isActive) return false;

    if (condition == 'above') {
      return currentTempCelsius > thresholdInCelsius;
    } else {
      return currentTempCelsius < thresholdInCelsius;
    }
  }

  @override
  String toString() => 'Alert($name: $threshold$unit $condition)';
}
