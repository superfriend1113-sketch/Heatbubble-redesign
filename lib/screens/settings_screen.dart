import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/sensor_service.dart';
import '../services/unit_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsOn = true;
  bool _darkMode = true;
  bool _hasCustomCalibration = false;
  final _sensor = SensorService();

  @override
  void initState() {
    super.initState();
    _sensor.hasCustomCalibration().then((v) {
      if (mounted) setState(() => _hasCustomCalibration = v);
    });
  }

  Future<void> _openCalibrationDialog() async {
    // Take a fresh raw reading
    final result = await _sensor.getCurrentTemp(samples: 3);
    if (!mounted) return;

    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Calibrate Temperature',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current raw reading: ${result.raw.toStringAsFixed(1)}°C\n\nPlace a real thermometer near your phone (not charging, idle for 5 min), then enter its reading below.',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 36.5',
                hintStyle: const TextStyle(color: Color(0xFF4A4A5A)),
                suffixText: '°C',
                suffixStyle: const TextStyle(color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFF1A1A26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () async {
              final actual = double.tryParse(controller.text.trim());
              if (actual == null || actual < 30 || actual > 45) return;
              final offset = actual - result.raw;
              await _sensor.saveCalibrationOffset(offset);
              if (mounted) setState(() => _hasCustomCalibration = true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final topPad = mq.padding.top;
    final hPad = (sw * 0.06).clamp(18.0, 28.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, topPad + 24, hPad, 32),
        children: [
          // ── Title ──
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 24),

          // ── User card ──
          _buildUserCard(),

          const SizedBox(height: 28),

          // ── ACCOUNT ──
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: LucideIcons.userRound,
            iconColor: const Color(0xFFFF6B35),
            title: 'Profile',
            subtitle: 'Manage your personal information',
            trailing: _chevron(),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: LucideIcons.lockKeyhole,
            iconColor: const Color(0xFF4FC3F7),
            title: 'Privacy & Security',
            subtitle: 'Control your data and privacy',
            trailing: _chevron(),
          ),

          const SizedBox(height: 28),

          // ── PREFERENCES ──
          _sectionLabel('PREFERENCES'),

          const SizedBox(height: 12),

          // ── Temperature Unit — inline segmented toggle ──
          ListenableBuilder(
            listenable: UnitService.instance,
            builder: (context, _) {
              final us = UnitService.instance;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F17),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1A1A26), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withAlpha(22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.thermometer,
                          color: Color(0xFFFF6B35), size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Temperature Unit',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(us.unitName,
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 13)),
                        ],
                      ),
                    ),
                    // ── °C / °F segmented pill ──
                    Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _UnitSegment(
                            label: '°C',
                            selected: us.isCelsius,
                            onTap: () => us.setUnit(TempUnit.celsius),
                          ),
                          _UnitSegment(
                            label: '°F',
                            selected: us.isFahrenheit,
                            onTap: () => us.setUnit(TempUnit.fahrenheit),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: LucideIcons.bell,
            iconColor: const Color(0xFFFF6B35),
            title: 'Notifications',
            subtitle: 'Manage alerts and reminders',
            trailing: _toggle(_notificationsOn, (v) {
              setState(() => _notificationsOn = v);
            }),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: LucideIcons.moon,
            iconColor: const Color(0xFF4FC3F7),
            title: 'Dark Mode',
            subtitle: 'Always on',
            trailing: _toggle(_darkMode, (v) {
              setState(() => _darkMode = v);
            }),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: LucideIcons.globe,
            iconColor: const Color(0xFF4FC3F7),
            title: 'Language',
            subtitle: 'English (US)',
            trailing: _chevron(),
          ),

          const SizedBox(height: 28),

          // ── HEALTH ──
          _sectionLabel('HEALTH'),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: LucideIcons.heart,
            iconColor: const Color(0xFFFF6B35),
            title: 'Health Goals',
            subtitle: 'Set your health targets',
            trailing: _chevron(),
          ),

          const SizedBox(height: 48),

          // ── Footer ──
          const Center(
            child: Column(
              children: [
                Text(
                  'HeatBubble v1.0.0',
                  style: TextStyle(
                    color: Color(0xFF4A4A5A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '© 2026 All rights reserved',
                  style: TextStyle(
                    color: Color(0xFF2E2E3A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── User card ───────────────────────────────────────
  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F17),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1A1A26), width: 1),
      ),
      child: Row(
        children: [
          // Avatar — same peach gradient as profile screen
          Container(
            width: 52,
            height: 52,
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
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'JD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'John Doe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'john.doe@email.com',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            color: Color(0xFF4A4A5A),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _chevron() => const Icon(
        LucideIcons.chevronRight,
        color: Color(0xFF4A4A5A),
        size: 20,
      );

  Widget _toggle(bool value, ValueChanged<bool> onChanged) {
    return Transform.scale(
      scale: 0.85,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: const Color(0xFFFF6B35),
        inactiveThumbColor: const Color(0xFF6B7280),
        inactiveTrackColor: const Color(0xFF1A1A26),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

// ── Single settings tile ────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A1A26), width: 1),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
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
          trailing,
        ],
      ),
    );
  }
}

// ── °C / °F segmented pill tab ─────────────────────
class _UnitSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnitSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B35) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
