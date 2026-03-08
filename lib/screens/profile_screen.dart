import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/storage_service.dart';
import '../services/unit_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = StorageService();

  int _daysTracked = 0;
  double _avgTemp = 0;
  int _streak = 0;
  int _achievements = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final days = await _storage.getUniqueDaysCount();
    final avg = await _storage.getSevenDayAverage();
    final streak = await _storage.getCurrentStreak();

    // Achievements unlocked based on milestones
    int ach = 0;
    if (days >= 1) ach++;
    if (days >= 7) ach++;
    if (days >= 30) ach++;
    if (streak >= 7) ach++;
    if (avg > 0) ach++;

    if (mounted) {
      setState(() {
        _daysTracked = days;
        _avgTemp = avg;
        _streak = streak;
        _achievements = ach;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final hPad = (sw * 0.06).clamp(18.0, 28.0);
    final topPad = mq.padding.top;

    // Responsive sizing
    final avatarSize = (sw * 0.26).clamp(90.0, 120.0);
    final avatarFontSize = avatarSize * 0.3;
    final nameFontSize = (sw * 0.065).clamp(22.0, 28.0);
    final topGap = (sh * 0.04).clamp(24.0, 40.0);
    final gridGap = (sh * 0.032).clamp(20.0, 36.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: ListenableBuilder(
        listenable: UnitService.instance,
        builder: (context, _) => _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(hPad, topPad + topGap, hPad, 32),

              children: [
                // ── Avatar ──
                Center(
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFFD0887A), Color(0xFF8AAEC8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD0887A).withAlpha(50),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'JD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: avatarFontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: (sh * 0.022).clamp(14.0, 22.0)),

                // ── Name ──
                Text(
                  'John Doe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 6),

                // ── Member since ──
                const Text(
                  'Member since Dec 2025',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                SizedBox(height: gridGap),

                // ── 2×2 Stats grid ──
                _buildGrid(sw, sh),

                const SizedBox(height: 32),
              ],
            ),         // closes ListView
        ),             // closes ListenableBuilder
    );
  }

  Widget _buildGrid(double sw, double sh) {
    // Card height: ~38% of screen width (each card is ~half-screen wide)
    final cardH = ((sw - 48) / 2 * 0.85).clamp(130.0, 180.0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: LucideIcons.calendarDays,
                iconColor: const Color(0xFFFF6B35),
                value: '$_daysTracked',
                label: 'Days Tracked',
                height: cardH,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.trendingUp,
                iconColor: const Color(0xFFFF6B35),
                value: _avgTemp > 0
                    ? UnitService.instance.format(_avgTemp)
                    : '--',
                label: 'Avg Temp',
                height: cardH,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: LucideIcons.target,
                iconColor: const Color(0xFFFF6B35),
                value: '$_streak Days',
                label: 'Streak',
                height: cardH,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.award,
                iconColor: const Color(0xFF4FC3F7),
                value: '$_achievements',
                label: 'Achievements',
                height: cardH,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


// ── Stat card ──────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final double height;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final valueFontSize = (sw * 0.065).clamp(22.0, 30.0);

    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A1A26), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon top-left
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const Spacer(),
          // Value
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
