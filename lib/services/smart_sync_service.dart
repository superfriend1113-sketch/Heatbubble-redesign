import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/temp_reading.dart';
import 'firebase_auth_service.dart';
import 'firebase_firestore_service.dart';
import 'storage_service.dart';

/// Smart sync service that optimizes cloud storage
/// Strategy:
/// 1. Store ALL readings locally (Isar)
/// 2. Sync only AGGREGATED data to Firestore (hourly/daily summaries)
/// 3. Sync individual readings only for last 7 days
/// 4. Keep historical aggregates forever (cheap storage)
class SmartSyncService {
  static final SmartSyncService _instance = SmartSyncService._internal();
  factory SmartSyncService() => _instance;
  SmartSyncService._internal();

  final _auth = FirebaseAuthService();
  final _firestore = FirebaseFirestoreService();
  final _storage = StorageService();

  static const String _lastSyncKey = 'last_smart_sync';
  static const String _lastAggregateKey = 'last_aggregate_sync';

  /// Sync strategy:
  /// - NO individual readings synced to cloud (all stored locally)
  /// - Aggregated data only: Hourly summaries (forever)
  /// - Daily summaries: Forever
  /// - Even cheaper and more private!
  Future<void> smartSync() async {
    if (!_auth.isSignedIn) {
      debugPrint('⚠️  [SmartSync] Not signed in, skipping sync');
      return;
    }

    try {
      debugPrint('🔄 [SmartSync] Starting smart sync...');
      
      // Only sync aggregated data (no individual readings)
      await _syncAggregates();
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      debugPrint('✅ [SmartSync] Smart sync completed');
    } catch (e) {
      debugPrint('❌ [SmartSync] Smart sync failed: $e');
      rethrow;
    }
  }

  /// Sync only recent readings (last 7 days)
  Future<void> _syncRecentReadings() async {
    try {
      final userId = _auth.currentUser!.uid;
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Get readings from last 7 days
      final allReadings = await _storage.getLast7Days();
      final recentReadings = allReadings
          .where((r) => r.timestamp.isAfter(sevenDaysAgo))
          .toList();
      
      if (recentReadings.isEmpty) {
        debugPrint('   - No recent readings to sync');
        return;
      }
      
      debugPrint('   - Syncing ${recentReadings.length} recent readings');
      
      // Batch upload (max 500 at a time to avoid timeout)
      const batchSize = 500;
      for (var i = 0; i < recentReadings.length; i += batchSize) {
        final end = (i + batchSize < recentReadings.length) 
            ? i + batchSize 
            : recentReadings.length;
        final batch = recentReadings.sublist(i, end);
        
        await _firestore.batchSaveReadings(
          userId: userId,
          readingsList: batch,
        );
      }
      
      debugPrint('   ✅ Recent readings synced');
    } catch (e) {
      debugPrint('   ❌ Failed to sync recent readings: $e');
      rethrow;
    }
  }

  /// Sync aggregated data (hourly and daily summaries)
  /// This is MUCH cheaper than storing individual readings
  /// NO individual readings are synced - all data stays local
  Future<void> _syncAggregates() async {
    try {
      final userId = _auth.currentUser!.uid;
      final prefs = await SharedPreferences.getInstance();
      final lastAggregateSync = prefs.getString(_lastAggregateKey);
      
      DateTime startDate;
      if (lastAggregateSync != null) {
        startDate = DateTime.parse(lastAggregateSync);
      } else {
        // First sync - aggregate all data
        startDate = DateTime.now().subtract(const Duration(days: 365));
      }
      
      debugPrint('   - Aggregating data since $startDate');
      
      // Get all readings since last aggregate sync
      final allReadings = await _storage.getAllReadings();
      final readingsToAggregate = allReadings
          .where((r) => r.timestamp.isAfter(startDate))
          .toList();
      
      if (readingsToAggregate.isEmpty) {
        debugPrint('   - No new data to aggregate');
        return;
      }
      
      // Create hourly aggregates
      final hourlyAggregates = _createHourlyAggregates(readingsToAggregate);
      
      // Create daily aggregates
      final dailyAggregates = _createDailyAggregates(readingsToAggregate);
      
      // Upload aggregates to Firestore
      await _uploadAggregates(userId, hourlyAggregates, dailyAggregates);
      
      // Update last aggregate sync time
      await prefs.setString(_lastAggregateKey, DateTime.now().toIso8601String());
      
      debugPrint('   ✅ Aggregates synced');
    } catch (e) {
      debugPrint('   ❌ Failed to sync aggregates: $e');
      rethrow;
    }
  }

