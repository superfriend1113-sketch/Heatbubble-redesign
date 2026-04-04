import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  // ── Google Test AdMob Ad Unit IDs (work on all devices) ───────────────────
  // These are official Google test IDs that always return test ads
  // Banner Test ID:
  static const String _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  // Interstitial Test ID:
  static const String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  // App Open Test ID:
  static const String _appOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';
  
  // TODO: For production, replace with your real AdMob IDs:
  // App ID (AndroidManifest.xml): ca-app-pub-3676471973768636~4261706101
  // Banner ID: ca-app-pub-3676471973768636/2948624436
  // Interstitial ID: ca-app-pub-3676471973768636/XXXXXXXXXX
  // App Open ID: ca-app-pub-3676471973768636/XXXXXXXXXX

  // ── Internal state ─────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  
  bool _isAdLoaded   = false;
  bool _isInitialized = false;
  bool _isLoading    = false;   // guard: prevents concurrent load calls
  int  _swipeAwayCount = 0;
  int  _loadAttempts = 0;
  String? _lastError;
  
  // Session tracking for one-time ads
  bool _interstitialShownThisSession = false;
  bool _appOpenShownThisSession = false;
  
  // Per-screen tracking for interstitial ads
  final Set<String> _interstitialShownScreens = {};

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
    debugPrint('   - Interstitial Unit: $_interstitialAdUnitId');
    debugPrint('   - App Open Unit: $_appOpenAdUnitId');
    debugPrint('═══════════════════════════════════════════════════════');
    _isInitialized = true;
    
    // Preload interstitial and app open ads
    loadInterstitialAd();
    loadAppOpenAd();
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

  // ── Interstitial Ad (once per session) ────────────────────────────────────

  /// Load interstitial ad (call this early, like in init)
  Future<void> loadInterstitialAd() async {
    if (_interstitialAd != null) {
      debugPrint('⚠️  [AdsService] Interstitial already loaded');
      return;
    }

    debugPrint('🎬 [AdsService] Loading interstitial ad...');
    
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('✅ [AdsService] Interstitial ad loaded');
            _interstitialAd = ad;
            
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('👋 [AdsService] Interstitial dismissed');
                ad.dispose();
                _interstitialAd = null;
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('❌ [AdsService] Interstitial failed to show: $error');
                ad.dispose();
                _interstitialAd = null;
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ [AdsService] Interstitial failed to load: $error');
            _interstitialAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('💥 [AdsService] Interstitial exception: $e');
    }
  }

  /// Show interstitial ad (only once per session)
  Future<void> showInterstitialAd() async {
    if (_interstitialShownThisSession) {
      debugPrint('⚠️  [AdsService] Interstitial already shown this session');
      return;
    }

    if (_interstitialAd == null) {
      debugPrint('⚠️  [AdsService] Interstitial not loaded, loading now...');
      await loadInterstitialAd();
      // Wait a moment for it to load
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_interstitialAd != null) {
      debugPrint('🎬 [AdsService] Showing interstitial ad');
      _interstitialShownThisSession = true;
      await _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      debugPrint('⚠️  [AdsService] Interstitial still not ready');
    }
  }

  /// Show interstitial ad per screen (once per screen per session)
  /// [screenId] should be unique per screen (e.g., 'home', 'settings')
  Future<void> showInterstitialAdForScreen(String screenId) async {
    if (_interstitialShownScreens.contains(screenId)) {
      debugPrint('⚠️  [AdsService] Interstitial already shown for screen: $screenId');
      return;
    }

    debugPrint('🎬 [AdsService] Attempting to show interstitial for screen: $screenId');

    if (_interstitialAd == null) {
      debugPrint('⚠️  [AdsService] Interstitial not loaded, loading now...');
      await loadInterstitialAd();
      // Wait a moment for it to load
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_interstitialAd != null) {
      debugPrint('✅ [AdsService] Showing interstitial ad for screen: $screenId');
      _interstitialShownScreens.add(screenId);
      await _interstitialAd!.show();
      _interstitialAd = null;
      
      // Preload next ad
      loadInterstitialAd();
    } else {
      debugPrint('⚠️  [AdsService] Interstitial still not ready for screen: $screenId');
    }
  }

  // ── App Open Ad (once per session) ────────────────────────────────────────

  /// Load app open ad
  Future<void> loadAppOpenAd() async {
    if (_appOpenAd != null) {
      debugPrint('⚠️  [AdsService] App open ad already loaded');
      return;
    }

    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🚀 [AdsService] Loading app open ad...');
    debugPrint('   - Ad Unit ID: $_appOpenAdUnitId');
    
    try {
      await AppOpenAd.load(
        adUnitId: _appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('✅ [AdsService] App open ad loaded successfully');
            _appOpenAd = ad;
            
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                debugPrint('👁️  [AdsService] App open ad showed full screen');
              },
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('👋 [AdsService] App open ad dismissed by user');
                ad.dispose();
                _appOpenAd = null;
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('❌ [AdsService] App open ad failed to show: $error');
                ad.dispose();
                _appOpenAd = null;
              },
              onAdImpression: (ad) {
                debugPrint('💰 [AdsService] App open ad impression recorded');
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ [AdsService] App open ad failed to load');
            debugPrint('   - Error Code: ${error.code}');
            debugPrint('   - Error Domain: ${error.domain}');
            debugPrint('   - Error Message: ${error.message}');
            _appOpenAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('💥 [AdsService] App open ad exception: $e');
      _appOpenAd = null;
    }
    debugPrint('═══════════════════════════════════════════════════════');
  }

  /// Show app open ad (only once per session)
  Future<void> showAppOpenAd() async {
    if (_appOpenShownThisSession) {
      debugPrint('⚠️  [AdsService] App open ad already shown this session');
      return;
    }

    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🚀 [AdsService] Attempting to show app open ad...');
    debugPrint('   - Ad loaded: ${_appOpenAd != null}');
    
    // If not loaded, try to load it
    if (_appOpenAd == null) {
      debugPrint('   - App open ad not loaded, loading now...');
      await loadAppOpenAd();
      
      // Wait up to 8 seconds for it to load (more time for slow networks)
      int attempts = 0;
      while (_appOpenAd == null && attempts < 16) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        if (attempts % 4 == 0) {
          debugPrint('   - Still waiting for app open ad... ${attempts * 500}ms elapsed');
        }
      }
    }

    if (_appOpenAd != null) {
      debugPrint('✅ [AdsService] App open ad ready, showing now...');
      _appOpenShownThisSession = true;
      await _appOpenAd!.show();
      _appOpenAd = null;
      debugPrint('✅ [AdsService] App open ad shown successfully');
    } else {
      debugPrint('❌ [AdsService] App open ad still not ready after 8 seconds');
      debugPrint('   - Possible reasons:');
      debugPrint('     • Slow network connection');
      debugPrint('     • AdMob server issues');
      debugPrint('     • No ad inventory available');
    }
    debugPrint('═══════════════════════════════════════════════════════');
  }

  /// Reset session flags (call this if you want to allow ads again in same session)
  void resetSession() {
    _interstitialShownThisSession = false;
    _appOpenShownThisSession = false;
    _interstitialShownScreens.clear();
    debugPrint('🔄 [AdsService] Session reset - ads can show again');
  }

  /// Force reload all ads (useful for debugging)
  void forceReloadAllAds() {
    debugPrint('🔄 [AdsService] Force reloading all ads...');
    resetSession();
    disposeBannerAd();
    loadBannerAd();
    loadInterstitialAd();
    loadAppOpenAd();
  }

  /// Get detailed ad status for debugging
  Map<String, dynamic> getAdStatus() {
    return {
      'isInitialized': _isInitialized,
      'bannerLoaded': _isAdLoaded,
      'bannerLoading': _isLoading,
      'interstitialLoaded': _interstitialAd != null,
      'appOpenLoaded': _appOpenAd != null,
      'interstitialShownThisSession': _interstitialShownThisSession,
      'appOpenShownThisSession': _appOpenShownThisSession,
      'interstitialShownScreens': _interstitialShownScreens.toList(),
      'lastError': _lastError,
      'loadAttempts': _loadAttempts,
    };
  }
}
