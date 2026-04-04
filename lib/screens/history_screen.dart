import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/storage_service.dart';
import '../services/unit_service.dart';
import '../models/temp_reading.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sh = mq.size.height;
    final sw = mq.size.width;
    final hPad = (sw * 0.05).clamp(16.0, 24.0);
    final topPad = mq.padding.top;

    return ListenableBuilder(
      listenable: UnitService.instance,
      builder: (context, _) => _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : RefreshIndicator(
              color: const Color(0xFFFF6B35),
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.fromLTRB(hPad, topPad + 20, hPad, 32),
                children: [
                  // ── Page header ──
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'History',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Detailed view of your temperature data",
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildChartCard(sh),
                  const SizedBox(height: 20),
                  _buildStatsGrid(),
                  const SizedBox(height: 20),
                  _buildAccuracyCard(),
                ],
              ),
            ),
    );
  }

  // ── Chart card ──
  Widget _buildChartCard(double screenHeight) {
    final chartH = (screenHeight * 0.22).clamp(150.0, 200.0);
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Temperature",
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: chartH,
            child: _weekReadings.length >= 2
                ? _buildChart()
                : const Center(
                    child: Text(
                      'Not enough data yet',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last 12 hours',
                style: TextStyle(
                  color: const Color(0xFF111827).withAlpha(130),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                'Updated every 3 seconds',
                style: TextStyle(
                  color: const Color(0xFF111827).withAlpha(130),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final us = UnitService.instance;
    
    // Get readings from last 12 hours only
    final now = DateTime.now();
    final twelveHoursAgo = now.subtract(const Duration(hours: 12));
    final recentReadings = _weekReadings
        .where((r) => r.timestamp.isAfter(twelveHoursAgo))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (recentReadings.length < 2) {
      return const Center(
        child: Text(
          'Not enough data yet',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      );
    }

    // Group readings by hour
    final Map<int, List<double>> byHour = {};
    for (final r in recentReadings) {
      final hourKey = r.timestamp.hour;
      byHour.putIfAbsent(hourKey, () => []);
      byHour[hourKey]!.add(r.temperature);
    }

    // Create spots with hourly averages (converted to user's unit)
    final spots = <FlSpot>[];
    final labels = <String>[];
    final sortedHours = byHour.keys.toList()..sort();
    
    for (int i = 0; i < sortedHours.length; i++) {
      final hour = sortedHours[i];
      final temps = byHour[hour]!;
      final avgCelsius = temps.reduce((a, b) => a + b) / temps.length;
      
      // Convert to user's selected unit
      final avgInUserUnit = us.convertFromCelsius(avgCelsius);
      spots.add(FlSpot(i.toDouble(), avgInUserUnit));
      
      // Format hour label (e.g., "10 AM", "2 PM")
      final hourLabel = hour == 0 ? '12 AM' 
          : hour < 12 ? '$hour AM'
          : hour == 12 ? '12 PM'
          : '${hour - 12} PM';
      labels.add(hourLabel);
    }

    // Calculate Y-axis range in user's unit
    final yValues = spots.map((s) => s.y).toList();
    final dataMin = yValues.reduce((a, b) => a < b ? a : b);
    final dataMax = yValues.reduce((a, b) => a > b ? a : b);
    
    // Adjust interval based on unit (Kelvin has larger numbers)
    final interval = us.unit == TempUnit.kelvin ? 1.0 : 0.5;
    final minY = ((dataMin - interval) / interval).floorToDouble() * interval;
    final maxY = ((dataMax + interval) / interval).ceilToDouble() * interval;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: const Color(0xFF111827).withAlpha(20),
            strokeWidth: 0.8,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                // Format based on unit (Kelvin shows no decimals, others show 1 decimal)
                final formatted = us.unit == TempUnit.kelvin 
                    ? value.toStringAsFixed(0)
                    : value.toStringAsFixed(1);
                return Text(
                  formatted,
                  style: TextStyle(
                    color: const Color(0xFF111827).withAlpha(120),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                // Show every other label to avoid crowding
                if (labels.length > 6 && i % 2 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: const Color(0xFF111827).withAlpha(100),
                      fontSize: 9,
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
            getTooltipColor: (_) => const Color(0xFF111827),
            tooltipRoundedRadius: 8,
            getTooltipItems: (items) => items.map((spot) {
              return LineTooltipItem(
                us.format(spot.y),
                const TextStyle(
                  color: Colors.white,
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
            color: const Color(0xFF111827),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: const Color(0xFF111827),
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFF6B35).withAlpha(45),
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

  // ── Stats grid: 2×2 ──
  Widget _buildStatsGrid() {
    final us = UnitService.instance;
    final temps = _weekReadings.map((r) => r.temperature).toList();
    final highest = temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : 0.0;
    final lowest = temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : 0.0;
    final current = temps.isNotEmpty ? temps.first : 0.0;
    final average = temps.isNotEmpty ? temps.reduce((a, b) => a + b) / temps.length : 0.0;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 18, color: Color(0xFF111827)),
              const SizedBox(width: 8),
              const Text(
                "Today's Statistics",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _statCard('Highest', highest > 0 ? us.format(highest) : '--')),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Lowest', lowest > 0 ? us.format(lowest) : '--')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('Current', current > 0 ? us.format(current) : '--')),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Average', average > 0 ? us.format(average) : '--')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(70),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF111827).withAlpha(150),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyCard() {
    return _glassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.trending_up_rounded,
            size: 18,
            color: Color(0xFF111827),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accuracy Information',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Temperature readings are estimated from device sensors when the phone is near your body. Typical variance is ±0.5°C. This is not medical-grade equipment.',
                  style: TextStyle(
                    color: const Color(0xFF111827).withAlpha(160),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(100), width: 1),
      ),
      child: child,
    );
  }

}