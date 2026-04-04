import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with SingleTickerProviderStateMixin {
  final _subscription = SubscriptionService();
  final InAppPurchase _iap = InAppPurchase.instance;
  
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _selectedProductId;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    // Listen to purchase updates
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) {
        _showError('Purchase failed: $error');
      },
    );

    // Initialize subscription service
    await _subscription.init();
    
    setState(() => _isLoading = false);
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (var purchase in purchases) {
      
      if (purchase.status == PurchaseStatus.purchased) {
        _handleSuccessfulPurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        _showError('Purchase failed: ${purchase.error?.message}');
        setState(() => _isPurchasing = false);
      } else if (purchase.status == PurchaseStatus.canceled) {
        setState(() => _isPurchasing = false);
      }

      // Complete pending purchases
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    try {
      await _subscription.setPremium(
        true,
        purchaseId: purchase.purchaseID,
        productId: purchase.productID,
      );
      
      if (mounted) {
        _showSuccess('Premium unlocked! 🎉');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showError('Failed to activate premium: $e');
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _purchaseProduct(String productId) async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _selectedProductId = productId;
    });

    try {
      final product = _subscription.products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found. Please try again.'),
      );

      // All our offerings are subscriptions — always buyNonConsumable
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _showError(e.toString());
      setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restorePurchases() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final success = await _subscription.restorePurchases();
      
      if (!mounted) return;
      
      if (success) {
        _showSuccess('Premium restored successfully! 🎉');
        // Wait a moment then close the paywall
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showError('No active subscriptions found. Purchase a plan to continue.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to restore purchases. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF5F0),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Premium badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8555)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.crown,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Upgrade to Premium',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlock all features and remove ads',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Features list
                      _buildFeatureItem(
                        LucideIcons.activity,
                        'Hourly Temperature Charts',
                        'Track temperature trends hour by hour',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        LucideIcons.bell,
                        'Custom Heat Alerts',
                        'Get notified when temperature changes',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        LucideIcons.sparkles,
                        'No Ads Ever',
                        'Enjoy ad-free experience forever',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        LucideIcons.cloud,
                        'Cloud Backup & Sync',
                        'Access your data across devices',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        LucideIcons.trendingUp,
                        'Advanced Analytics',
                        'Deep insights into your temperature data',
                      ),
                      const SizedBox(height: 32),

                      // Price options
                      if (_subscription.products.isNotEmpty) ...[
                        // Annual — best value (highlighted)
                        _buildPriceOption(
                          productId: SubscriptionService.annualSubscriptionId,
                          title: 'Annual Plan',
                          price: _getProductPrice(SubscriptionService.annualSubscriptionId),
                          period: 'Billed annually • Cancel anytime',
                          isBestValue: true,
                          savings: 'Save 17%',
                        ),
                        const SizedBox(height: 12),
                        // Monthly
                        _buildPriceOption(
                          productId: SubscriptionService.monthlySubscriptionId,
                          title: 'Monthly Plan',
                          price: _getProductPrice(SubscriptionService.monthlySubscriptionId),
                          period: 'Billed monthly • Cancel anytime',
                          isBestValue: false,
                          savings: null,
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Loading pricing...',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Restore purchases button
                      TextButton(
                        onPressed: _isLoading ? null : _restorePurchases,
                        child: Text(
                          'Restore Purchases',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Terms
                      Text(
                        'Payment will be charged to your Google Play account. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF6B35),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceOption({
    required String productId,
    required String title,
    required String price,
    required String period,
    required bool isBestValue,
    String? savings,
  }) {
    final isSelected = _selectedProductId == productId;
    final isThisPurchasing = _isPurchasing && isSelected;
    final isAnnual = productId == SubscriptionService.annualSubscriptionId;

    return GestureDetector(
      onTap: isThisPurchasing ? null : () => _purchaseProduct(productId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isBestValue
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8555)],
                )
              : null,
          color: isBestValue ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBestValue ? Colors.transparent : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            if (isBestValue)
              BoxShadow(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isBestValue ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    if (savings != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          savings,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isThisPurchasing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Price and period
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isBestValue ? Colors.white : const Color(0xFF111827),
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    isAnnual ? '/year' : '/month',
                    style: TextStyle(
                      fontSize: 16,
                      color: isBestValue ? Colors.white70 : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 7-day free trial badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isBestValue 
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isBestValue 
                      ? Colors.white.withValues(alpha: 0.3)
                      : const Color(0xFFFF6B35).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.gift,
                    size: 14,
                    color: isBestValue ? Colors.white : const Color(0xFFFF6B35),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '7-day free trial',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isBestValue ? Colors.white : const Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            
            // Additional info
            Text(
              period,
              style: TextStyle(
                fontSize: 13,
                color: isBestValue ? Colors.white.withValues(alpha: 0.9) : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProductPrice(String productId) {
    try {
      final product = _subscription.products.firstWhere((p) => p.id == productId);
      
      // If Google Play returns "Free" (happens in testing/unpublished products),
      // show the actual prices as fallback
      if (product.price.toLowerCase().contains('free') || 
          product.price.isEmpty || 
          product.price == '0') {
        return productId == SubscriptionService.annualSubscriptionId ? r'$19.99' : r'$1.99';
      }
      
      return product.price;
    } catch (e) {
      // Fallback prices shown while products are loading or not found
      return productId == SubscriptionService.annualSubscriptionId ? r'$19.99' : r'$1.99';
    }
  }
}
