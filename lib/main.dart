import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/nudge_service.dart';
import 'services/background_service.dart';
import 'services/unit_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reset onboarding to show GetStartedScreen (temporary for testing)
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('onboarded');

  // Set system UI styles synchronously (no await needed)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ── OPTIMIZED: Parallelize independent initialization tasks ──────────────
  // Run all independent async operations concurrently
  await Future.wait([
    // Initialize Mobile Ads SDK
    _initializeMobileAds(),
    // Load persisted temperature unit
    UnitService.instance.load(),
    // Initialize notifications
    NudgeService.init(),
    // Request notification permission (Android 13+)
    Permission.notification.request(),
    // Initialize background polling
    _initializeBackgroundWork(),
  ]);

  runApp(const HeatBubbleApp());
}

/// Initialize Mobile Ads SDK with test device configuration
Future<void> _initializeMobileAds() async {
  debugPrint('═══════════════════════════════════════════════════════');
  debugPrint('[Init] Initializing Mobile Ads SDK...');
  debugPrint('[Init] Platform: ${defaultTargetPlatform.name}');
  debugPrint('═══════════════════════════════════════════════════════');
  
  try {
    // Initialize the Mobile Ads SDK
    final initResult = await MobileAds.instance.initialize();
    
    debugPrint('[Init] ✅ Mobile Ads SDK initialized successfully');
    debugPrint('[Init] Adapter statuses:');
    initResult.adapterStatuses.forEach((key, value) {
      debugPrint('       - $key: ${value.state.name} (${value.description})');
    });
    debugPrint('═══════════════════════════════════════════════════════');
    
  } catch (e, stackTrace) {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('[Init] ❌ ERROR initializing Mobile Ads');
    debugPrint('[Init] Exception: $e');
    debugPrint('[Init] Stack trace: $stackTrace');
    debugPrint('═══════════════════════════════════════════════════════');
  }
}

/// Initialize background work manager
Future<void> _initializeBackgroundWork() async {
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  initBackgroundPolling();
}
