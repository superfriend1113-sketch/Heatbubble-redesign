import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  Future<void> _onGetStarted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final topPad = mq.padding.top;
    final bottomPad = mq.padding.bottom;
    final hPad = (sw * 0.07).clamp(24.0, 36.0);

    // Responsive logo size
    final logoSize = (sw * 0.21).clamp(76.0, 96.0);
    final titleSize = (sw * 0.09).clamp(30.0, 40.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Padding(
        padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: sh * 0.07),

            // ── App logo ──────────────────────────────────
            Center(
              child: Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(logoSize * 0.26),
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFFF6B35), Color(0xFF4FC3F7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withAlpha(70),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  LucideIcons.thermometer,
                  color: Colors.white,
                  size: logoSize * 0.45,
                ),
              ),
            ),

            SizedBox(height: sh * 0.032),

            // ── App name ──────────────────────────────────
            Center(
              child: Text(
                'HeatBubble',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Tagline ───────────────────────────────────
            const Center(
              child: Text(
                'Your Personal Temperature Guardian',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),

            SizedBox(height: sh * 0.06),

            // ── Feature rows ─────────────────────────────
            _FeatureRow(
              icon: LucideIcons.trendingUp,
              iconColor: const Color(0xFFFF6B35),
              title: 'Real-time Tracking',
              subtitle:
                  'Monitor your body temperature continuously with precision sensors',
            ),
            SizedBox(height: sh * 0.028),
            _FeatureRow(
              icon: LucideIcons.thermometer,
              iconColor: const Color(0xFF4FC3F7),
              title: 'Smart Alerts',
              subtitle:
                  'Receive instant notifications for temperature anomalies',
            ),
            SizedBox(height: sh * 0.028),
            _FeatureRow(
              icon: LucideIcons.shieldCheck,
              iconColor: const Color(0xFF9CA3AF),
              title: 'Health Insights',
              subtitle:
                  'Analyze trends and patterns with intelligent health reports',
            ),

            const Spacer(),

            // ── Get Started button ────────────────────────
            SizedBox(
              width: double.infinity,
              height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C55)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () => _onGetStarted(context),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(LucideIcons.arrowRight,
                          color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: sh * 0.04),
          ],
        ),
      ),
    );
  }
}

// ── Feature row ──────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF111118),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1A1A26), width: 1),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
