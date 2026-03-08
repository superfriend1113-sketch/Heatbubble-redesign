import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/temp_reading.dart';

class StorageService {
  static Isar? _isar;

  Future<Isar> get db async {
    // 1. Cached Dart reference still open
    if (_isar != null && _isar!.isOpen) return _isar!;

    // 2. Native instance already open (e.g. after hot restart)
    //    getInstance() returns the default unnamed instance or null
    final existing = Isar.getInstance();
    if (existing != null && existing.isOpen) {
      _isar = existing;
      return _isar!;
    }

    // 3. Fresh open
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [TempReadingSchema],
      directory: dir.path,
    );
    return _isar!;
  }

  Future<void> saveReading(TempReading reading) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.tempReadings.put(reading);
    });
  }

  /// Last 24 hours of readings
  Future<List<TempReading>> getLast24Hours() async {
    final isar = await db;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return isar.tempReadings
        .filter()
        .timestampGreaterThan(cutoff)
        .sortByTimestamp()
        .findAll();
  }

  /// Last 7 days of readings
  Future<List<TempReading>> getLast7Days() async {
    final isar = await db;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return isar.tempReadings
        .filter()
        .timestampGreaterThan(cutoff)
        .sortByTimestamp()
        .findAll();
  }

  /// 7-day rolling average (for AI nudge baseline)
  Future<double> getSevenDayAverage() async {
    final isar = await db;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final readings = await isar.tempReadings
        .filter()
        .timestampGreaterThan(cutoff)
        .findAll();

    if (readings.isEmpty) return 0.0;
    final sum = readings.fold(0.0, (acc, r) => acc + r.temperature);
    return sum / readings.length;
  }

  /// Most recent reading
  Future<TempReading?> getLatest() async {
    final isar = await db;
    return isar.tempReadings.where().sortByTimestampDesc().findFirst();
  }

  /// Get min temp from last 7 days
  Future<double> getMin7Days() async {
    final readings = await getLast7Days();
    if (readings.isEmpty) return 0.0;
    return readings.map((r) => r.temperature).reduce((a, b) => a < b ? a : b);
  }

  /// Get max temp from last 7 days
  Future<double> getMax7Days() async {
    final readings = await getLast7Days();
    if (readings.isEmpty) return 0.0;
    return readings.map((r) => r.temperature).reduce((a, b) => a > b ? a : b);
  }

  /// Get total reading count
  Future<int> getTotalCount() async {
    final isar = await db;
    return isar.tempReadings.count();
  }

  /// Count distinct calendar days that have at least one reading
  Future<int> getUniqueDaysCount() async {
    final isar = await db;
    final all = await isar.tempReadings.where().findAll();
    final days = all
        .map((r) =>
            '${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}')
        .toSet();
    return days.length;
  }

  /// Current streak: consecutive days ending today that have readings
  Future<int> getCurrentStreak() async {
    final isar = await db;
    final all = await isar.tempReadings
        .where()
        .sortByTimestampDesc()
        .findAll();
    if (all.isEmpty) return 0;

    final daySet = all
        .map((r) => DateTime(
            r.timestamp.year, r.timestamp.month, r.timestamp.day))
        .toSet();

    int streak = 0;
    DateTime check = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    while (daySet.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Purge readings older than 30 days
  Future<void> pruneOldReadings() async {
    final isar = await db;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    await isar.writeTxn(() async {
      await isar.tempReadings
          .filter()
          .timestampLessThan(cutoff)
          .deleteAll();
    });
  }
}
