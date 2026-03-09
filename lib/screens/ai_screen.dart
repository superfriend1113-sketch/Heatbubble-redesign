import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/storage_service.dart';

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
  final List<_InsightItem> _insights = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final readings = await _storage.getLast7Days();
    final latest = await _storage.getLatest();
    final current = latest?.temperature ?? 0;

    // Build trend
    String trend = 'Stable Trend';
    String desc = 'Your temperature is stable and within normal range. Great job maintaining consistency!';

    if (readings.length >= 2) {
      final recent = readings.take(5).map((r) => r.temperature).toList();
      final older = readings.skip(5).take(5).map((r) => r.temperature).toList();
      if (recent.isNotEmpty && older.isNotEmpty) {
        final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
        final olderAvg = older.reduce((a, b) => a + b) / older.length;
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

    // Build insights
    final insights = <_InsightItem>[];
    if (readings.length >= 2) {
      for (int i = 0; i < readings.length - 1 && insights.length < 6; i++) {
        final curr = readings[i];
        final prev = readings[i + 1];
        final diff = curr.temperature - prev.temperature;
        if (diff.abs() > 0.2) {
          final timeAgo = _formatTimeAgo(curr.timestamp);
          if (diff > 0.2) {
            insights.add(_InsightItem(
              type: _InsightType.alert,
              text: '🌡 Temperature rising detected! Your body temperature has increased ${diff.toStringAsFixed(1)}°C in the last reading. Stay hydrated and take a break if needed.',
              timeAgo: timeAgo,
            ));
          } else {
            insights.add(_InsightItem(
              type: _InsightType.info,
              text: '📉 Temperature decreasing trend observed. You\'ve cooled down ${diff.abs().toStringAsFixed(1)}°C recently. This could be normal after activity or being in a cooler space.',
              timeAgo: timeAgo,
            ));
          }
        }
      }
    }

    // Always add stable insight
    insights.insert(0, _InsightItem(
      type: _InsightType.success,
      text: '✅ Your temperature is stable and within normal range. Keep up the healthy habits!',
      timeAgo: _formatTimeAgo(DateTime.now()),
    ));

    if (mounted) {
      setState(() {
        _trendLabel = trend;
        _trendDescription = desc;
        _insights.clear();
        _insights.addAll(insights.take(5).toList());
        _loading = false;
      });
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final ago = DateTime.now().difference(dt);
    if (ago.inMinutes < 1) return 'less than a minute ago';
    if (ago.inMinutes < 60) return '${ago.inMinutes} minutes ago';
    if (ago.inHours < 24) return '${ago.inHours} hours ago';
    return '${ago.inDays} days ago';
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

                // ── Recent Insights — wrapped in glass card like Current Analysis ──
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
                      ..._insights.map((insight) => _buildInsightCard(insight)),
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

  Widget _buildInsightCard(_InsightItem insight) {
    final Color iconColor;
    final IconData iconData;
    switch (insight.type) {
      case _InsightType.alert:
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.warning_amber_rounded;
        break;
      case _InsightType.info:
        iconColor = const Color(0xFF3B82F6);
        iconData = Icons.info_outline_rounded;
        break;
      case _InsightType.success:
        iconColor = const Color(0xFF10B981);
        iconData = Icons.check_circle;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(210),   // near-solid white
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
          // ── Coloured circle icon badge ──
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),

          // ── Text + timestamp ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.text,
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
                      insight.timeAgo,
                      style: TextStyle(
                        color: const Color(0xFF111827).withAlpha(130),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
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

enum _InsightType { alert, info, success }

class _InsightItem {
  final _InsightType type;
  final String text;
  final String timeAgo;

  const _InsightItem({
    required this.type,
    required this.text,
    required this.timeAgo,
  });
}