  /// Create hourly aggregates (avg, min, max per hour)
  Map<String, Map<String, dynamic>> _createHourlyAggregates(List<TempReading> readings) {
    final Map<String, List<double>> hourlyData = {};
    
    for (var reading in readings) {
      // Group by hour (YYYY-MM-DD-HH)
      final hourKey = '${reading.timestamp.year}-'
          '${reading.timestamp.month.toString().padLeft(2, '0')}-'
          '${reading.timestamp.day.toString().padLeft(2, '0')}-'
          '${reading.timestamp.hour.toString().padLeft(2, '0')}';
      
      hourlyData.putIfAbsent(hourKey, () => []);
      hourlyData[hourKey]!.add(reading.temperature);
    }
    
    // Calculate aggregates for each hour
    final Map<String, Map<String, dynamic>> aggregates = {};
    hourlyData.forEach((hourKey, temps) {
      final avg = temps.reduce((a, b) => a + b) / temps.length;
      final min = temps.reduce((a, b) => a < b ? a : b);
      final max = temps.reduce((a, b) => a > b ? a : b);
      
      aggregates[hourKey] = {
        'avg': avg,
        'min': min,
        'max': max,
        'count': temps.length,
        'timestamp': _parseHourKey(hourKey),
      };
    });
    
    return aggregates;
  }

  /// Create daily aggregates (avg, min, max per day)
  Map<String, Map<String, dynamic>> _createDailyAggregates(List<TempReading> readings) {
    final Map<String, List<double>> dailyData = {};
    
    for (var reading in readings) {
      // Group by day (YYYY-MM-DD)
      final dayKey = '${reading.timestamp.year}-'
          '${reading.timestamp.month.toString().padLeft(2, '0')}-'
          '${reading.timestamp.day.toString().padLeft(2, '0')}';
      
      dailyData.putIfAbsent(dayKey, () => []);
      dailyData[dayKey]!.add(reading.temperature);
    }
    
    // Calculate aggregates for each day
    final Map<String, Map<String, dynamic>> aggregates = {};
    dailyData.forEach((dayKey, temps) {
      final avg = temps.reduce((a, b) => a + b) / temps.length;
      final min = temps.reduce((a, b) => a < b ? a : b);
      final max = temps.reduce((a, b) => a > b ? a : b);
      
      aggregates[dayKey] = {
        'avg': avg,
        'min': min,
        'max': max,
        'count': temps.length,
        'timestamp': _parseDayKey(dayKey),
      };
    });
    
    return aggregates;
  }

  /// Upload aggregates to Firestore
  Future<void> _uploadAggregates(
    String userId,
    Map<String, Map<String, dynamic>> hourlyAggregates,
    Map<String, Map<String, dynamic>> dailyAggregates,
  ) async {
    try {
      // Upload hourly aggregates
      for (var entry in hourlyAggregates.entries) {
        await _firestore.users
            .doc(userId)
            .collection('hourly_aggregates')
            .doc(entry.key)
            .set(entry.value);
      }
      
      // Upload daily aggregates
      for (var entry in dailyAggregates.entries) {
        await _firestore.users
            .doc(userId)
            .collection('daily_aggregates')
            .doc(entry.key)
            .set(entry.value);
      }
      
      debugPrint('   - Uploaded ${hourlyAggregates.length} hourly + ${dailyAggregates.length} daily aggregates');
    } catch (e) {
      debugPrint('   ❌ Failed to upload aggregates: $e');
      rethrow;
    }
  }

  /// Clean up old individual readings from cloud (keep only 7 days)
  Future<void> _cleanupOldReadings() async {
    try {
      final userId = _auth.currentUser!.uid;
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Query old readings
      final oldReadings = await _firestore.readings
          .where('userId', isEqualTo: userId)
          .where('timestamp', isLessThan: sevenDaysAgo)
          .get();
      
      if (oldReadings.docs.isEmpty) {
        debugPrint('   - No old readings to clean up');
        return;
      }
      
      debugPrint('   - Cleaning up ${oldReadings.docs.length} old readings');
      
      // Delete in batches
      for (var doc in oldReadings.docs) {
        await doc.reference.delete();
      }
      
      debugPrint('   ✅ Old readings cleaned up');
    } catch (e) {
      debugPrint('   ❌ Failed to cleanup old readings: $e');
      // Don't rethrow - cleanup failure shouldn't block sync
    }
  }

  DateTime _parseHourKey(String hourKey) {
    final parts = hourKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(parts[3]),
    );
  }

  DateTime _parseDayKey(String dayKey) {
    final parts = dayKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Get hourly chart data from cloud (for premium users)
  Future<List<Map<String, dynamic>>> getHourlyChartData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_auth.isSignedIn) return [];
    
    try {
      final userId = _auth.currentUser!.uid;
      
      final snapshot = await _firestore.users
          .doc(userId)
          .collection('hourly_aggregates')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp')
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ [SmartSync] Failed to get hourly chart data: $e');
      return [];
    }
  }

  /// Get daily chart data from cloud
  Future<List<Map<String, dynamic>>> getDailyChartData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_auth.isSignedIn) return [];
    
    try {
      final userId = _auth.currentUser!.uid;
      
      final snapshot = await _firestore.users
          .doc(userId)
          .collection('daily_aggregates')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp')
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ [SmartSync] Failed to get daily chart data: $e');
      return [];
    }
  }
}
