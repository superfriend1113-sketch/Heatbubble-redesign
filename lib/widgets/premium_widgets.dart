import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/ads_service.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';

/// Ad banner widget that automatically shows for free users
/// Falls back to premium upgrade prompt if ad fails to load within 5 seconds
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  final _ads = AdsService();
  final _subscription = SubscriptionService();
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🎨 [AdBannerWidget] initState called');
    debugPrint('   - isPremium: ${_subscription.isPremium}');
    debugPrint('═══════════════════════════════════════════════════════');
    
    // Register setState callback so widget rebuilds when ad loads/fails
    _ads.onAdStateChanged = () {
      debugPrint('🔄 [AdBannerWidget] Ad state changed, rebuilding widget');
      if (mounted) setState(() {});
    };
    
    // Set timeout for ad loading (5 seconds)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_ads.isAdLoaded) {
        debugPrint('⏱️  [AdBannerWidget] Ad load timeout - showing fallback');
        setState(() {
          _showFallback = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _ads.onAdStateChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 [AdBannerWidget] build called');
    
    if (_subscription.isPremium) {
      debugPrint('   - User is premium, hiding ad');
      return const SizedBox.shrink();
    }

    // Show fallback if timeout or ad failed
    if (_showFallback || (_ads.lastError != null && !_ads.isAdLoaded)) {
      debugPrint('   - Showing premium upgrade fallback');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: PremiumUpgradePrompt(
          onDismiss: () {
            setState(() => _showFallback = false);
          },
        ),
      );
    }

    final adWidget = _ads.getBannerAdWidget();
    if (adWidget == null) {
      debugPrint('   - No ad widget available, showing loading');
      
      // Show minimal loading indicator
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading ad...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    debugPrint('   - Showing ad widget');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: adWidget,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Advertisement',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(LucideIcons.x, color: Colors.grey[600]),
                    onPressed: () {
                      _ads.trackSwipeAway();
                      setState(() {
                        _ads.disposeBannerAd();
                        _showFallback = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Premium upgrade prompt widget
class PremiumUpgradePrompt extends StatelessWidget {
  final VoidCallback? onDismiss;

  const PremiumUpgradePrompt({
    super.key,
    this.onDismiss,
  });

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PaywallScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8555)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ Unlock Premium',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hourly charts, custom alerts & more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    LucideIcons.x,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _showPaywall(context),
              child: const Text(
                'Upgrade - \$2.99',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feature locked overlay
class FeatureLockedOverlay extends StatelessWidget {
  final String featureName;
  final VoidCallback onUpgrade;

  const FeatureLockedOverlay({
    super.key,
    required this.featureName,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.lock,
                size: 48,
                color: Color(0xFFFF6B35),
              ),
              const SizedBox(height: 16),
              Text(
                '$featureName\nis a Premium Feature',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: onUpgrade,
                icon: const Icon(LucideIcons.lock),
                label: const Text('Unlock for \$2.99'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
