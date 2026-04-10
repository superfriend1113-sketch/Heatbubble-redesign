import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'firebase_auth_service.dart';
import 'firebase_firestore_service.dart';
import 'home_widget_service.dart';
import 'storage_service.dart';
import 'unit_service.dart';

/// Manages the HeatBubble subscription state.
///
/// Subscription model:
///   • Monthly  — $1.99/month  — auto-renews monthly
///   • Annual   — $19.99/year  — auto-renews every 12 months
///   Both plans include a **7-day free trial** for first-time subscribers
///   (enforced by Google Play; no code change needed).
class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase iap = InAppPurchase.instance;
  final _auth      = FirebaseAuthService();
  final _firestore = FirebaseFirestoreService();
  final _homeWidget = HomeWidgetService();
  final _storage = StorageService();

  bool _isPremium = false;
  List<ProductDetails> _products = [];
  StreamSubscription<DocumentSnapshot>? _subscriptionListener;

  // ── Product IDs (must match Play Console exactly) ──────────────────────
  static const String monthlySubscriptionId = 'heatbubble_premium_monthly'; // $1.99/mo
  static const String annualSubscriptionId  = 'heatbubble_premium_annual';  // $19.99/yr

  static const Set<String> _allProductIds = {
    monthlySubscriptionId,
    annualSubscriptionId,
  };

  // ── Expiry durations ────────────────────────────────────────────────────
  static const Duration _monthlyDuration = Duration(days: 31);
  static const Duration _annualDuration  = Duration(days: 366);

  // ── SharedPreferences keys ──────────────────────────────────────────────
  static const String _premiumKey      = 'is_premium';
  static const String _purchaseDateKey = 'premium_purchase_date';
  static const String _productIdKey    = 'premium_product_id';
  static const String _expiryKey       = 'premium_expiry_date';

  bool get isPremium => _isPremium;
  List<ProductDetails> get products => _products;

  ProductDetails? get monthlyProduct =>
      _products.where((p) => p.id == monthlySubscriptionId).firstOrNull;

  ProductDetails? get annualProduct =>
      _products.where((p) => p.id == annualSubscriptionId).firstOrNull;

  // ── Initialise ──────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadPremiumStatus();
    await _initializeProducts();
    
    // Listen to subscription changes in real-time
    if (_auth.isSignedIn) {
      _listenToSubscriptionChanges();
    }
  }

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumKey) ?? false;

    // Validate locally-cached expiry (belt-and-suspenders; Play handles renewal)
    final expiryStr = prefs.getString(_expiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        _isPremium = false;
        await prefs.setBool(_premiumKey, false);
      }
    }
  }

  Future<void> _initializeProducts() async {
    
    final bool available = await iap.isAvailable();
    
    if (!available) {
      return;
    }

    try {
      final ProductDetailsResponse response =
          await iap.queryProductDetails(_allProductIds);
      
      // Filter out "Free" trial entries - keep only products with actual prices
      _products = response.productDetails.where((product) {
        return !product.price.toLowerCase().contains('free') && 
               product.price.isNotEmpty &&
               product.price != '0';
      }).toList();
      
      
      for (var product in _products) {
      }
      
      if (response.notFoundIDs.isNotEmpty) {
        for (var id in response.notFoundIDs) {
        }
      }
      
    } catch (e) {
    }
  }

  // ── Purchase methods ────────────────────────────────────────────────────

  /// Start the monthly subscription flow ($1.99/month, 7-day trial for new users).
  Future<bool> purchaseMonthly() async => _startSubscription(monthlySubscriptionId);

  /// Start the annual subscription flow ($19.99/year, 7-day trial for new users).
  Future<bool> purchaseAnnual() async => _startSubscription(annualSubscriptionId);

  Future<bool> _startSubscription(String productId) async {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      return false;
    }
    try {
      // Pass Firebase UID as obfuscatedAccountId so backend can link purchase to user
      final String? userId = _auth.isSignedIn ? _auth.currentUser?.uid : null;
      
      final PurchaseParam param = PurchaseParam(
        productDetails: product,
        applicationUserName: userId, // This becomes obfuscatedExternalAccountId
      );
      
      await iap.buyNonConsumable(purchaseParam: param);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Premium status management ───────────────────────────────────────────

  /// Called when a purchase is verified. Sets premium and syncs to Firebase.
  Future<void> setPremium(
    bool value, {
    String? purchaseId,
    String? productId,
  }) async {
    _isPremium = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
    await prefs.setString(_purchaseDateKey, DateTime.now().toIso8601String());

    // Calculate and cache local expiry date
    DateTime? expiry;
    if (value && productId != null) {
      expiry = productId == annualSubscriptionId
          ? DateTime.now().add(_annualDuration)
          : DateTime.now().add(_monthlyDuration);
      await prefs.setString(_expiryKey, expiry.toIso8601String());
      await prefs.setString(_productIdKey, productId);
    } else if (!value) {
      await prefs.remove(_expiryKey);
      await prefs.remove(_productIdKey);
    }

    // Sync to Firebase if signed in
    if (_auth.isSignedIn) {
      try {
        await _firestore.saveSubscription(
          userId: _auth.currentUser!.uid,
          isPremium: value,
          purchaseId: purchaseId,
          productId: productId,
          expiryDate: expiry,
          purchaseToken: purchaseId, // Save purchase token for backend verification
        );
      } catch (e) {
      }
    }

    // Update home screen widget with new premium status
    await _updateWidget();
    
    // Notify all listeners (UI will update automatically)
    notifyListeners();
  }

  /// Update the home screen widget with current temperature and premium status
  Future<void> _updateWidget() async {
    try {
      final latest = await _storage.getLatest();
      if (latest != null) {
        // Calculate trend from last 24 hours
        final readings = await _storage.getLast24Hours();
        String trend = 'Stable';
        if (readings.length >= 2) {
          final diff = latest.temperature - readings[readings.length - 2].temperature;
          if (diff > 0.3) {
            trend = 'Rising';
          } else if (diff < -0.3) {
            trend = 'Falling';
          }
        }

        await _homeWidget.updateWidget(
          temperature: latest.temperature,
          trend: trend,
          unit: UnitService.instance.unit,
          isPremium: _isPremium,
        );
      }
    } catch (e) {
      // Widget update failed, but don't block premium status change
    }
  }

  // ── Firebase sync ───────────────────────────────────────────────────────

  Future<void> syncFromFirebase() async {
    if (!_auth.isSignedIn) return;

    try {
      final data = await _firestore.getSubscription(_auth.currentUser!.uid);

      if (data != null) {
        final isPremium = data['isPremium'] as bool? ?? false;

        // Check server-side expiry date
        if (data['expiryDate'] != null) {
          final expiryDate = (data['expiryDate'] as dynamic).toDate() as DateTime;
          if (DateTime.now().isAfter(expiryDate)) {
            await setPremium(false);
            return;
          }
        }

        _isPremium = isPremium;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_premiumKey, isPremium);

        // Update widget with synced premium status
        await _updateWidget();
        
        // Notify all listeners (UI updates automatically)
        notifyListeners();
      }
    } catch (e) {
    }
  }

  // ── Restore & validate ──────────────────────────────────────────────────

  /// Restores purchases — use when user reinstalls or switches device.
  Future<bool> restorePurchases() async {
    
    try {
      // Restore purchases triggers Google Play to refresh purchase state
      await iap.restorePurchases();
      
      // Reload premium status from local storage
      await _loadPremiumStatus();

      // Update widget with restored premium status
      await _updateWidget();
      
      return _isPremium;
      
    } catch (e) {
      return false;
    }
  }

  Future<bool> validatePremium() async => _isPremium;

  Future<String?> getPurchaseDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_purchaseDateKey);
  }

  /// Returns which plan the user is on, or null if not subscribed.
  Future<String?> getActivePlanId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_productIdKey);
  }

  // ── Real-time subscription listener ────────────────────────────────────

  /// Listen to subscription changes in Firestore in real-time
  /// This allows instant updates when backend changes subscription status
  void _listenToSubscriptionChanges() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _subscriptionListener?.cancel(); // Cancel existing listener if any

    _subscriptionListener = _firestore.subscriptions
        ?.doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final isPremium = data['isPremium'] as bool? ?? false;
        final status = data['status'] as String? ?? 'inactive';

        // Update local state if changed
        if (_isPremium != isPremium) {
          _isPremium = isPremium;
          _savePremiumStatus(isPremium);
          _updateWidget();
          notifyListeners();

          // Show message to user based on status
          if (!isPremium) {
            if (status == 'expired') {
              print('⚠️ Your subscription has expired');
            } else if (status == 'cancelled') {
              print('⚠️ Your subscription was cancelled');
            } else if (status == 'paused') {
              print('⚠️ Your subscription is paused');
            }
          }
        }

        // Update status even if premium status hasn't changed
        if (status == 'cancelled' && isPremium) {
          print('⚠️ Your subscription is cancelled but still active until expiry');
        } else if (status == 'grace_period' && isPremium) {
          print('⚠️ Payment issue - subscription in grace period');
        } else if (status == 'on_hold' && isPremium) {
          print('⚠️ Payment issue - subscription on hold');
        }
      }
    }, onError: (error) {
      print('Error listening to subscription changes: $error');
    });
  }

  Future<void> _savePremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, isPremium);
  }

  /// Start listening to subscription changes (call after sign-in)
  void startListening() {
    if (_auth.isSignedIn) {
      _listenToSubscriptionChanges();
    }
  }

  /// Stop listening to subscription changes (call on sign-out)
  void stopListening() {
    _subscriptionListener?.cancel();
    _subscriptionListener = null;
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    super.dispose();
  }
}
