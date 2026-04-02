import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'firebase_auth_service.dart';
import 'firebase_firestore_service.dart';

/// Manages the HeatBubble subscription state.
///
/// Subscription model:
///   • Monthly  — $1.99/month  — auto-renews monthly
///   • Annual   — $19.99/year  — auto-renews every 12 months
///   Both plans include a **7-day free trial** for first-time subscribers
///   (enforced by Google Play; no code change needed).
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase iap = InAppPurchase.instance;
  final _auth      = FirebaseAuthService();
  final _firestore = FirebaseFirestoreService();

  bool _isPremium = false;
  List<ProductDetails> _products = [];

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
  }

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumKey) ?? false;

    // Validate locally-cached expiry (belt-and-suspenders; Play handles renewal)
    final expiryStr = prefs.getString(_expiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        debugPrint('⚠️  [Subscription] Local cache expired — resetting premium');
        _isPremium = false;
        await prefs.setBool(_premiumKey, false);
      }
    }
  }

  Future<void> _initializeProducts() async {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🛒 [Subscription] Initializing In-App Products...');
    debugPrint('   Product IDs to query: $_allProductIds');
    
    final bool available = await iap.isAvailable();
    debugPrint('   IAP Available: $available');
    
    if (!available) {
      debugPrint('⚠️  [Subscription] In-App Purchase not available on this device');
      debugPrint('═══════════════════════════════════════════════════════');
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
      
      debugPrint('✅ [Subscription] Query completed');
      debugPrint('   Products found: ${_products.length} (filtered from ${response.productDetails.length})');
      
      for (var product in _products) {
        debugPrint('   ├─ ID: ${product.id}');
        debugPrint('   │  Title: ${product.title}');
        debugPrint('   │  Price: ${product.price}');
        debugPrint('   │  Description: ${product.description}');
      }
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️  [Subscription] Products NOT FOUND in Play Console:');
        for (var id in response.notFoundIDs) {
          debugPrint('   ✗ $id');
        }
        debugPrint('   → Check Play Console: Monetize → Subscriptions');
        debugPrint('   → Ensure products are published (at least to Internal Testing)');
      }
      
      debugPrint('═══════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('❌ [Subscription] Error loading products: $e');
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
      debugPrint('❌ [Subscription] Product not found: $productId');
      return false;
    }
    try {
      // Subscriptions use buyNonConsumable (they are not consumed)
      final PurchaseParam param = PurchaseParam(productDetails: product);
      await iap.buyNonConsumable(purchaseParam: param);
      return true;
    } catch (e) {
      debugPrint('❌ [Subscription] Purchase error: $e');
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
        );
        debugPrint('✅ [Subscription] Synced to Firebase (premium=$value, expiry=$expiry)');
      } catch (e) {
        debugPrint('⚠️  [Subscription] Firebase sync failed: $e');
      }
    }
  }

  // ── Firebase sync ───────────────────────────────────────────────────────

  Future<void> syncFromFirebase() async {
    if (!_auth.isSignedIn) return;

    try {
      debugPrint('🔄 [Subscription] Syncing from Firebase');
      final data = await _firestore.getSubscription(_auth.currentUser!.uid);

      if (data != null) {
        final isPremium = data['isPremium'] as bool? ?? false;

        // Check server-side expiry date
        if (data['expiryDate'] != null) {
          final expiryDate = (data['expiryDate'] as dynamic).toDate() as DateTime;
          if (DateTime.now().isAfter(expiryDate)) {
            debugPrint('⚠️  [Subscription] Server expiry passed — revoking premium');
            await setPremium(false);
            return;
          }
        }

        _isPremium = isPremium;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_premiumKey, isPremium);
        debugPrint('✅ [Subscription] Synced: isPremium=$isPremium');
      }
    } catch (e) {
      debugPrint('❌ [Subscription] Firebase sync failed: $e');
    }
  }

  // ── Restore & validate ──────────────────────────────────────────────────

  /// Restores purchases — use when user reinstalls or switches device.
  Future<bool> restorePurchases() async {
    debugPrint('🔄 [Subscription] Starting restore purchases...');
    
    try {
      // Restore purchases triggers Google Play to refresh purchase state
      await iap.restorePurchases();
      
      // Reload premium status from local storage
      await _loadPremiumStatus();
      
      debugPrint('✅ [Subscription] Restore complete - isPremium: $_isPremium');
      return _isPremium;
      
    } catch (e) {
      debugPrint('❌ [Subscription] Restore failed: $e');
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
}
