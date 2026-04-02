import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'services/nudge_service.dart';
import 'services/background_service.dart';
import 'services/unit_service.dart';
import 'services/firebase_init_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/subscription_service.dart';
import 'services/home_widget_service.dart';
import 'services/ads_service.dart';
import 'screens/onboarding_screen.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── ONLY CRITICAL BLOCKING OPERATIONS ──
  // Check if onboarding has been completed (fast, local read)
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  // Set system UI styles (synchronous, instant)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize timezone database (synchronous, fast)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/New_York'));

  // ── LAUNCH APP IMMEDIATELY ──
  runApp(HeatBubbleApp(showOnboarding: !onboardingCompleted));

  // ── ALL OTHER INITIALIZATION HAPPENS IN BACKGROUND ──
  _initializeInBackground();
}

/// Initialize all non-critical services in the background after app launch
void _initializeInBackground() {
  Future.microtask(() async {
    debugPrint('🚀 [Init] Starting background initialization...');
    
    try {
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
        // Initialize home screen widget
        HomeWidgetService.init(),
      ]);
      
      debugPrint('✅ [Init] Core services initialized');
      
      // Initialize Firebase (optional - won't block if not configured)
      try {
        await FirebaseInitService().initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️  [Init] Firebase initialization timed out after 5s');
            throw TimeoutException('Firebase init timeout');
          },
        );
        
        // Sync subscription status from Firebase if user is logged in
        await _syncSubscriptionFromFirebase().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('⚠️  [Init] Firebase sync timed out after 3s');
          },
        );
      } catch (e) {
        debugPrint('⚠️  [Init] Firebase not configured yet: $e');
        debugPrint('   App will work without Firebase features');
      }

      // Schedule daily reminder
      await NudgeService().scheduleDailyReminder();
      debugPrint('✅ [Init] All background initialization complete');
      
      // Show app open ad AFTER everything is initialized (once per session, for free users)
      await _showAppOpenAdIfNeeded();
      
    } catch (e, stackTrace) {
      debugPrint('❌ [Init] Background initialization error: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
  });
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

/// Show app open ad for free users (once per session)
Future<void> _showAppOpenAdIfNeeded() async {
  try {
    final subscription = SubscriptionService();
    final ads = AdsService();
    
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🚀 [Init] Checking if app open ad should show...');
    debugPrint('   - isPremium: ${subscription.isPremium}');
    
    // Only show for free users
    if (!subscription.isPremium) {
      // Wait 2 seconds for app to settle and UI to be ready
      debugPrint('   - Waiting 2 seconds for app to settle...');
      await Future.delayed(const Duration(seconds: 2));
      
      debugPrint('   - Attempting to show app open ad...');
      await ads.showAppOpenAd();
      debugPrint('   - App open ad flow completed');
    } else {
      debugPrint('   - User is premium, skipping app open ad');
    }
    debugPrint('═══════════════════════════════════════════════════════');
  } catch (e) {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('⚠️  [Init] Failed to show app open ad: $e');
    debugPrint('═══════════════════════════════════════════════════════');
  }
}

/// Initialize background work manager
Future<void> _initializeBackgroundWork() async {
  await Workmanager().initialize(callbackDispatcher);
  initBackgroundPolling();
}

/// Sync subscription status from Firebase if user is logged in
Future<void> _syncSubscriptionFromFirebase() async {
  try {
    final auth = FirebaseAuthService();
    final subscription = SubscriptionService();
    
    if (auth.isSignedIn) {
      debugPrint('🔄 [Init] User is logged in, syncing subscription from Firebase');
      await subscription.syncFromFirebase();
    } else {
      debugPrint('ℹ️  [Init] User not logged in, using local subscription status');
    }
  } catch (e) {
    debugPrint('⚠️  [Init] Failed to sync subscription: $e');
    // Continue even if sync fails - use local data
  }
}
