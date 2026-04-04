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
    
    
    if (_isAdLoaded) {
      return;
    }
    
    if (_isLoading) {
      return;
    }
    
    if (!_isInitialized) {
      await init();
    }

    _isLoading = true;

    // Dispose any stale ad first
    if (_bannerAd != null) {
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
            _isAdLoaded = true;
            _isLoading  = false;
            _lastError = null;
            onAdStateChanged?.call();
          },
          onAdFailedToLoad: (ad, error) {
            
            // Detailed error analysis
            final isJsError = error.message.contains('JavascriptEngine');
            final isWebViewError = error.message.contains('WebView');
            
            if (isJsError || isWebViewError) {
            }
            
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
              Future.delayed(const Duration(seconds: 5), () => loadBannerAd(retry: false));
            } else if (error.code == 3) {
            } else if (error.code == 1) {
            } else if (error.code == 0 && !isJsError && !isWebViewError) {
            }
          },
          onAdOpened: (ad) {
          },
          onAdClosed: (ad) {
          },
          onAdImpression: (ad) {
          },
          onAdWillDismissScreen: (ad) {
          },
          onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          },
        ),
      );

      await _bannerAd!.load();
      
    } catch (e, stackTrace) {
      _isLoading = false;
      _lastError = 'Exception: $e';
      onAdStateChanged?.call();
    }
  }

  /// Dispose the current banner ad and reset state.
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd   = null;
    _isAdLoaded = false;
    _isLoading  = false;
    onAdStateChanged?.call();
  }

  void trackSwipeAway() {
    _swipeAwayCount++;
  }

  /// Returns the ready-to-use AdWidget, or null if not loaded yet.
  Widget? getBannerAdWidget() {
    if (!_isAdLoaded || _bannerAd == null) {
      return null;
    }
    
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
      return;
    }

    
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitialAd = null;
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _interstitialAd = null;
              },
            );
          },
          onAdFailedToLoad: (error) {
            _interstitialAd = null;
          },
        ),
      );
    } catch (e) {
    }
  }

  /// Show interstitial ad (only once per session)
  Future<void> showInterstitialAd() async {
    if (_interstitialShownThisSession) {
      return;
    }

    if (_interstitialAd == null) {
      await loadInterstitialAd();
      // Wait a moment for it to load
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_interstitialAd != null) {
      _interstitialShownThisSession = true;
      await _interstitialAd!.show();
      _interstitialAd = null;
    } else {
    }
  }

  /// Show interstitial ad per screen (once per screen per session)
  /// [screenId] should be unique per screen (e.g., 'home', 'settings')
  Future<void> showInterstitialAdForScreen(String screenId) async {
    if (_interstitialShownScreens.contains(screenId)) {
      return;
    }


    if (_interstitialAd == null) {
      await loadInterstitialAd();
      // Wait a moment for it to load
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_interstitialAd != null) {
      _interstitialShownScreens.add(screenId);
      await _interstitialAd!.show();
      _interstitialAd = null;
      
      // Preload next ad
      loadInterstitialAd();
    } else {
    }
  }

  // ── App Open Ad (once per session) ────────────────────────────────────────

  /// Load app open ad
  Future<void> loadAppOpenAd() async {
    if (_appOpenAd != null) {
      return;
    }

    
    try {
      await AppOpenAd.load(
        adUnitId: _appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _appOpenAd = null;
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _appOpenAd = null;
              },
              onAdImpression: (ad) {
              },
            );
          },
          onAdFailedToLoad: (error) {
            _appOpenAd = null;
          },
        ),
      );
    } catch (e) {
      _appOpenAd = null;
    }
  }

  /// Show app open ad (only once per session)
  Future<void> showAppOpenAd() async {
    if (_appOpenShownThisSession) {
      return;
    }

    
    // If not loaded, try to load it
    if (_appOpenAd == null) {
      await loadAppOpenAd();
      
      // Wait up to 8 seconds for it to load (more time for slow networks)
      int attempts = 0;
      while (_appOpenAd == null && attempts < 16) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        if (attempts % 4 == 0) {
        }
      }
    }

    if (_appOpenAd != null) {
      _appOpenShownThisSession = true;
      await _appOpenAd!.show();
      _appOpenAd = null;
    } else {
    }
  }

  /// Reset session flags (call this if you want to allow ads again in same session)
  void resetSession() {
    _interstitialShownThisSession = false;
    _appOpenShownThisSession = false;
    _interstitialShownScreens.clear();
  }
}
