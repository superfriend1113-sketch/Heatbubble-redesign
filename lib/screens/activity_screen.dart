import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/storage_service.dart';
import '../services/unit_service.dart';
import '../models/temp_reading.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _storage = StorageService();
  List<TempReading> _weekReadings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final readings = await _storage.getLast7Days();
    if (mounted) {
      setState(() {
        _weekReadings = readings;
        _loading = false;
      });
    }
  }

  bool get _hasMultiDayData {
    if (_weekReadings.isEmpty) return false;
    final firstDay = DateFormat('yyyy-MM-dd').format(_weekReadings.first.timestamp);
    final lastDay = DateFormat('yyyy-MM-dd').format(_weekReadings.last.timestamp);
    return firstDay != lastDay;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sh = mq.size.height;
    final sw = mq.size.width;
    final hPad = (sw * 0.06).clamp(18.0, 28.0);
    final topPad = mq.padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: ListenableBuilder(
        listenable: UnitService.instance,
        builder: (context, _) => _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(hPad, topPad + 24, hPad, 32),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildChartCard(sh),
                  const SizedBox(height: 28),
                  _buildRecentReadings(),
                ],
              ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your temperature history',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── 7-Day chart card ─────────────────────────────
  Widget _buildChartCard(double screenHeight) {
    final chartH = (screenHeight * 0.18).clamp(120.0, 180.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(13), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text(
                _hasMultiDayData ? '7-DAY OVERVIEW' : '7-DAY OVERVIEW',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Temperature',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: chartH,
            child: _weekReadings.length >= 2
                ? _buildWeekChart()
                : const Center(
                    child: Text(
                      'Not enough data yet',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
    // ── Group by calendar date → average per day ──
    final Map<String, List<double>> byDate = {};
    for (final r in _weekReadings) {
      final key = DateFormat('yyyy-MM-dd').format(r.timestamp);
      byDate.putIfAbsent(key, () => []);
      byDate[key]!.add(r.temperature);
    }

    // Sort ascending, keep last 7 days
    final sortedKeys = byDate.keys.toList()..sort();
    final recentKeys = sortedKeys.length > 7
        ? sortedKeys.sublist(sortedKeys.length - 7)
        : sortedKeys;

    if (recentKeys.isEmpty) {
      return const Center(
        child: Text(
          'No data yet — keep monitoring!',
          style: TextStyle(color: Color(0xFF4A4A5A), fontSize: 13),
        ),
      );
    }

    final spots = <FlSpot>[];
    final usedLabels = <String>[];

    for (int i = 0; i < recentKeys.length; i++) {
      final temps = byDate[recentKeys[i]]!;
      final avg = temps.reduce((a, b) => a + b) / temps.length;
      spots.add(FlSpot(i.toDouble(), avg));
      usedLabels.add(DateFormat('EEE').format(DateTime.parse(recentKeys[i])));
    }

    // ── Y range snapped to nearest 0.75 ──
    final yValues = spots.map((s) => s.y).toList();
    final dataMin = yValues.reduce((a, b) => a < b ? a : b);
    final dataMax = yValues.reduce((a, b) => a > b ? a : b);
    const interval = 0.75;
    final minY = ((dataMin - 0.75) / interval).floorToDouble() * interval;
    final maxY = ((dataMax + 0.75) / interval).ceilToDouble() * interval;

    return LineChart(
      LineChartData(
        // ── Subtle horizontal grid lines ──
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFF1E1E2E),
            strokeWidth: 0.8,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // ── Y-axis: 0.75 interval, 2-decimal labels (35, 35.75, 36.5 …) ──
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 0.75,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                // Show only values snapped to multiples of 0.75
                final snapped = (value / 0.75).round() * 0.75;
                if ((snapped - value).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Color(0xFF4A4A5A),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          // ── X-axis: day names ──
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= usedLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    usedLabels[i],
                    style: const TextStyle(
                      color: Color(0xFF4A4A5A),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A1A26),
            tooltipRoundedRadius: 8,
            getTooltipItems: (items) => items.map((spot) {
              final us = UnitService.instance;
              return LineTooltipItem(
                us.format(spot.y),
                const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            gradient: const LinearGradient(
              colors: [Color(0xFF4FC3F7), Color(0xFFFF6B35), Color(0xFF4FC3F7)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: const Color(0xFFFF6B35),
                strokeWidth: 2,
                strokeColor: const Color(0xFF0A0A0F),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFF6B35).withAlpha(40),
                  const Color(0xFFFF6B35).withAlpha(0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ── Recent readings ───────────────────────────────
  // ── Build per-day summary ─────────────────────────
  Widget _buildRecentReadings() {
    // Group all readings by calendar date key
    final Map<String, List<TempReading>> byDate = {};
    for (final r in _weekReadings) {
      final key = DateFormat('yyyy-MM-dd').format(r.timestamp);
      byDate.putIfAbsent(key, () => []);
      byDate[key]!.add(r);
    }

    // Sort descending (most recent day first)
    final sortedKeys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedKeys.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No readings yet',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        ),
      );
    }

    // Build daily summary list
    final dailySummaries = sortedKeys.map((key) {
      final readings = byDate[key]!;
      final temps = readings.map((r) => r.temperature).toList();
      final avg = temps.reduce((a, b) => a + b) / temps.length;
      final min = temps.reduce((a, b) => a < b ? a : b);
      final max = temps.reduce((a, b) => a > b ? a : b);
      return _DaySummary(
        dateKey: key,
        avg: avg,
        min: min,
        max: max,
        count: readings.length,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DAILY SUMMARY',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        ...dailySummaries.asMap().entries.map(
              (e) => _buildDayCard(e.value, e.key, dailySummaries),
            ),
      ],
    );
  }

  Widget _buildDayCard(
    _DaySummary day,
    int index,
    List<_DaySummary> allDays,
  ) {
    // ── Determine day status from daily average ──
    final Color tc;
    final String statusLabel;
    if (day.avg < 35.0) {
      tc = const Color(0xFF4FC3F7);
      statusLabel = 'Low';
    } else if (day.avg >= 40.0) {
      tc = const Color(0xFFFF6B35);
      statusLabel = 'Elevated';
    } else {
      tc = Colors.white;
      statusLabel = 'Normal';
    }

    // ── Trend: compare to next day in list (previous chronologically) ──
    final Color badgeColor;
    final IconData trendIcon;
    if (index + 1 < allDays.length) {
      final prevAvg = allDays[index + 1].avg;
      if (day.avg > prevAvg + 0.1) {
        trendIcon = LucideIcons.trendingUp;
        badgeColor = const Color(0xFFFF6B35);
      } else if (day.avg < prevAvg - 0.1) {
        trendIcon = LucideIcons.trendingDown;
        badgeColor = const Color(0xFF4FC3F7);
      } else {
        trendIcon = LucideIcons.minus;
        badgeColor = const Color(0xFF9CA3AF);
      }
    } else {
      trendIcon = LucideIcons.minus;
      badgeColor = const Color(0xFF9CA3AF);
    }

    // ── Date label ──
    final date = DateTime.parse(day.dateKey);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final String dateLabel;
    if (DateFormat('yMd').format(date) == DateFormat('yMd').format(today)) {
      dateLabel = 'Today';
    } else if (DateFormat('yMd').format(date) ==
        DateFormat('yMd').format(yesterday)) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('MMM d').format(date);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A1A26), width: 1),
      ),
      child: Row(
        children: [
          // ── Daily avg bubble ──
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tc.withAlpha(18),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: tc.withAlpha(30),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  UnitService.instance.formatValue(day.avg),
                  style: TextStyle(
                    color: tc,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  UnitService.instance.symbol,
                  style: TextStyle(
                    color: tc.withAlpha(160),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Day info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + status pill
                Row(
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tc.withAlpha(22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: tc,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Min / Max / readings count
                Row(
                  children: [
                    const Icon(LucideIcons.arrowDown,
                        size: 11, color: Color(0xFF4FC3F7)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${UnitService.instance.formatValue(day.min)}${UnitService.instance.symbol}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowUp,
                        size: 11, color: Color(0xFFFF6B35)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${UnitService.instance.formatValue(day.max)}${UnitService.instance.symbol}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.activity,
                        size: 11, color: Color(0xFF6B7280)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${day.count}x',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Trend badge ──
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(trendIcon, color: badgeColor, size: 22),
          ),
        ],
      ),
    );
  }
}

// ── Daily summary model ──
class _DaySummary {
  final String dateKey;
  final double avg;
  final double min;
  final double max;
  final int count;

  const _DaySummary({
    required this.dateKey,
    required this.avg,
    required this.min,
    required this.max,
    required this.count,
  });
}

