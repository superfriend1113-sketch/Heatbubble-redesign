import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final topPad = mq.padding.top;
    final hPad = (sw * 0.06).clamp(18.0, 28.0);
    final titleSize = (sw * 0.065).clamp(22.0, 28.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, topPad + 24, hPad, 32),
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Stay updated with your health alerts',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          _NotificationCard(
            icon: LucideIcons.triangleAlert,
            iconBgColor: const Color(0xFFFF6B35).withAlpha(38),
            iconColor: const Color(0xFFFF6B35),
            title: 'Temperature Alert',
            description:
                'Your body temperature has been elevated for 15 minutes',
            timeAgo: '2m ago',
          ),
          _NotificationCard(
            icon: LucideIcons.chartBar,
            iconBgColor: const Color(0xFF6B7280).withAlpha(38),
            iconColor: const Color(0xFF9CA3AF),
            title: 'Weekly Summary',
            description: 'Your average temperature this week: 36.5°C',
            timeAgo: '1h ago',
          ),
          _NotificationCard(
            icon: LucideIcons.circleCheck,
            iconBgColor: const Color(0xFF4ADE80).withAlpha(38),
            iconColor: const Color(0xFF4ADE80),
            title: 'Back to Normal',
            description: 'Your temperature has returned to normal range',
            timeAgo: '3h ago',
          ),
          _NotificationCard(
            icon: LucideIcons.clock,
            iconBgColor: const Color(0xFF6B7280).withAlpha(38),
            iconColor: const Color(0xFF9CA3AF),
            title: 'Daily Reminder',
            description: 'Time to take your temperature measurement',
            timeAgo: '5h ago',
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String description;
  final String timeAgo;

  const _NotificationCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E2E), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
