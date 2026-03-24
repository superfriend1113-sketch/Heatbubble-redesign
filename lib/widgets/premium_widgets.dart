import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ads_service.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';

/// Ad banner widget that automatically shows for free users
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  final _ads = AdsService();
  final _subscription = SubscriptionService();

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
    
    // Trigger ad load immediately for free users
    if (!_subscription.isPremium) {
      debugPrint('🚀 [AdBannerWidget] Triggering ad load');
      _ads.loadBannerAd();
    } else {
      debugPrint('⚠️  [AdBannerWidget] Skipping ad load (premium user)');
    }
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

    final adWidget = _ads.getBannerAdWidget();
    if (adWidget == null) {
      debugPrint('   - No ad widget available, showing loading');
      
      // Just show a simple loading indicator - dialog will handle errors
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          height: 50,
          color: Colors.black12,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    debugPrint('   - Showing ad widget');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        color: Colors.black26,
        child: Column(
          children: [
            adWidget,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    iconSize: 16,
                    icon: const Icon(LucideIcons.x, color: Colors.grey),
                    onPressed: () {
                      _ads.trackSwipeAway();
                      setState(() {
                        _ads.disposeBannerAd();
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
