import 'package:workmanager/workmanager.dart';
import 'sensor_service.dart';
import 'storage_service.dart';
import 'nudge_service.dart';
import '../models/temp_reading.dart';

const _taskName = 'heatbubble.pollTemp';

void initBackgroundPolling() {
  Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
    ),
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final sensor = SensorService();
      final storage = StorageService();
      final nudge = NudgeService();

      await NudgeService.init();

      final result = await sensor.getCurrentTemp();
      if (!result.success) return true;

      final reading = TempReading(
        temperature: result.calibrated,
        rawTemp: result.raw,
        timestamp: DateTime.now(),
        source: result.source,
      );

      await storage.saveReading(reading);
      await storage.pruneOldReadings();

      final average = await storage.getSevenDayAverage();
      await nudge.checkAndNudge(
        currentTemp: result.calibrated,
        averageTemp: average,
      );

      return true;
    } catch (e) {
      return true;
    }
  });
}
