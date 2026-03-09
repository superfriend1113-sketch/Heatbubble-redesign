import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/ai_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/get_started_screen.dart';

class HeatBubbleApp extends StatelessWidget {
  const HeatBubbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final interFamily = GoogleFonts.inter().fontFamily!;

    return MaterialApp(
      title: 'HeatBubble',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFF6B35),
          secondary: Color(0xFF4FC3F7),
          surface: Colors.transparent,
          onSurface: Color(0xFF111827),
        ),
        fontFamily: interFamily,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
    );
  }
}

/// Checks SharedPreferences to decide first-launch vs returning user
class _SplashRouter extends StatelessWidget {
  const _SplashRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance()
          .then((p) => p.getBool('onboarded') ?? false),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFFF8E53),
            body: SizedBox.shrink(),
          );
        }
        return snap.data! ? const AppShell() : const GetStartedScreen();
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    AiScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      // ── Warm gradient background matching Figma ──
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF6B6B), // coral red
            Color(0xFFFF8E53), // warm orange
            Color(0xFFFFB366), // golden peach
            Color(0xFFD4A8C8), // soft mauve
            Color(0xFFB8A9D4), // lavender
            Color(0xFF8BA4D0), // periwinkle blue
          ],
          stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // ── Human silhouette (subtle, centered) ──
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  Icons.accessibility_new_rounded,
                  size: MediaQuery.of(context).size.height * 0.5,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ),
          // ── Scaffold: body is a Column (screen + nav bar) ──
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                // ── All screen content fills the remaining space ──
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
                // ── Nav bar: glassmorphic frosted surface ──
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(55),
                        border: const Border(
                          top: BorderSide(color: Color(0x33FFFFFF), width: 0.8),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 8,
                          bottom: bottomPadding + 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _NavItem(
                              icon: LucideIcons.house,
                              label: 'Home',
                              isActive: _currentIndex == 0,
                              onTap: () => setState(() => _currentIndex = 0),
                            ),
                            _NavItem(
                              icon: LucideIcons.chartNoAxesCombined,
                              label: 'History',
                              isActive: _currentIndex == 1,
                              onTap: () => setState(() => _currentIndex = 1),
                            ),
                            _NavItem(
                              icon: LucideIcons.brain,
                              label: 'AI',
                              isActive: _currentIndex == 2,
                              onTap: () => setState(() => _currentIndex = 2),
                            ),
                            _NavItem(
                              icon: LucideIcons.settings,
                              label: 'Settings',
                              isActive: _currentIndex == 3,
                              onTap: () => setState(() => _currentIndex = 3),
                            ),
                          ],
                        ),
                      ),
                    ),
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


class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Active: dark rounded square around icon only ──
            // ── Inactive: no background ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF111827) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : const Color(0xFF6B7280),
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            // Label always below the icon/pill
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF111827) : const Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

