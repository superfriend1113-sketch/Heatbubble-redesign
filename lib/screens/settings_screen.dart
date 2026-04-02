import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/unit_service.dart';
import '../services/subscription_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/nudge_service.dart';
import '../services/ads_service.dart';
import '../screens/paywall_screen.dart';
import '../screens/custom_alerts_screen.dart';
import '../screens/auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoDetectSensors = true;
  bool _batteryFallback = true;
  bool _notificationsEnabled = true;
  bool _temperatureAlerts = true;
  bool _trendAlerts = true;
  bool _dailyReminders = false;
  
  final _subscription = SubscriptionService();
  final _auth = FirebaseAuthService();
  final _sync = FirebaseSyncService();
  final _firestore = FirebaseFirestoreService();
  final _ads = AdsService();
  
  bool _isSyncing = false;
  Map<String, dynamic>? _cloudStats;

  @override
  void initState() {
    super.initState();
    _subscription.init();
    _loadCloudData();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    // Load notification preferences from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _temperatureAlerts = prefs.getBool('temperature_alerts') ?? true;
      _trendAlerts = prefs.getBool('trend_alerts') ?? true;
      _dailyReminders = prefs.getBool('daily_reminders') ?? false;
    });
  }

  Future<void> _saveNotificationPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadCloudData() async {
    if (!_auth.isSignedIn) return;

    try {
      final userId = _auth.currentUser!.uid;
      final stats = await _firestore.getUserStats(userId);
      
      if (mounted) {
        setState(() => _cloudStats = stats);
      }
    } catch (e) {
      debugPrint('Error loading cloud data: $e');
    }
  }

  Future<void> _syncData() async {
    if (!_auth.isSignedIn) {
      _showMessage('Please sign in to sync data');
      return;
    }

    setState(() => _isSyncing = true);

    try {
      await _sync.syncToCloud();
      await _loadCloudData();
      _showMessage('Data synced successfully', isError: false);
    } catch (e) {
      _showMessage('Sync failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _auth.signOut();
      if (mounted) {
        setState(() => _cloudStats = null);
        _showMessage('Signed out successfully', isError: false);
      }
    } catch (e) {
      _showMessage('Sign out failed: $e');
    }
  }

  Future<void> _restorePurchases() async {
    try {
      _showMessage('Restoring purchases...', isError: false);
      
      final success = await _subscription.restorePurchases();
      
      if (!mounted) return;
      
      if (success) {
        _showMessage('Premium restored successfully! 🎉', isError: false);
        setState(() {}); // Refresh UI
      } else {
        _showMessage('No active subscriptions found', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to restore purchases', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final hPad = (sw * 0.05).clamp(16.0, 24.0);
    final topPad = mq.padding.top;

    return ListenableBuilder(
      listenable: UnitService.instance,
      builder: (context, _) {
        final us = UnitService.instance;
        return ListView(
          padding: EdgeInsets.fromLTRB(hPad, topPad + 20, hPad, 32),
          children: [
            // ── Header ──
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Customize your experience',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Account Section (Firebase) ──
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _auth.isSignedIn ? LucideIcons.user : LucideIcons.userX,
                        size: 18,
                        color: const Color(0xFF111827),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Account',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_isSyncing) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (!_auth.isSignedIn) ...[
                    // Not signed in
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Not Signed In',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  'Sign in to sync your data',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                              setState(() {});
                              _loadCloudData();
                            },
                            child: const Text('Sign In'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Signed in
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _auth.currentUser?.displayName ?? 'User',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      _auth.currentUser?.email ?? 'Anonymous',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                LucideIcons.check,
                                color: const Color(0xFF10B981),
                                size: 20,
                              ),
                            ],
                          ),
                          
                          // Cloud stats
                          if (_cloudStats != null) ...[
                            const SizedBox(height: 12),
                            Divider(color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _miniStat(
                                  'Readings',
                                  '${_cloudStats!['totalReadings'] ?? 0}',
                                ),
                                _miniStat(
                                  'Avg Temp',
                                  '${(_cloudStats!['avgTemp'] ?? 0.0).toStringAsFixed(1)}°',
                                ),
                              ],
                            ),
                          ],
                          
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _syncData,
                                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                                  label: const Text('Sync'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF111827)),
                                    foregroundColor: const Color(0xFF111827),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _signOut,
                                  icon: const Icon(LucideIcons.logOut, size: 16),
                                  label: const Text('Sign Out'),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red.shade300),
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Subscription Status ──
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.crown, size: 18, color: Color(0xFFFF6B35)),
                      const SizedBox(width: 8),
                      const Text(
                        'Subscription',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _subscription.isPremium
                          ? const Color(0xFFFF6B35).withAlpha(30)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _subscription.isPremium ? 'Premium Active' : 'Free Tier',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _subscription.isPremium
                                    ? const Color(0xFFFF6B35)
                                    : Colors.grey[700],
                              ),
                            ),
                            if (_subscription.isPremium)
                              FutureBuilder<String?>(
                                future: _subscription.getPurchaseDate(),
                                builder: (context, snap) {
                                  return Text(
                                    snap.data ?? 'Lifetime access',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        if (!_subscription.isPremium)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => const PaywallScreen(),
                              );
                            },
                            child: const Text('Upgrade'),
                          ),
                      ],
                    ),
                  ),
                  if (_subscription.isPremium) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _restorePurchases,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          side: const BorderSide(color: Color(0xFF111827)),
                        ),
                        child: const Text('Restore Purchases'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Custom Alerts (Premium Feature) ──
            if (_subscription.isPremium)
              _glassCard(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomAlertsScreen(),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(LucideIcons.bell, size: 18, color: Color(0xFFFF6B35)),
                              SizedBox(width: 8),
                              Text(
                                'Custom Alerts',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: Color(0xFF111827),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create and manage temperature alerts',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_subscription.isPremium) const SizedBox(height: 20),

            // ── Temperature Unit ──
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.thermostat_rounded, size: 18, color: Color(0xFF111827)),
                      const SizedBox(width: 8),
                      const Text(
                        'Temperature Unit',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _unitOption(
                    title: 'Celsius (°C)',
                    subtitle: 'Standard metric unit',
                    unit: TempUnit.celsius,
                    us: us,
                  ),
                  const SizedBox(height: 10),
                  _unitOption(
                    title: 'Fahrenheit (°F)',
                    subtitle: 'Imperial unit',
                    unit: TempUnit.fahrenheit,
                    us: us,
                  ),
                  const SizedBox(height: 10),
                  _unitOption(
                    title: 'Kelvin (K)',
                    subtitle: 'Absolute temperature',
                    unit: TempUnit.kelvin,
                    us: us,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Notifications ──
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.bell, size: 18, color: Color(0xFF111827)),
                      const SizedBox(width: 8),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _toggleRow(
                    title: 'Enable Notifications',
                    subtitle: 'Receive app notifications',
                    value: _notificationsEnabled,
                    onChanged: (v) async {
                      // Show interstitial ad once per screen for free users
                      if (!_subscription.isPremium) {
                        await _ads.showInterstitialAdForScreen('settings');
                      }
                      
                      setState(() => _notificationsEnabled = v);
                      _saveNotificationPreference('notifications_enabled', v);
                    },
                  ),
                  if (_notificationsEnabled) ...[
                    const SizedBox(height: 8),
                    Divider(color: const Color(0xFF111827).withAlpha(20), height: 24),
                    const SizedBox(height: 8),
                    _toggleRow(
                      title: 'Temperature Alerts',
                      subtitle: 'Alert when temperature is extreme',
                      value: _temperatureAlerts,
                      onChanged: (v) async {
                        // Show interstitial ad once per screen for free users
                        if (!_subscription.isPremium) {
                          await _ads.showInterstitialAdForScreen('settings');
                        }
                        
                        setState(() => _temperatureAlerts = v);
                        _saveNotificationPreference('temperature_alerts', v);
                      },
                    ),
                    const SizedBox(height: 8),
                    _toggleRow(
                      title: 'Trend Alerts',
                      subtitle: 'Alert on significant temperature changes',
                      value: _trendAlerts,
                      onChanged: (v) async {
                        // Show interstitial ad once per screen for free users
                        if (!_subscription.isPremium) {
                          await _ads.showInterstitialAdForScreen('settings');
                        }
                        
                        setState(() => _trendAlerts = v);
                        _saveNotificationPreference('trend_alerts', v);
                      },
                    ),
                    const SizedBox(height: 8),
                    _toggleRow(
                      title: 'Daily Reminders',
                      subtitle: 'Remind to check temperature daily',
                      value: _dailyReminders,
                      onChanged: (v) async {
                        // Show interstitial ad once per screen for free users
                        if (!_subscription.isPremium) {
                          await _ads.showInterstitialAdForScreen('settings');
                        }
                        
                        setState(() => _dailyReminders = v);
                        await _saveNotificationPreference('daily_reminders', v);
                        // Schedule or cancel daily reminder
                        await NudgeService().scheduleDailyReminder();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Sensor Preferences ──
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.smartphone, size: 18, color: Color(0xFF111827)),
                      const SizedBox(width: 8),
                      const Text(
                        'Sensor Preferences',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _toggleRow(
                    title: 'Auto-detect sensors',
                    subtitle: 'Automatically use available sensors',
                    value: _autoDetectSensors,
                    onChanged: (v) async {
                      // Show interstitial ad once per screen for free users
                      if (!_subscription.isPremium) {
                        await _ads.showInterstitialAdForScreen('settings');
                      }
                      
                      setState(() => _autoDetectSensors = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  _toggleRow(
                    title: 'Battery fallback',
                    subtitle: 'Use battery temp when needed',
                    value: _batteryFallback,
                    onChanged: (v) async {
                      // Show interstitial ad once per screen for free users
                      if (!_subscription.isPremium) {
                        await _ads.showInterstitialAdForScreen('settings');
                      }
                      
                      setState(() => _batteryFallback = v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── App Information ──
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF111827)),
                      const SizedBox(width: 8),
                      const Text(
                        'App Information',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _infoRow('Version', '1.0.0'),
                  Divider(color: const Color(0xFF111827).withAlpha(20), height: 24),
                  _infoRow('Build', 'MVP'),
                  Divider(color: const Color(0xFF111827).withAlpha(20), height: 24),
                  _infoRow('Developer', 'HeatBubble Team'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Footer ──
            Center(
              child: Column(
                children: [
                  Text(
                    '© 2026 HeatBubble. All rights reserved.',
                    style: TextStyle(
                      color: const Color(0xFF111827).withAlpha(140),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For entertainment purposes only. Not medical advice.',
                    style: TextStyle(
                      color: const Color(0xFF111827).withAlpha(120),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Unit option card ──
  Widget _unitOption({
    required String title,
    required String subtitle,
    required TempUnit unit,
    required UnitService us,
  }) {
    final isActive = us.unit == unit;
    return GestureDetector(
      onTap: () async {
        // Show interstitial ad once per screen for free users
        if (!_subscription.isPremium) {
          await _ads.showInterstitialAdForScreen('settings');
        }
        
        // Set the unit
        us.setUnit(unit);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF111827) : Colors.white.withAlpha(60),
          borderRadius: BorderRadius.circular(14),
          border: isActive ? null : Border.all(color: Colors.white.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF111827),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: isActive ? Colors.white.withAlpha(170) : const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Toggle row ──
  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFFFF6B35),
          inactiveTrackColor: const Color(0xFF9CA3AF),
          inactiveThumbColor: Colors.white,
        ),
      ],
    );
  }

  // ── Info row ──
  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Glass card ──
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

  // ── Mini stat widget ──
  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

