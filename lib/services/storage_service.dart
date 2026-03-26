import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/temp_reading.dart';
import '../models/alert.dart';
import 'storage_cache.dart';

class StorageService {
  static Isar? _isar;
  final _cache = StorageCache();

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
      [TempReadingSchema, AlertSchema],
      directory: dir.path,
    );
    return _isar!;
  }

  Future<void> saveReading(TempReading reading) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.tempReadings.put(reading);
    });
    // Invalidate caches after write
    _cache.invalidateAll();
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

  /// Last 7 days of readings (with caching)
  Future<List<TempReading>> getLast7Days() async {
    // Check cache first
    final cached = _cache.getCachedLast7Days();
    if (cached != null) return cached;
    
    // Cache miss - query database
    final isar = await db;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final readings = await isar.tempReadings
        .filter()
        .timestampGreaterThan(cutoff)
        .sortByTimestamp()
        .findAll();
    
    // Update cache
    _cache.cacheLast7Days(readings);
    return readings;
  }

  /// 7-day rolling average (for AI nudge baseline) - with caching
  Future<double> getSevenDayAverage() async {
    // Check cache first
    final cached = _cache.getCachedSevenDayAverage();
    if (cached != null) return cached;
    
    // Cache miss - query database
    final isar = await db;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final readings = await isar.tempReadings
        .filter()
        .timestampGreaterThan(cutoff)
        .findAll();

    if (readings.isEmpty) return 0.0;
    final sum = readings.fold(0.0, (acc, r) => acc + r.temperature);
    final average = sum / readings.length;
    
    // Update cache
    _cache.cacheSevenDayAverage(average);
    return average;
  }

  /// Most recent reading (with caching)
  Future<TempReading?> getLatest() async {
    // Check cache first
    final cached = _cache.getCachedLatest();
    if (cached != null) return cached;
    
    // Cache miss - query database
    final isar = await db;
    final latest = await isar.tempReadings.where().sortByTimestampDesc().findFirst();
    
    // Update cache
    if (latest != null) {
      _cache.cacheLatest(latest);
    }
    return latest;
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

  /// Get all readings (use with caution - can be large dataset)
  /// For smart sync aggregation only
  Future<List<TempReading>> getAllReadings() async {
    final isar = await db;
    return isar.tempReadings
        .where()
        .sortByTimestamp()
        .findAll();
  }

  /// Count distinct calendar days that have at least one reading
  /// Optimized: Uses aggregation instead of loading all readings
  Future<int> getUniqueDaysCount() async {
    final isar = await db;
    // Get only timestamps, not full objects
    final timestamps = await isar.tempReadings
        .where()
        .timestampProperty()
        .findAll();
    
    if (timestamps.isEmpty) return 0;
    
    final days = timestamps
        .map((ts) => DateTime(ts.year, ts.month, ts.day).millisecondsSinceEpoch)
        .toSet();
    return days.length;
  }

  /// Current streak: consecutive days ending today that have readings
  /// Optimized: Uses timestamps only and limits query range
  Future<int> getCurrentStreak() async {
    final isar = await db;
    
    // Only check last 365 days max (reasonable streak limit)
    final maxLookback = DateTime.now().subtract(const Duration(days: 365));
    final timestamps = await isar.tempReadings
        .filter()
        .timestampGreaterThan(maxLookback)
        .timestampProperty()
        .findAll();
    
    if (timestamps.isEmpty) return 0;

    // Convert to day-level precision (milliseconds since epoch)
    final daySet = timestamps
        .map((ts) => DateTime(ts.year, ts.month, ts.day).millisecondsSinceEpoch)
        .toSet();

    int streak = 0;
    final now = DateTime.now();
    DateTime check = DateTime(now.year, now.month, now.day);
    
    while (daySet.contains(check.millisecondsSinceEpoch)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
      // Safety limit
      if (streak > 365) break;
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
    // Invalidate caches after delete
    _cache.invalidateAll();
  }

  /// Find the reading closest to [hoursAgo] hours in the past.
  /// Searches within a ±30-minute window around the target time.
  /// Returns null if no reading exists in that window.
  Future<TempReading?> getReadingNearTime(double hoursAgo) async {
    final isar = await db;
    final target = DateTime.now().subtract(
      Duration(minutes: (hoursAgo * 60).round()),
    );
    final windowStart = target.subtract(const Duration(minutes: 30));
    final windowEnd   = target.add(const Duration(minutes: 30));

    final candidates = await isar.tempReadings
        .filter()
        .timestampGreaterThan(windowStart)
        .timestampLessThan(windowEnd)
        .findAll();

    if (candidates.isEmpty) return null;

    // Pick the one closest in time to the target
    candidates.sort((a, b) =>
      a.timestamp.difference(target).abs().compareTo(
      b.timestamp.difference(target).abs()));
    return candidates.first;
  }

  /// All readings between [from] and [to] (inclusive).
  Future<List<TempReading>> getReadingsInWindow(
      DateTime from, DateTime to) async {
    final isar = await db;
    return isar.tempReadings
        .filter()
        .timestampGreaterThan(from)
        .timestampLessThan(to)
        .sortByTimestamp()
        .findAll();
  }
}
