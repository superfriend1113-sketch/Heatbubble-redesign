import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/storage_service.dart';
import '../services/alert_store.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _storage = StorageService();
  bool _loading = true;
  String _trendLabel = 'Stable Trend';
  String _trendDescription = '';
  List<AlertRecord> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final readings = await _storage.getLast7Days();

    // ── Current Analysis: computed from sensor readings ──
    String trend = 'Stable Trend';
    String desc = 'Your temperature is stable and within normal range. Great job maintaining consistency!';

    if (readings.length >= 2) {
      final recent = readings.take(5).map((r) => r.temperature).toList();
      final older  = readings.skip(5).take(5).map((r) => r.temperature).toList();
      if (recent.isNotEmpty && older.isNotEmpty) {
        final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
        final olderAvg  = older.reduce((a, b) => a + b) / older.length;
        final diff = recentAvg - olderAvg;
        if (diff > 0.3) {
          trend = 'Rising Trend';
          desc = 'Your body temperature is increasing. This could indicate activity, warm environment, or the beginning of a fever. Stay hydrated.';
        } else if (diff < -0.3) {
          trend = 'Falling Trend';
          desc = 'Your body temperature is decreasing. This is normal after exercise or when moving to a cooler environment.';
        }
      }
    }

    // ── Recent Insights: real fired notifications ──
    final alerts = await AlertStore.load();

    if (mounted) {
      setState(() {
        _trendLabel = trend;
        _trendDescription = desc;
        _alerts = alerts;
        _loading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final hPad = (sw * 0.05).clamp(16.0, 24.0);
    final topPad = mq.padding.top;

    return _loading
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
                      'AI Insights',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your personalized health analysis',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Current Analysis card ──
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card header
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withAlpha(15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.brain,
                              size: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Current Analysis',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Inner analysis sub-card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(200),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Coloured circle icon
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _trendColor().withAlpha(30),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _trendIcon(),
                                    size: 16,
                                    color: _trendColor(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _trendLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _trendDescription,
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Recent Insights — real fired notifications ──
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Insights',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_alerts.isEmpty)
                        _emptyAlerts()
                      else
                        ..._alerts.take(6).map((a) => _buildAlertCard(a)),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  // Trend helpers
  Color _trendColor() {
    if (_trendLabel.contains('Rising')) return const Color(0xFFFF4E50);
    if (_trendLabel.contains('Falling')) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
  }

  IconData _trendIcon() {
    if (_trendLabel.contains('Rising')) return Icons.warning_amber_rounded;
    if (_trendLabel.contains('Falling')) return LucideIcons.trendingDown;
    return Icons.check_circle;
  }

  // ── Alert type → icon / colour ─────────────────────
  Color _alertColor(AlertType type) {
    switch (type) {
      case AlertType.extremeCold: return const Color(0xFF3B82F6);  // blue
      case AlertType.extremeHeat: return const Color(0xFFEF4444);  // red
      case AlertType.risingTrend: return const Color(0xFFF59E0B);  // amber
      case AlertType.fallingTrend: return const Color(0xFF3B82F6); // blue
      case AlertType.stable:      return const Color(0xFF10B981);  // green
    }
  }

  IconData _alertIcon(AlertType type) {
    switch (type) {
      case AlertType.extremeCold:  return Icons.ac_unit_rounded;
      case AlertType.extremeHeat:  return Icons.local_fire_department_rounded;
      case AlertType.risingTrend:  return Icons.trending_up_rounded;
      case AlertType.fallingTrend: return Icons.trending_down_rounded;
      case AlertType.stable:       return Icons.check_circle;
    }
  }

  Widget _emptyAlerts() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 36),
            SizedBox(height: 10),
            Text(
              'No alerts fired yet',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Alerts appear here when extreme\ntemperatures are detected.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(AlertRecord alert) {
    final color = _alertColor(alert.type);
    final icon  = _alertIcon(alert.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(210),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(230), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coloured circle badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 12,
                      color: const Color(0xFF111827).withAlpha(130),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      alert.timeAgo,
                      style: TextStyle(
                        color: const Color(0xFF111827).withAlpha(130),
                        fontSize: 12,
                      ),
                    ),
                  ],
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
        color: Colors.white.withAlpha(80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(120), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}


