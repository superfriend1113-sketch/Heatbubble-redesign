import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/unit_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoDetectSensors = true;
  bool _batteryFallback = true;

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
                    onChanged: (v) => setState(() => _autoDetectSensors = v),
                  ),
                  const SizedBox(height: 8),
                  _toggleRow(
                    title: 'Battery fallback',
                    subtitle: 'Use battery temp when needed',
                    value: _batteryFallback,
                    onChanged: (v) => setState(() => _batteryFallback = v),
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
      onTap: () => us.setUnit(unit),
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

  Widget _unitOptionDisabled({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF111827).withAlpha(130),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: const Color(0xFF6B7280).withAlpha(130),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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
          activeColor: const Color(0xFFFF6B35),
          activeTrackColor: const Color(0xFF111827),
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
}
