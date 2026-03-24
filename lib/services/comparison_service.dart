import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// Handles comparison of current temperature data against historical readings
/// and manages random notification scheduling.
class ComparisonService {
  static const _nextNotifyKey = 'next_comparison_notify_time';

  // Random intervals in minutes that notifications can be scheduled at
  static const List<int> _intervalMinutesOptions = [5, 10, 15, 30];

  final StorageService _storage;
  final Random _random = Random();

  ComparisonService({StorageService? storage})
      : _storage = storage ?? StorageService();

  // ── Random scheduling ────────────────────────────────

  /// Returns true if a comparison notification is due right now.
  Future<bool> isNotificationDue() async {
    final prefs = await SharedPreferences.getInstance();
    final nextMs = prefs.getInt(_nextNotifyKey);

    if (nextMs == null) {
      // First run — schedule the first notification soon (15–30 min)
      final firstDelay = 15 + _random.nextInt(16); // 15–30 minutes
      final nextTime = DateTime.now()
          .add(Duration(minutes: firstDelay))
          .millisecondsSinceEpoch;
      await prefs.setInt(_nextNotifyKey, nextTime);
      return false;
    }

    return DateTime.now().millisecondsSinceEpoch >= nextMs;
  }

  /// Schedule the next comparison notification at a random future time.
  Future<void> scheduleNext() async {
    final prefs = await SharedPreferences.getInstance();
    await _scheduleNext(prefs);
  }

  Future<void> _scheduleNext(SharedPreferences prefs) async {
    final minutesAhead =
        _intervalMinutesOptions[_random.nextInt(_intervalMinutesOptions.length)];
    final nextTime =
        DateTime.now().add(Duration(minutes: minutesAhead)).millisecondsSinceEpoch;
    await prefs.setInt(_nextNotifyKey, nextTime);
  }

  // ── Comparison logic ─────────────────────────────────

  /// Build a comparison result by checking current temp against various
  /// historical data points. Returns the most interesting comparison found.
  Future<ComparisonResult?> compare(double currentTemp) async {
    // Try comparisons in priority order — return the first interesting one
    final comparisons = <Future<ComparisonResult?> Function()>[
      () => _compareToHoursAgo(currentTemp),
      () => _compareToYesterdaySameTime(currentTemp),
      () => _compareToDailyAverage(currentTemp),
      () => _compareToWeekAverage(currentTemp),
    ];

    // Shuffle so notification text variety is higher
    comparisons.shuffle(_random);

    for (final compare in comparisons) {
      final result = await compare();
      if (result != null) return result;
    }
    return null;
  }

  /// Compare to a reading from a random number of hours ago (1-12h).
  Future<ComparisonResult?> _compareToHoursAgo(double currentTemp) async {
    final hoursAgo = [1, 2, 3, 5, 6, 8, 12][_random.nextInt(7)];
    final pastReading =
        await _storage.getReadingNearTime(hoursAgo.toDouble());
    if (pastReading == null) return null;

    final diff = currentTemp - pastReading.temperature;
    if (diff.abs() < 0.3) {
      return ComparisonResult(
        type: ComparisonType.hoursAgo,
        diff: diff,
        hoursAgo: hoursAgo,
        message: _stableHoursAgoMessage(hoursAgo),
      );
    }

    return ComparisonResult(
      type: ComparisonType.hoursAgo,
      diff: diff,
      hoursAgo: hoursAgo,
      message: _hoursAgoMessage(diff, hoursAgo),
    );
  }

  /// Compare to yesterday at the same time of day.
  Future<ComparisonResult?> _compareToYesterdaySameTime(
      double currentTemp) async {
    final pastReading = await _storage.getReadingNearTime(24);
    if (pastReading == null) return null;

    final diff = currentTemp - pastReading.temperature;
    return ComparisonResult(
      type: ComparisonType.yesterdaySameTime,
      diff: diff,
      message: _yesterdayMessage(diff),
    );
  }

  /// Compare to today's running average so far.
  Future<ComparisonResult?> _compareToDailyAverage(
      double currentTemp) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final readings = await _storage.getReadingsInWindow(startOfDay, now);
    if (readings.length < 3) return null;

