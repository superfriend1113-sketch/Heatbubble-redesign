import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/subscription_service.dart';
import '../services/unit_service.dart';
import 'auth/login_screen.dart';
import 'paywall_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuthService();
  final _firestore = FirebaseFirestoreService();
  final _sync = FirebaseSyncService();
  final _subscription = SubscriptionService();

  bool _isSyncing = false;
  Map<String, dynamic>? _cloudStats;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!_auth.isSignedIn) return;

    try {
      final userId = _auth.currentUser!.uid;
      
      // Load cloud statistics
      final stats = await _firestore.getUserStats(userId);
      
      if (mounted) {
        setState(() {
          _cloudStats = stats;
        });
      }
    } catch (e) {
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
      await _loadUserData();
      _showMessage('Data synced successfully', isError: false);
    } catch (e) {
      _showMessage('Sync failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _restoreData() async {
    if (!_auth.isSignedIn) {
      _showMessage('Please sign in to restore data');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Restore Data',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will restore your data from the cloud. Continue?',
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
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);

    try {
      await _sync.restoreFromCloud();
      await _loadUserData();
      _showMessage('Data restored successfully', isError: false);
    } catch (e) {
      _showMessage('Restore failed: $e');
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
        setState(() {
          _cloudStats = null;
        });
        _showMessage('Signed out successfully', isError: false);
      }
    } catch (e) {
      _showMessage('Sign out failed: $e');
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            color: Colors.red,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will permanently delete your account and all data. This action cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete cloud data first
      await _sync.clearCloudData();
      
      // Delete account
      await _auth.deleteAccount();
      
      if (mounted) {
        _showMessage('Account deleted successfully', isError: false);
      }
    } catch (e) {
      _showMessage('Delete failed: $e');
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
    final user = _auth.currentUser;
    final isSignedIn = _auth.isSignedIn;
    final isPremium = _subscription.isPremium;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isSyncing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // User Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPremium
                          ? const Color(0xFFFF6B35)
                          : Colors.grey.shade700,
                    ),
                    child: Icon(
                      isSignedIn ? LucideIcons.user : LucideIcons.userX,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name/Email
                  if (isSignedIn) ...[
                    Text(
                      user?.displayName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Anonymous',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Not Signed In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to sync your data',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Premium Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isPremium
                          ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPremium
                            ? const Color(0xFFFF6B35)
                            : Colors.grey.shade700,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPremium ? LucideIcons.crown : LucideIcons.lock,
                          size: 16,
                          color: isPremium
                              ? const Color(0xFFFF6B35)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPremium ? 'Premium' : 'Free',
                          style: TextStyle(
                            color: isPremium
                                ? const Color(0xFFFF6B35)
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cloud Stats (if signed in)
            if (isSignedIn && _cloudStats != null) ...[
              const Text(
                'Cloud Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Readings',
                      '${_cloudStats!['totalReadings'] ?? 0}',
                      LucideIcons.activity,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Avg Temp',
                      '${(_cloudStats!['avgTemp'] ?? 0.0).toStringAsFixed(1)}°',
                      LucideIcons.thermometer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Actions Section
            const Text(
              'Account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Sign In / Sign Out
            if (!isSignedIn)
              _actionTile(
                icon: LucideIcons.logIn,
                title: 'Sign In',
                subtitle: 'Sync your data across devices',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                  setState(() {});
                  _loadUserData();
                },
              )
            else ...[
              _actionTile(
                icon: LucideIcons.refreshCw,
                title: 'Sync Data',
                subtitle: 'Upload local data to cloud',
                onTap: _syncData,
              ),
              _actionTile(
                icon: LucideIcons.download,
                title: 'Restore Data',
                subtitle: 'Download data from cloud',
                onTap: _restoreData,
              ),
              _actionTile(
                icon: LucideIcons.logOut,
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                onTap: _signOut,
              ),
            ],

            const SizedBox(height: 24),

            // Premium Section
            const Text(
              'Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (!isPremium)
              _actionTile(
                icon: LucideIcons.crown,
                title: 'Upgrade to Premium',
                subtitle: 'Unlock all features for \$2.99',
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => const PaywallScreen(),
                  );
                  setState(() {});
                },
                iconColor: const Color(0xFFFF6B35),
              )
            else
              _actionTile(
                icon: LucideIcons.check,
                title: 'Premium Active',
                subtitle: 'Thank you for your support!',
                onTap: null,
                iconColor: Colors.green,
              ),

            const SizedBox(height: 24),

            // Settings Section
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _actionTile(
              icon: LucideIcons.thermometer,
              title: 'Temperature Unit',
              subtitle: 'Change temperature display unit',
              onTap: () => _showUnitPicker(),
            ),

            const SizedBox(height: 24),

            // Danger Zone
            if (isSignedIn) ...[
              const Text(
                'Danger Zone',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _actionTile(
                icon: LucideIcons.trash2,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                onTap: _deleteAccount,
                iconColor: Colors.red,
              ),
            ],

            const SizedBox(height: 24),

            // App Info
            Center(
              child: Column(
                children: [
                  Text(
                    'HeatBubble v1.0.0',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Made with ❤️ for temperature tracking',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? const Color(0xFFFF6B35)).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor ?? const Color(0xFFFF6B35),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
        trailing: onTap != null
            ? Icon(
                LucideIcons.chevronRight,
                color: Colors.grey.shade600,
                size: 20,
              )
            : null,
      ),
    );
  }

  void _showUnitPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Temperature Unit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: UnitService.instance,
              builder: (context, _) {
                final us = UnitService.instance;
                return Column(
                  children: [
                    _unitOption('Celsius (°C)', TempUnit.celsius, us),
                    _unitOption('Fahrenheit (°F)', TempUnit.fahrenheit, us),
                    _unitOption('Kelvin (K)', TempUnit.kelvin, us),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitOption(String label, TempUnit unit, UnitService us) {
    final isSelected = us.unit == unit;
    return ListTile(
      onTap: () {
        us.setUnit(unit);
        Navigator.pop(context);
      },
      leading: Icon(
        isSelected ? LucideIcons.check : LucideIcons.circle,
        color: isSelected ? const Color(0xFFFF6B35) : Colors.grey.shade600,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade400,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
