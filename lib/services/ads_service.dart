import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  // ── Production AdMob Ad Unit IDs ───────────────────────────────────────────
  static const String _bannerAdUnitId = 'ca-app-pub-3676471973768636/2948624436';

  // ── Internal state ─────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  bool _isAdLoaded   = false;
  bool _isInitialized = false;
  bool _isLoading    = false;   // guard: prevents concurrent load calls
  int  _swipeAwayCount = 0;
  int  _loadAttempts = 0;
  String? _lastError;

  /// Listener called whenever ad state changes (loaded / failed / disposed).
  /// Widgets should set this to `() { if (mounted) setState(() {}); }`.
  VoidCallback? onAdStateChanged;

  bool get isAdLoaded => _isAdLoaded;
  int  get swipeAwayCount => _swipeAwayCount;
  String? get lastError => _lastError;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Mark SDK as initialized (main.dart calls MobileAds.instance.initialize()).
  Future<void> init() async {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🎯 [AdsService] Initializing ads service');
    debugPrint('   - Using Google test IDs (work on all devices)');
    debugPrint('   - Banner Unit: $_bannerAdUnitId');
    debugPrint('═══════════════════════════════════════════════════════');
    _isInitialized = true;
  }

  /// Load a banner ad.  Safe to call multiple times (no-ops if already loading
  /// or already loaded).  Retries once after 5 s on network failure.
  /// FIXED: Removed timeout that was causing race condition with AdMob callbacks
  Future<void> loadBannerAd({bool retry = true}) async {
    _loadAttempts++;
    
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('📱 [AdsService] Load attempt #$_loadAttempts');
    debugPrint('   - isAdLoaded: $_isAdLoaded');
    debugPrint('   - isLoading: $_isLoading');
    debugPrint('   - isInitialized: $_isInitialized');
    debugPrint('   - retry: $retry');
    debugPrint('═══════════════════════════════════════════════════════');
    
    if (_isAdLoaded) {
      debugPrint('⚠️  [AdsService] Ad already loaded, skipping');
      return;
    }
    
    if (_isLoading) {
      debugPrint('⚠️  [AdsService] Ad already loading, skipping');
      return;
    }
    
    if (!_isInitialized) {
      debugPrint('⚠️  [AdsService] SDK not initialized, initializing now...');
      await init();
    }

    _isLoading = true;
    debugPrint('🔄 [AdsService] Starting ad load...');
    debugPrint('   - Ad Unit ID: $_bannerAdUnitId');
    debugPrint('   - Ad Size: ${AdSize.banner.width}x${AdSize.banner.height}');

    // Dispose any stale ad first
    if (_bannerAd != null) {
      debugPrint('🗑️  [AdsService] Disposing stale ad');
      _bannerAd?.dispose();
      _bannerAd = null;
    }

    try {
      _bannerAd = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('═══════════════════════════════════════════════════════');
            debugPrint('✅ [AdsService] Banner ad LOADED successfully!');
            debugPrint('   - Ad ID: ${ad.adUnitId}');
            debugPrint('   - Response Info: ${ad.responseInfo}');
            debugPrint('═══════════════════════════════════════════════════════');
            _isAdLoaded = true;
            _isLoading  = false;
            _lastError = null;
            onAdStateChanged?.call();
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('═══════════════════════════════════════════════════════');
            debugPrint('❌ [AdsService] Banner ad FAILED to load');
            debugPrint('   - Error Code: ${error.code}');
            debugPrint('   - Error Domain: ${error.domain}');
            debugPrint('   - Error Message: ${error.message}');
            debugPrint('   - Response Info: ${error.responseInfo}');
            debugPrint('   - Ad Unit ID: ${ad.adUnitId}');
            
            // Detailed error analysis
            final isJsError = error.message.contains('JavascriptEngine');
            final isWebViewError = error.message.contains('WebView');
            
            if (isJsError || isWebViewError) {
              debugPrint('');
              debugPrint('🔍 DIAGNOSIS: WebView/JavascriptEngine Error Detected');
              debugPrint('   This usually means Android System WebView is outdated.');
              debugPrint('   SOLUTION: User should update "Android System WebView" from Play Store.');
              debugPrint('   App will show update prompt to user.');
              debugPrint('   NOTE: After WebView update, ads should work normally.');
            }
            debugPrint('═══════════════════════════════════════════════════════');
            
            _lastError = 'Code ${error.code}: ${error.message}';
            ad.dispose();
            _bannerAd   = null;
            _isAdLoaded = false;
            _isLoading  = false;
            onAdStateChanged?.call();

            // Error codes:
            // 0 = INTERNAL_ERROR (includes JavascriptEngine issues)
            // 1 = INVALID_REQUEST
            // 2 = NETWORK_ERROR
            // 3 = NO_FILL
            
            // Retry once after a delay (only for network errors)
            if (retry && error.code == 2) {
              debugPrint('🔄 [AdsService] Network error detected, retrying in 5s...');
              Future.delayed(const Duration(seconds: 5), () => loadBannerAd(retry: false));
            } else if (error.code == 3) {
              debugPrint('⚠️  [AdsService] No ad inventory available (NO_FILL)');
            } else if (error.code == 1) {
              debugPrint('⚠️  [AdsService] Invalid ad request configuration');
            } else if (error.code == 0 && !isJsError && !isWebViewError) {
              debugPrint('⚠️  [AdsService] Internal AdMob error (non-WebView related)');
            }
          },
          onAdOpened: (ad) {
            debugPrint('👆 [AdsService] Banner ad opened (user clicked)');
          },
          onAdClosed: (ad) {
            debugPrint('👋 [AdsService] Banner ad closed');
          },
          onAdImpression: (ad) {
            debugPrint('👁️  [AdsService] Banner ad impression recorded');
          },
          onAdWillDismissScreen: (ad) {
            debugPrint('📱 [AdsService] Ad will dismiss screen');
          },
          onPaidEvent: (ad, valueMicros, precision, currencyCode) {
            debugPrint('💰 [AdsService] Paid event: $valueMicros $currencyCode');
          },
        ),
      );

      debugPrint('🚀 [AdsService] Calling ad.load()...');
      await _bannerAd!.load();
      debugPrint('✓  [AdsService] ad.load() completed, waiting for callback...');
      
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('💥 [AdsService] EXCEPTION during ad load');
      debugPrint('   - Exception: $e');
      debugPrint('   - Stack trace: $stackTrace');
      debugPrint('═══════════════════════════════════════════════════════');
      _isLoading = false;
      _lastError = 'Exception: $e';
      onAdStateChanged?.call();
    }
  }

  /// Dispose the current banner ad and reset state.
  void disposeBannerAd() {
    debugPrint('🗑️  [AdsService] Disposing banner ad');
    _bannerAd?.dispose();
    _bannerAd   = null;
    _isAdLoaded = false;
    _isLoading  = false;
    onAdStateChanged?.call();
  }

  void trackSwipeAway() {
    _swipeAwayCount++;
    debugPrint('👆 [AdsService] User swiped away ad (count: $_swipeAwayCount)');
  }

  /// Returns the ready-to-use AdWidget, or null if not loaded yet.
  Widget? getBannerAdWidget() {
    if (!_isAdLoaded || _bannerAd == null) {
      debugPrint('⚠️  [AdsService] getBannerAdWidget called but ad not ready');
      debugPrint('   - isAdLoaded: $_isAdLoaded');
      debugPrint('   - _bannerAd: ${_bannerAd != null ? "exists" : "null"}');
      debugPrint('   - lastError: $_lastError');
      return null;
    }
    
    debugPrint('✅ [AdsService] Returning ad widget');
    return SizedBox(
      width:  _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child:  AdWidget(ad: _bannerAd!),
    );
  }
}