    final avg =
        readings.fold(0.0, (sum, r) => sum + r.temperature) / readings.length;
    final diff = currentTemp - avg;
    if (diff.abs() < 0.2) return null;

    return ComparisonResult(
      type: ComparisonType.dailyAverage,
      diff: diff,
      message: _dailyAvgMessage(diff),
    );
  }

  /// Compare to 7-day rolling average.
  Future<ComparisonResult?> _compareToWeekAverage(
      double currentTemp) async {
    final avg = await _storage.getSevenDayAverage();
    if (avg == 0.0) return null;

    final diff = currentTemp - avg;
    return ComparisonResult(
      type: ComparisonType.weekAverage,
      diff: diff,
      message: _weekAvgMessage(diff),
    );
  }

  // ── Message builders ─────────────────────────────────

  String _hoursAgoMessage(double diff, int hours) {
    final abs = diff.abs().toStringAsFixed(1);
    final timeLabel = hours == 1 ? '1 hour' : '$hours hours';

    if (diff > 0) {
      if (diff >= 3)
        return '🔥 Your temperature jumped $abs°C in the last $timeLabel — stay hydrated!';
      if (diff >= 1.5)
        return '🌡️ Up $abs°C from $timeLabel ago — your body is warming up.';
      return '📈 Slightly warmer ($abs°C) compared to $timeLabel ago.';
    } else {
      if (diff <= -3)
        return '🧊 Your temperature dropped $abs°C in $timeLabel — are you somewhere cold?';
      if (diff <= -1.5)
        return '❄️ Down $abs°C from $timeLabel ago — cooling down noticeably.';
      return '📉 Slightly cooler ($abs°C) compared to $timeLabel ago.';
    }
  }

  String _stableHoursAgoMessage(int hours) {
    final timeLabel = hours == 1 ? '1 hour' : '$hours hours';
    final messages = [
      '✅ Rock steady — same temperature as $timeLabel ago.',
      '😊 No change from $timeLabel ago — your body temperature is consistent.',
      '👍 Holding steady compared to $timeLabel ago!',
    ];
    return messages[_random.nextInt(messages.length)];
  }

  String _yesterdayMessage(double diff) {
    final abs = diff.abs().toStringAsFixed(1);
    if (diff.abs() < 0.3) {
      return '📊 Almost identical to this time yesterday — your pattern is consistent!';
    }
    if (diff > 0) {
      if (diff >= 2)
        return '🔥 You\'re $abs°C warmer than this time yesterday — notable increase.';
      return '🌡️ A bit warmer ($abs°C) than this time yesterday.';
    } else {
      if (diff <= -2)
        return '🧊 You\'re $abs°C cooler than yesterday at this hour.';
      return '❄️ Slightly cooler ($abs°C) than this time yesterday.';
    }
  }

  String _dailyAvgMessage(double diff) {
    final abs = diff.abs().toStringAsFixed(1);
    if (diff > 0) {
      if (diff >= 2)
        return '📈 Currently $abs°C above today\'s average — running warm!';
      return '🌡️ You\'re $abs°C above your average today.';
    } else {
      if (diff <= -2)
        return '📉 Currently $abs°C below today\'s average — running cool.';
      return '❄️ You\'re $abs°C below your average today.';
    }
  }

  String _weekAvgMessage(double diff) {
    final abs = diff.abs().toStringAsFixed(1);
    if (diff.abs() < 0.3) {
      return '📊 Right on track — matching your weekly average perfectly.';
    }
    if (diff > 0) {
      if (diff >= 3)
        return '🔥 $abs°C above your weekly average — significantly warmer than usual!';
      return '🌡️ Running $abs°C warmer than your week average.';
    } else {
      if (diff <= -3)
        return '🧊 $abs°C below your weekly average — much cooler than usual.';
      return '❄️ Running $abs°C cooler than your week average.';
    }
  }
}

// ── Data models ──────────────────────────────────────

enum ComparisonType { hoursAgo, yesterdaySameTime, dailyAverage, weekAverage }

class ComparisonResult {
  final ComparisonType type;
  final double diff;
  final int? hoursAgo;
  final String message;

  const ComparisonResult({
    required this.type,
    required this.diff,
    required this.message,
    this.hoursAgo,
  });
}
