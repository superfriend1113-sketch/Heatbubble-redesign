import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() {
    return _instance;
  }

  SubscriptionService._internal();

  final InAppPurchase iap = InAppPurchase.instance;
  bool _isPremium = false;
  List<ProductDetails> _products = [];

  // Product IDs
  static const String oneTimePurchaseId = 'heatbubble_premium_onetime';
  static const String monthlySubscriptionId = 'heatbubble_premium_monthly';

  // Keys
  static const String _premiumKey = 'is_premium';
  static const String _purchaseDateKey = 'premium_purchase_date';

  bool get isPremium => _isPremium;
  List<ProductDetails> get products => _products;

  /// Initialize subscription service
  Future<void> init() async {
    await _loadPremiumStatus();
    await _initializeProducts();
  }

  /// Load premium status from persistent storage
  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumKey) ?? false;
  }

  /// Initialize available products
  Future<void> _initializeProducts() async {
    final bool available = await iap.isAvailable();

    if (!available) {
      print('In-App Purchase not available');
      return;
    }

    // Fetch product details
    const Set<String> ids = {
      oneTimePurchaseId,
      monthlySubscriptionId,
    };

    try {
      final ProductDetailsResponse response = await iap.queryProductDetails(ids);

      _products = response.productDetails;
      print('Products loaded: ${_products.length}');
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  /// Purchase one-time premium ($2.99)
  Future<bool> purchaseOneTime() async {
    final product = _products.firstWhere(
      (p) => p.id == oneTimePurchaseId,
      orElse: () => throw Exception('Product not found'),
    );

    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      await iap.buyNonConsumable(purchaseParam: purchaseParam);
      return true;
    } catch (e) {
      print('Purchase error: $e');
      return false;
    }
  }

  /// Purchase monthly subscription ($1.99/month)
  Future<bool> purchaseMonthly() async {
    final product = _products.firstWhere(
      (p) => p.id == monthlySubscriptionId,
      orElse: () => throw Exception('Product not found'),
    );

    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      await iap.buyConsumable(purchaseParam: purchaseParam);
      return true;
    } catch (e) {
      print('Purchase error: $e');
      return false;
    }
  }

  /// Mark user as premium
  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
    await prefs.setString(_purchaseDateKey, DateTime.now().toIso8601String());
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    try {
      await iap.restorePurchases();
      // Update premium status based on restored purchases
      await _loadPremiumStatus();
    } catch (e) {
      print('Restore purchases error: $e');
    }
  }

  /// Check if premium is valid (for future backend validation)
  Future<bool> validatePremium() async {
    // For now, just return local status
    // Later can add backend validation
    return _isPremium;
  }

  /// Get purchase date
  Future<String?> getPurchaseDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_purchaseDateKey);
  }

  /// Cancel subscription (placeholder for future implementation)
  Future<void> cancelSubscription() async {
    await setPremium(false);
  }
}
