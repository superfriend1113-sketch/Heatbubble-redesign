import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/temp_reading.dart';
import '../services/storage_service.dart';
import '../services/unit_service.dart';

class HourlyTemperatureChart extends StatefulWidget {
  final int hoursBack; // How many hours to display (default 24)
  final double? minY;
  final double? maxY;
  
  const HourlyTemperatureChart({
    super.key,
    this.hoursBack = 24,
    this.minY,
    this.maxY,
  });

  @override
  State<HourlyTemperatureChart> createState() => _HourlyTemperatureChartState();
}

class _HourlyTemperatureChartState extends State<HourlyTemperatureChart> {
  final _storage = StorageService();
  late UnitService _unitService;
  
  List<TempReading> _readings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _unitService = UnitService.instance;
    _loadData();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(hours: widget.hoursBack));
    final readings = await _storage.getReadingsInWindow(cutoff, now);
    
    setState(() {
      _readings = readings;
      _loading = false;
    });
  }

  /// Group readings by hour and calculate averages
  Map<int, List<TempReading>> _groupByHour() {
    final grouped = <int, List<TempReading>>{};
    
    for (final reading in _readings) {
      final hour = reading.timestamp.hour;
      grouped.putIfAbsent(hour, () => []).add(reading);
    }
    
    return grouped;
  }

  /// Get hourly average temperature
  List<FlSpot> _getChartSpots() {
    final grouped = _groupByHour();
    final spots = <FlSpot>[];
    
    for (int i = 0; i < 24; i++) {
      final readings = grouped[i] ?? [];
      if (readings.isNotEmpty) {
        final avg = readings.map((r) => r.temperature).reduce((a, b) => a + b) / readings.length;
        spots.add(FlSpot(i.toDouble(), avg));
      }
    }
    
    return spots;
  }

  /// Convert temperature to display unit
  double _convertTemp(double celsius) {
    final unit = _unitService.unit;
    if (unit == 'F') {
      return celsius * 9 / 5 + 32;
    } else if (unit == 'K') {
      return celsius + 273.15;
    }
    return celsius;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_readings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No temperature data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    final spots = _getChartSpots();
    
    if (spots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Insufficient data for chart',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Calculate min/max
    final temps = spots.map((s) => s.y).toList();
    final minTemp = _convertTemp(temps.reduce((a, b) => a < b ? a : b));
    final maxTemp = _convertTemp(temps.reduce((a, b) => a > b ? a : b));
    final avgTemp = _convertTemp(temps.reduce((a, b) => a + b) / temps.length);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.1),
            const Color(0xFF4FC3F7).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            '📊 Hourly Temperature',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statBox('Min', '${minTemp.toStringAsFixed(1)}°'),
              _statBox('Avg', '${avgTemp.toStringAsFixed(1)}°'),
              _statBox('Max', '${maxTemp.toStringAsFixed(1)}°'),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        return Text(
                          '${hour}h',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                      interval: 3,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}°',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFFFF6B35),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFFFF6B35),
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFF6B35).withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B35),
          ),
        ),
      ],
    );
  }
}
