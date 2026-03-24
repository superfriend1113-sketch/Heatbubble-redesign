import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../services/unit_service.dart';
import '../services/nudge_service.dart';
import '../services/comparison_service.dart';
import '../services/subscription_service.dart';
import '../services/ads_service.dart';
import '../models/temp_reading.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/hourly_chart_widget.dart';
import '../screens/paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sensor = SensorService();
  final _storage = StorageService();
  final _nudge = NudgeService();
  final _comparison = ComparisonService();
  final _subscription = SubscriptionService();
  final _ads = AdsService();

  double _currentTemp = 0;
  double _avgTemp = 0;
  bool _isCharging = false;
  bool _isStable = true;
  bool _showAiBanner = true;
  Timer? _pollTimer;
  Timer? _adCheckTimer;
  bool _showUpgradePrompt = false;
  bool _dialogShown = false; // Flag to prevent multiple dialogs

  // Trend
  String _trendLabel = 'Stable';
  double _variance = 0;

  @override
  void initState() {
    super.initState();
    _initSubscription();
    _loadData();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadData());
    
    // Continuous ad check every 3 seconds for free users
    _adCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      debugPrint('⏰ [HomeScreen] Timer tick - checking ads...');
      if (!_subscription.isPremium && mounted) {
        _checkWebViewAndEnforce();
      } else {
        debugPrint('   - Skipping (premium: ${_subscription.isPremium}, mounted: $mounted)');
      }
    });
  }

  Future<void> _initSubscription() async {
    debugPrint('🚀 [HomeScreen] Initializing subscription and ads...');
    await _subscription.init();
    debugPrint('   - Subscription initialized, isPremium: ${_subscription.isPremium}');
    
    // Init the SDK early so it's warm when AdBannerWidget builds.
    // AdBannerWidget itself will call loadBannerAd().
    await _ads.init();
    debugPrint('   - Ads initialized');
    
    // Check for ad loading issues immediately for free users
    if (!_subscription.isPremium) {
      debugPrint('   - User is FREE, setting up ad state listener');
      // Set up listener to check when ad fails
      _ads.onAdStateChanged = () {
        debugPrint('📢 [HomeScreen] Ad state changed!');
        debugPrint('   - isAdLoaded: ${_ads.isAdLoaded}');
        debugPrint('   - lastError: ${_ads.lastError}');
        if (mounted && !_ads.isAdLoaded && _ads.lastError != null) {
          // Ad failed to load - show dialog immediately
          debugPrint('   - Triggering dialog from ad state change');
          _checkWebViewAndEnforce();
        }
      };
    } else {
      debugPrint('   - User is PREMIUM, skipping ad setup');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _adCheckTimer?.cancel();
    _ads.disposeBannerAd();
    super.dispose();
  }

  void _checkWebViewAndEnforce() {
    debugPrint('🔍 [HomeScreen] _checkWebViewAndEnforce called');
    debugPrint('   - mounted: $mounted');
    debugPrint('   - isPremium: ${_subscription.isPremium}');
    debugPrint('   - _dialogShown: $_dialogShown');
    debugPrint('   - _ads.lastError: ${_ads.lastError}');
    debugPrint('   - _ads.isAdLoaded: ${_ads.isAdLoaded}');
    
    if (!mounted || _subscription.isPremium || _dialogShown) {
      debugPrint('   ❌ Skipping dialog (conditions not met)');
      return;
    }
    
    // Check if ad failed to load
    final hasError = _ads.lastError != null && !_ads.isAdLoaded;
    debugPrint('   - hasError: $hasError');
    
    if (hasError) {
      debugPrint('   ✅ Showing dialog!');
      // Set flag to prevent multiple dialogs
      _dialogShown = true;
      
      // Show blocking dialog immediately - user must choose
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (context) => WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orange.shade700.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.orange.shade400,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Title
                  const Text(
                    'Ads Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Message
                  Text(
                    'The free version requires ads to be displayed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade300,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ads cannot load on your device. Please choose an option below:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 20),
                  
                  // Upgrade to Premium Button (Primary)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        
                        // Pause ad checking while paywall is open
                        _adCheckTimer?.cancel();
                        
                        // Show paywall and wait for result
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          isDismissible: false,
                          builder: (context) => const PaywallScreen(),
                        );
                        
                        // After paywall closes, check if user upgraded
                        if (mounted) {
                          await _subscription.init(); // Refresh subscription status
                          
                          if (_subscription.isPremium) {
                            // User upgraded! Reset flag and don't restart timer
                            _dialogShown = false;
                            setState(() {}); // Rebuild to hide ads
                          } else {
                            // User didn't upgrade, restart ad checking
                            _dialogShown = false;
                            _adCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
                              if (!_subscription.isPremium && mounted) {
                                _checkWebViewAndEnforce();
                              }
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.star_rounded, size: 20),
                      label: const Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Enable Ads Button (Install WebView)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Open Play Store to WebView
                        final webViewUrl = Uri.parse('market://details?id=com.google.android.webview');
                        final webViewHttpUrl = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.webview');
                        
                        bool opened = false;
                        if (await canLaunchUrl(webViewUrl)) {
                          opened = await launchUrl(webViewUrl, mode: LaunchMode.externalApplication);
                        }
                        if (!opened && await canLaunchUrl(webViewHttpUrl)) {
                          opened = await launchUrl(webViewHttpUrl, mode: LaunchMode.externalApplication);
                        }
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          // Don't reset flag - keep it shown
                          // Show restart message
                          _showRestartDialog();
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Enable Ads',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E1E2E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Exit App Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        SystemNavigator.pop();
                      },
                      icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                      label: const Text(
                        'Exit App',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade300,
                        side: BorderSide(color: Colors.grey.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).then((_) {
        // If dialog is dismissed somehow, reset flag so it can show again
        if (mounted && !_subscription.isPremium && _ads.lastError != null) {
          _dialogShown = false;
        }
      });
    }
  }
  
  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  'Restart Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2E),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Message
                Text(
                  'After installing WebView from Play Store, please restart the app to see ads.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => SystemNavigator.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E2E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Close App',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          _isCharging = result.isCharging;
          _isStable = result.isStable;
          _variance = variance;
          _trendLabel = trend;
        });
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

            // ── Ad Banner for free users (at bottom) ──
            if (!_subscription.isPremium)
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