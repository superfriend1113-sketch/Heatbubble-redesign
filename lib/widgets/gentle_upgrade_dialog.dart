import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../screens/paywall_screen.dart';

/// Gentle, dismissible upgrade prompt
class GentleUpgradeDialog extends StatelessWidget {
  const GentleUpgradeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    
    // Responsive sizing
    final dialogPadding = (screenWidth * 0.05).clamp(16.0, 24.0);
    final iconSize = (screenWidth * 0.08).clamp(28.0, 32.0);
    final titleSize = (screenWidth * 0.055).clamp(20.0, 24.0);
    final subtitleSize = (screenWidth * 0.035).clamp(13.0, 14.0);
    final featureSize = (screenWidth * 0.035).clamp(13.0, 14.0);
    final priceSize = (screenWidth * 0.045).clamp(16.0, 18.0);
    final buttonSize = (screenWidth * 0.04).clamp(15.0, 16.0);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screenHeight * 0.8,
        ),
        padding: EdgeInsets.all(dialogPadding),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1E2E),
              Color(0xFF2D2D3F),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sparkle icon
              Container(
                padding: EdgeInsets.all(dialogPadding * 0.67),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8555)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  LucideIcons.sparkles,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              SizedBox(height: dialogPadding * 0.83),

              // Title
              Text(
                'Enjoying HeatBubble?',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: dialogPadding * 0.5),

              // Subtitle
              Text(
                'Unlock premium features for the best experience',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: Colors.grey.shade300,
                  height: 1.5,
                ),
              ),
              SizedBox(height: dialogPadding),

              // Features list
              _featureItem(LucideIcons.activity, 'Hourly temperature charts', featureSize),
              SizedBox(height: dialogPadding * 0.5),
              _featureItem(LucideIcons.bell, 'Custom heat alerts', featureSize),
              SizedBox(height: dialogPadding * 0.5),
              _featureItem(LucideIcons.cloud, 'Cloud backup & sync', featureSize),
              SizedBox(height: dialogPadding * 0.5),
              _featureItem(LucideIcons.sparkles, 'No ads, ever', featureSize),
              SizedBox(height: dialogPadding),

              // Price
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: dialogPadding * 0.5,
                  horizontal: dialogPadding * 0.83,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.gift,
                      color: const Color(0xFFFF6B35),
                      size: featureSize + 6,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '7-day free trial • Starting at \$1.99/mo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: subtitleSize,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: dialogPadding),

              // Upgrade button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const PaywallScreen(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: dialogPadding * 0.67),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      fontSize: buttonSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: dialogPadding * 0.5),

              // Maybe later button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: subtitleSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureItem(IconData icon, String text, double fontSize) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFFF6B35),
          size: fontSize + 6,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
            ),
          ),
        ),
      ],
    );
  }
}
