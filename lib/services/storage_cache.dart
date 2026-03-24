import 'dart:async';
import '../models/temp_reading.dart';

/// Cache layer for frequently accessed storage queries
/// Reduces database hits and improves UI responsiveness
class StorageCache {
  static final StorageCache _instance = StorageCache._internal();
  factory StorageCache() => _instance;
  StorageCache._internal();

  // Cache entries with timestamps
  List<TempReading>? _last7DaysCache;
  DateTime? _last7DaysCacheTime;
  
  double? _sevenDayAverageCache;
  DateTime? _sevenDayAverageCacheTime;
  
  TempReading? _latestCache;
  DateTime? _latestCacheTime;

  // Cache duration: 5 seconds (balance between freshness and performance)
  static const _cacheDuration = Duration(seconds: 5);

  /// Get cached 7-day readings if fresh, otherwise null
  List<TempReading>? getCachedLast7Days() {
    if (_last7DaysCache != null && _last7DaysCacheTime != null) {
      if (DateTime.now().difference(_last7DaysCacheTime!) < _cacheDuration) {
        return _last7DaysCache;
      }
    }
    return null;
  }

  /// Cache 7-day readings
  void cacheLast7Days(List<TempReading> readings) {
    _last7DaysCache = readings;
    _last7DaysCacheTime = DateTime.now();
  }

  /// Get cached 7-day average if fresh, otherwise null
  double? getCachedSevenDayAverage() {
    if (_sevenDayAverageCache != null && _sevenDayAverageCacheTime != null) {
      if (DateTime.now().difference(_sevenDayAverageCacheTime!) < _cacheDuration) {
        return _sevenDayAverageCache;
      }
    }
    return null;
  }

  /// Cache 7-day average
  void cacheSevenDayAverage(double average) {
    _sevenDayAverageCache = average;
    _sevenDayAverageCacheTime = DateTime.now();
  }

  /// Get cached latest reading if fresh, otherwise null
  TempReading? getCachedLatest() {
    if (_latestCache != null && _latestCacheTime != null) {
      if (DateTime.now().difference(_latestCacheTime!) < _cacheDuration) {
        return _latestCache;
      }
    }
    return null;
  }

  /// Cache latest reading
  void cacheLatest(TempReading reading) {
    _latestCache = reading;
    _latestCacheTime = DateTime.now();
  }

  /// Invalidate all caches (call after write operations)
  void invalidateAll() {
    _last7DaysCache = null;
    _last7DaysCacheTime = null;
    _sevenDayAverageCache = null;
    _sevenDayAverageCacheTime = null;
    _latestCache = null;
    _latestCacheTime = null;
  }

  /// Invalidate specific cache
  void invalidateLast7Days() {
    _last7DaysCache = null;
    _last7DaysCacheTime = null;
    _sevenDayAverageCache = null;
    _sevenDayAverageCacheTime = null;
  }
}
