import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../services/unit_service.dart';
import '../models/temp_reading.dart';
import '../widgets/temp_display.dart';
import '../widgets/temp_chart.dart';

/// ──────────────────────────────────────────────
/// Figma Design System Typography
/// ──────────────────────────────────────────────
/// HEADING XL  → 32px • w600
/// HEADING L   → 24px • w600
/// BODY        → 14px • w500
/// CAPTION     → 12px • w500
/// LABEL       → 10px • w600
/// ──────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _sensor = SensorService();
  final _storage = StorageService();

  double _currentTemp = 0;
  double _avgTemp    = 0;
  double _minTemp    = 0;
  double _maxTemp    = 0;
  List<TempReading> _readings = [];
  bool _loading     = true;
  bool _isCharging  = false;
  bool _isStable    = true;
  DateTime? _lastUpdated;
  Timer? _liveTimer;

  /// Rolling buffer of last 5 readings for smoothed display
  final List<double> _tempBuffer = [];
  double get _displayTemp =>
      _tempBuffer.isEmpty ? _currentTemp : _tempBuffer.reduce((a, b) => a + b) / _tempBuffer.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    // Poll every 8s — gives time for 5-sample averaging (5 × 800ms = 4s)
    _liveTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _pollTemp(),
    );
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _liveTimer?.cancel();
      _liveTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _loadData(); // full stats reload
      _liveTimer ??= Timer.periodic(
        const Duration(seconds: 8),
        (_) => _pollTemp(),
      );
    }
  }

  /// Lightweight: only reads current sensor temp and updates the display.
  /// Runs every 5 seconds for live updating.
  Future<void> _pollTemp() async {
    final result = await _sensor.getCurrentTemp();
    if (!result.success || !mounted) return;

    // Update rolling buffer — exclude charging readings for accuracy
    if (!result.isCharging) {
      _tempBuffer.add(result.calibrated);
      if (_tempBuffer.length > 5) _tempBuffer.removeAt(0);
    }

    final smoothed = _displayTemp;
    final reading = TempReading(
      temperature: smoothed,
      rawTemp: result.raw,
      timestamp: DateTime.now(),
      source: result.source,
    );
    await _storage.saveReading(reading);
    if (!mounted) return;

    final readings = await _storage.getLast7Days();
    final avg     = await _storage.getSevenDayAverage();
    final min     = await _storage.getMin7Days();
    final max     = await _storage.getMax7Days();
    if (!mounted) return;

    setState(() {
      _isCharging  = result.isCharging;
      _isStable    = result.isStable;
      _currentTemp = smoothed;
      _lastUpdated = DateTime.now();
      _readings    = readings;
      _avgTemp     = avg;
      _minTemp     = min;
      _maxTemp     = max;
    });
  }

  Future<void> _loadData() async {
    final result = await _sensor.getCurrentTemp();
    if (result.success) {
      if (!result.isCharging) {
        _tempBuffer.add(result.calibrated);
        if (_tempBuffer.length > 5) _tempBuffer.removeAt(0);
      }
      final smoothed = _displayTemp;
      final reading = TempReading(
        temperature: smoothed,
        rawTemp: result.raw,
        timestamp: DateTime.now(),
        source: result.source,
      );
      await _storage.saveReading(reading);
    }

    final readings = await _storage.getLast7Days();
    final avg      = await _storage.getSevenDayAverage();
    final min      = await _storage.getMin7Days();
    final max      = await _storage.getMax7Days();
    final latest   = await _storage.getLatest();

    if (mounted) {
      setState(() {
        _isCharging  = result.isCharging;
        _isStable    = result.isStable;
        _readings    = readings;
        _avgTemp     = avg;
        _minTemp     = min;
        _maxTemp     = max;
        _currentTemp = _displayTemp > 0 ? _displayTemp
                       : latest?.temperature ?? result.calibrated;
        _lastUpdated = latest?.timestamp ?? DateTime.now();
        _loading     = false;
      });
    }
  }

  // ── Temperature state — absolute thresholds ──
  // < 35°C  → Low      → Blue  #4FC3F7
  // 35–39°C → Normal   → White
  // ≥ 40°C  → Elevated → Orange #FF6B35
  _TempState get _tempState {
    if (_currentTemp == 0) return _TempState.normal;
    if (_currentTemp < 35.0) return _TempState.low;
    if (_currentTemp >= 40.0) return _TempState.elevated;
    return _TempState.normal; // 35.0 – 39.9
  }

  Color get _stateColor {
    switch (_tempState) {
      case _TempState.elevated:
        return const Color(0xFFFF6B35); // orange-red
      case _TempState.low:
        return const Color(0xFF4FC3F7); // light blue
      case _TempState.normal:
        return Colors.white;
    }
  }

  String get _stateLabel {
    switch (_tempState) {
      case _TempState.elevated:
        return 'Elevated';
      case _TempState.low:
        return 'Low';
      case _TempState.normal:
        return 'Normal';
    }
  }

  String get _stateDescription {
    switch (_tempState) {
      case _TempState.elevated:
        return 'Temperature is above normal range';
      case _TempState.low:
        return 'Temperature is below normal range';
      case _TempState.normal:
        return 'Your temperature is within normal\nrange';
    }
  }

  String get _lastUpdatedText {
    if (_lastUpdated == null) return '';
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    // Responsive horizontal padding: 6% of width, clamped
    final hPad = (sw * 0.06).clamp(18.0, 28.0);
    // Responsive gap before temperature: 7% of height
    final tempGap = (sh * 0.07).clamp(40.0, 72.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: ListenableBuilder(
        listenable: UnitService.instance,
        builder: (context, _) => _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
              )
            : RefreshIndicator(
                color: const Color(0xFFFF6B35),
                backgroundColor: const Color(0xFF1A1A24),
                onRefresh: _loadData,
                child: Stack(

                children: [
                  // ── Bottom glow — animated color transition ──
                  Positioned(
                    bottom: -60,
                    left: 0,
                    right: 0,
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        begin: _stateColor,
                        end: _stateColor,
                      ),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, color, _) {
                        final c = color ?? _stateColor;
                        return Container(
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.bottomCenter,
                              radius: 1.4,
                              colors: [
                                c.withAlpha(80),
                                c.withAlpha(28),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Main content
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: mq.padding.top + 24,
                      left: hPad,
                      right: hPad,
                      bottom: 24,
                    ),
                    children: [
                      _buildHeader(),
                      SizedBox(height: tempGap),
                      TempDisplay(
                        temperature: _currentTemp,
                        color: _stateColor,
                      ),
                      // ── Charging warning banner ──
                      if (_isCharging) _buildChargingBanner(),
                      if (_isCharging) const SizedBox(height: 12),
                      _buildStatusLabel(),
                      const SizedBox(height: 4),
                      _buildDescription(),
                      if (_avgTemp > 0) _buildBaselineDeviation(),
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      _buildChartSection(sh),
                    ],
                  ),
                ],
              ),
            ),
        ),  // ListenableBuilder
    );
  }


  /// ── Header: "● Live Monitoring" + "Mar 7" ──
  Widget _buildHeader() {
    final date = DateFormat('MMM d').format(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _tempState == _TempState.elevated
                    ? const Color(0xFFFF6B35)
                    : _tempState == _TempState.low
                        ? const Color(0xFF4FC3F7)
                        : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            // BODY: 14px • w500
            Text(
              'Live Monitoring',
              style: GoogleFonts.inter(
                color: const Color(0xFFB0B8C4),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        // CAPTION: 12px • w500 — gray
        Text(
          date,
          style: GoogleFonts.inter(
            color: const Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// ── Status: "Normal" / "Elevated" / "Low" ──
  Widget _buildStatusLabel() {
    final sw = MediaQuery.of(context).size.width;
    final fontSize = (sw * 0.05).clamp(16.0, 22.0);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _stateLabel,
            style: TextStyle(
              color: const Color(0xFF9CA3AF),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          // Green = stable, Yellow = settling
          if (_tempBuffer.length >= 3) ...[const SizedBox(width: 8),
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isStable ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ── Description text ──
  Widget _buildDescription() {
    return Text(
      _stateDescription,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        color: const Color(0xFF6B7280),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
    );
  }

  Widget _buildChargingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24).withAlpha(70)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 15),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Charging detected — readings may be elevated',
              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaselineDeviation() {
    final us = UnitService.instance;
    final devC = _currentTemp - _avgTemp;
    if (devC.abs() < 0.05) return const SizedBox.shrink();
    // Convert deviation: (C dev) × 9/5 gives F deviation
    final dev = us.isCelsius ? devC : devC * 9 / 5;
    final sign = dev > 0 ? '+' : '';
    final Color devColor = devC > 0.5
        ? const Color(0xFFFF6B35)
        : devC < -0.5 ? const Color(0xFF4FC3F7) : const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: devColor.withAlpha(22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: devColor.withAlpha(60)),
          ),
          child: Text(
            '$sign${dev.toStringAsFixed(1)}${us.symbol} from your baseline',
            style: TextStyle(color: devColor, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  /// ── MIN / MAX / AVG stat cards ──
  Widget _buildStatsRow() {
    final us = UnitService.instance;
    final avgDev = _avgTemp > 0 ? _currentTemp - _avgTemp : 0.0;
    final minDev = _minTemp > 0 ? _minTemp - _avgTemp : 0.0;
    final maxDev = _maxTemp > 0 ? _maxTemp - _avgTemp : 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'MIN',
            value: _minTemp > 0 ? us.format(_minTemp) : '--',
            deviation: us.isCelsius ? minDev : minDev * 9 / 5,
            symbol: us.symbol,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'MAX',
            value: _maxTemp > 0 ? us.format(_maxTemp) : '--',
            deviation: us.isCelsius ? maxDev : maxDev * 9 / 5,
            symbol: us.symbol,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'AVG',
            value: _avgTemp > 0 ? us.format(_avgTemp) : '--',
            deviation: us.isCelsius ? avgDev : avgDev * 9 / 5,
            symbol: us.symbol,
          ),
        ),
      ],
    );
  }

  /// ── 7-Day Trend chart card ──
  Widget _buildChartSection(double screenHeight) {
    final chartH = (screenHeight * 0.22).clamp(150.0, 220.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A1A26), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LABEL: 10px • w600
              Text(
                '7-DAY TREND',
                style: GoogleFonts.inter(
                  color: const Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              // CAPTION: 12px • w500
              Text(
                'Last updated: $_lastUpdatedText',
                style: GoogleFonts.inter(
                  color: const Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: chartH,
            child: _readings.length >= 2
                ? TempChart(
                    readings: _readings,
                    lineColor: _stateColor,
                  )
                : Center(
                    child: Text(
                      'Collecting data…',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Temperature state enum ──
enum _TempState { normal, elevated, low }

// ── Stat card widget ──
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final double deviation;
  final String symbol;

  const _StatCard({
    required this.label,
    required this.value,
    required this.deviation,
    this.symbol = '°C',
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final vertPad = (sh * 0.032).clamp(16.0, 26.0);
    final valueFontSize = (sw * 0.065).clamp(22.0, 30.0);

    Color devColor;
    if (deviation > 0.1) {
      devColor = const Color(0xFFFF6B35);
    } else if (deviation < -0.1) {
      devColor = const Color(0xFF4FC3F7);
    } else {
      devColor = const Color(0xFF6B7280);
    }

    final devText = deviation >= 0
        ? '+${deviation.toStringAsFixed(1)}$symbol'
        : '${deviation.toStringAsFixed(1)}$symbol';


    return Container(
      padding: EdgeInsets.symmetric(vertical: vertPad, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A1A26), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            devText,
            style: TextStyle(
              color: devColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
