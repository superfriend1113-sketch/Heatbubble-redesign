import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../services/unit_service.dart';
import '../services/subscription_service.dart';
import '../services/ads_service.dart';
import '../services/reading_counter_service.dart';
import '../services/smart_sync_service.dart';
import '../services/home_widget_service.dart';
import '../models/temp_reading.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/ad_failure_banner.dart';
import '../widgets/gentle_upgrade_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sensor = SensorService();
  final _storage = StorageService();
  final _subscription = SubscriptionService();
  final _ads = AdsService();
  final _readingCounter = ReadingCounterService();
  final _smartSync = SmartSyncService();
  final _homeWidget = HomeWidgetService();

  double _currentTemp = 0;
  double _avgTemp = 0;
  bool _showAiBanner = true;
  Timer? _pollTimer;
  Timer? _syncTimer;
  bool _showAdFailureBanner = false;

  // Trend
  String _trendLabel = 'Stable';
  double _variance = 0;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadData();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadData());
    
    // Smart sync every 5 minutes (only syncs aggregates, very cheap)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => _smartSync.smartSync());
  }

  Future<void> _initServices() async {
    debugPrint('🚀 [HomeScreen] Initializing services...');
    
    // Initialize subscription
    await _subscription.init();
    debugPrint('   - Subscription initialized, isPremium: ${_subscription.isPremium}');
    
    // Initialize reading counter
    await _readingCounter.init();
    
    // Initialize ads for free users
    if (!_subscription.isPremium) {
      await _ads.init();
      debugPrint('   - Ads initialized');
      
      // Set up ad state listener BEFORE loading ad
      _ads.onAdStateChanged = () {
        if (mounted) {
          setState(() {
            // Show banner if ads fail, but don't block
            _showAdFailureBanner = !_ads.isAdLoaded && _ads.lastError != null;
          });
        }
      };
      
      // Load the banner ad
      await _ads.loadBannerAd();
      debugPrint('   - Banner ad load initiated');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _syncTimer?.cancel();
    _ads.disposeBannerAd();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final result = await _sensor.getCurrentTemp();
      final temp = result.calibrated;

      if (temp > 0) {
        await _storage.saveReading(TempReading(
          temperature: temp,
          rawTemp: result.raw,
          timestamp: DateTime.now(),
        ));
        
        // Increment reading counter for free users
        if (!_subscription.isPremium) {
          await _readingCounter.increment();
          
          // Check if we should show gentle upgrade prompt
          if (_readingCounter.shouldShowUpgradePrompt() && mounted) {
            await _readingCounter.markPromptShown();
            
            // Show gentle, dismissible prompt
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => const GentleUpgradeDialog(),
                );
              }
            });
          }
        }
      }

      final avg = await _storage.getSevenDayAverage();
      final readings = await _storage.getLast7Days();

      // Calculate variance & trend
      double variance = 0;
      String trend = 'Stable';
      if (readings.length >= 2) {
        final temps = readings.take(10).map((r) => r.temperature).toList();
        final mean = temps.reduce((a, b) => a + b) / temps.length;
        final sq = temps.map((t) => (t - mean) * (t - mean)).reduce((a, b) => a + b);
        variance = sq / temps.length;

        // Trend
        final recent = temps.take(3).toList();
        final older = temps.skip(3).take(3).toList();
        if (recent.isNotEmpty && older.isNotEmpty) {
          final recAvg = recent.reduce((a, b) => a + b) / recent.length;
          final oldAvg = older.reduce((a, b) => a + b) / older.length;
          if (recAvg - oldAvg > 0.2) {
            trend = 'Rising';
          } else if (recAvg - oldAvg < -0.2) {
            trend = 'Falling';
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentTemp = temp;
          _avgTemp = avg;
          // _isCharging and _isStable removed as unused
          _variance = variance;
          _trendLabel = trend;
        });
        // Push data to device home screen widget.
        // isPremium: also allow dev bypass so testing works without a subscription.
        _homeWidget.updateWidget(
          temperature: temp,
          trend: trend,
          unit: UnitService.instance.unit,
          isPremium: _subscription.isPremium || kDevHomeWidgetBypass,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final hPad = (sw * 0.05).clamp(16.0, 24.0);
    final topPad = mq.padding.top;

    return ListenableBuilder(
      listenable: UnitService.instance,
      builder: (context, _) {
        final us = UnitService.instance;

        // AI banner content
        final bool isAlert = _trendLabel == 'Rising' && _currentTemp > 37.5;
        final String aiBannerText = isAlert
            ? 'Temperature rising detected! Your body temperature has increased. Stay hydrated and take a break if needed.'
            : 'Your temperature is stable and within normal range. Keep up the healthy habits!';
        final String aiBadge = isAlert ? 'Alert' : 'Good';

        return ListView(
          padding: EdgeInsets.fromLTRB(hPad, topPad + 16, hPad, 32),
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'HeatBubble',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pocket Temperature Monitor',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _loadData,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(70),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.refreshCw, size: 18, color: Color(0xFF111827)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── AI Health Assistant banner ──
            if (_showAiBanner)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(190),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(200), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isAlert
                            ? const Color(0xFFFF4E50).withAlpha(30)
                            : const Color(0xFF10B981).withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAlert ? Icons.warning_amber_rounded : Icons.check_circle,
                        size: 20,
                        color: isAlert ? const Color(0xFFFF4E50) : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'AI Health Assistant',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAlert
                                      ? const Color(0xFFFF4E50).withAlpha(30)
                                      : const Color(0xFF10B981).withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  aiBadge,
                                  style: TextStyle(
                                    color: isAlert ? const Color(0xFFFF4E50) : const Color(0xFF10B981),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            aiBannerText,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showAiBanner = false),
                      child: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),

            SizedBox(height: sh * 0.04),

            // ── Thermometer icon ──
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(70),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.thermostat_rounded,
                  size: 28,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            SizedBox(height: sh * 0.025),

            // ── Large temperature readout ──
            Center(
              child: Text(
                us.formatValue(_currentTemp),
                style: TextStyle(
                  color: const Color(0xFF111827),
                  fontSize: (sw * 0.22).clamp(72.0, 110.0),
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -3,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── "Pocket Temperature" label ──
            const Center(
              child: Text(
                'Pocket Temperature',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Unit toggle pill (°C / °F / K) ──
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(100),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _unitPill('°C', TempUnit.celsius, us),
                    const SizedBox(width: 4),
                    _unitPill('°F', TempUnit.fahrenheit, us),
                    const SizedBox(width: 4),
                    _unitPill('K', TempUnit.kelvin, us), // Kelvin
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Sensor Active indicator ──
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Sensor Active',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: sh * 0.04),

            // ── Quick stats row: Average / Variance / Trend ──
            Row(
              children: [
                Expanded(
                  child: _quickStatCard(
                    'Average',
                    _avgTemp > 0 ? us.format(_avgTemp) : '--',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickStatCard(
                    'Variance',
                    '±${_variance.toStringAsFixed(1)}°',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickStatTrend(_trendLabel),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Home Screen Widget promo card ──
            _HomeWidgetPromoCard(
              isPremium: _subscription.isPremium,
              currentTemp: _currentTemp,
              trendLabel: _trendLabel,
            ),

            const SizedBox(height: 20),

            // ── Ad Failure Banner (non-blocking) ──
            if (!_subscription.isPremium && _showAdFailureBanner)
              AdFailureBanner(
                onDismiss: () {
                  setState(() => _showAdFailureBanner = false);
                },
              ),

            // ── Ad Banner for free users (at bottom) ──
            if (!_subscription.isPremium && !_showAdFailureBanner)
              const AdBannerWidget(),
          ],
        );
      },
    );
  }

  // ── Unit pill widget ──
  Widget _unitPill(String label, TempUnit? unit, UnitService us) {
    final isActive = unit != null && us.unit == unit;
    return GestureDetector(
      onTap: unit != null ? () => us.setUnit(unit) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF111827) : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Glass stat card ──
  Widget _quickStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(80), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF111827).withAlpha(140),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStatTrend(String trend) {
    IconData icon = LucideIcons.moveRight;
    Color iconColor = const Color(0xFF6B7280);
    if (trend == 'Rising') {
      icon = LucideIcons.trendingUp;
      iconColor = const Color(0xFFFF4E50);
    } else if (trend == 'Falling') {
      icon = LucideIcons.trendingDown;
      iconColor = const Color(0xFF3B82F6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(80), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 6),
          Text(
            trend,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen Widget Promo Card
// Shows instructions to add the widget; premium-gated with dev bypass.
// ─────────────────────────────────────────────────────────────────────────────

/// Set to true during development so you can see the widget banner and test the
/// feature without purchasing premium. Flip to false before releasing.
const bool kDevHomeWidgetBypass = true;

class _HomeWidgetPromoCard extends StatelessWidget {
  final bool isPremium;
  final double currentTemp;
  final String trendLabel;

  const _HomeWidgetPromoCard({
    required this.isPremium,
    required this.currentTemp,
    required this.trendLabel,
  });

  bool get _canSee => kDevHomeWidgetBypass || isPremium;

  @override
  Widget build(BuildContext context) {
    if (!_canSee) return const SizedBox.shrink();

    final isAlert = trendLabel == 'Rising' && currentTemp > 37.5;
    final statusColor =
        isAlert ? const Color(0xFFFF4E50) : const Color(0xFF10B981);
    final statusIcon =
        isAlert ? Icons.warning_amber_rounded : Icons.check_circle;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(200),
            Colors.white.withAlpha(160),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(220), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Home Screen Widget',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (kDevHomeWidgetBypass && !isPremium)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF10B981).withAlpha(70)),
                        ),
                        child: const Text(
                          '🛠  Dev Mode',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Mini widget preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withAlpha(60),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HeatBubble',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTemp > 0
                          ? UnitService.instance.format(currentTemp)
                          : '--°',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trendLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor == const Color(0xFFFF4E50)
                        ? Colors.white
                        : Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Step-by-step instructions
          const Text(
            'How to add to your home screen:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          _Step(
              n: '1',
              text: 'Long-press an empty area on your home screen'),
          const SizedBox(height: 5),
          _Step(n: '2', text: 'Tap Widgets'),
          const SizedBox(height: 5),
          _Step(n: '3', text: 'Search for \'HeatBubble\' and tap & hold it'),
          const SizedBox(height: 5),
          _Step(n: '4', text: 'Drop it on your home screen'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF6B35),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF374151).withAlpha(200),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}