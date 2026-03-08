import 'package:isar/isar.dart';

part 'temp_reading.g.dart';

@collection
class TempReading {
  Id id = Isar.autoIncrement;

  late double temperature; // °C — battery temp with calibration offset applied
  late double rawTemp; // raw battery °C before offset

  @Index()
  late DateTime timestamp;

  // Source: 'battery', 'ambient', 'ble'
  late String source;

  TempReading({
    required this.temperature,
    required this.rawTemp,
    required this.timestamp,
    this.source = 'battery',
  });
}
