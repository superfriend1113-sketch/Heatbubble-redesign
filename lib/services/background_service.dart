import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'storage_service.dart';
import 'nudge_service.dart';
import 'comparison_service.dart';

const _taskName = 'heatbubble.pollTemp';

void initBackgroundPolling() {
  Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update, // always re-register
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
    ),
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final storage    = StorageService();
      final nudge      = NudgeService();
      final comparison = ComparisonService(storage: storage);

      await NudgeService.init();

      // ── Background: use the last saved reading from DB ──
      // MethodChannel (sensor) is NOT available in background isolate,
      // so we rely on foreground-saved readings for comparison.
      final latest = await storage.getLatest();
      if (latest == null) return true;

      // Only use readings that are reasonably fresh (< 30 min old)
      final age = DateTime.now().difference(latest.timestamp);
      if (age.inMinutes > 30) return true;

      final currentTemp = latest.temperature;

      await storage.pruneOldReadings();

      // ── Threshold-based nudges ──
      final average = await storage.getSevenDayAverage();
      await nudge.checkAndNudge(
        currentTemp: currentTemp,
        averageTemp: average,
      );

      // ── Extreme temperature alerts ──
      await nudge.checkExtremeTemp(currentTemp);

      // ── Random-interval comparison notification ──
      if (await comparison.isNotificationDue()) {
        final compResult = await comparison.compare(currentTemp);
        if (compResult != null) {
          await nudge.sendComparisonNotification(compResult);
        }
        await comparison.scheduleNext();
      }

      return true;
    } catch (e) {
      return true;
    }
  });
}
