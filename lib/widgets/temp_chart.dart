import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/temp_reading.dart';

class TempChart extends StatelessWidget {
  final List<TempReading> readings;
  final Color lineColor;

  const TempChart({
    super.key,
    required this.readings,
    this.lineColor = const Color(0xFFFF6B35),
  });

  @override
  Widget build(BuildContext context) {
    if (readings.length < 2) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < readings.length; i++) {
      spots.add(FlSpot(i.toDouble(), readings[i].temperature));
    }

    final temps = readings.map((r) => r.temperature).toList();
    final minY = (temps.reduce((a, b) => a < b ? a : b) - 0.5).floorToDouble();
    final maxY = (temps.reduce((a, b) => a > b ? a : b) + 0.5).ceilToDouble();

    return LineChart(
      LineChartData(
        // ── No grid at all ──
        gridData: const FlGridData(show: false),
        // ── No axis labels at all ──
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        // ── No border ──
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        // ── Touch tooltip only ──
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => const Color(0xFF1A1A26),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)}°C',
                TextStyle(
                  color: lineColor,
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
            curveSmoothness: 0.4,
            color: lineColor.withAlpha(220),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withAlpha(60),
                  lineColor.withAlpha(0),
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
}
