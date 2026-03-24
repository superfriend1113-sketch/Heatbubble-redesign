import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _subscription = SubscriptionService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _subscription.init();
  }

  Future<void> _purchaseOneTime() async {
    setState(() => _isLoading = true);
    try {
      final success = await _subscription.purchaseOneTime();
      if (success) {
        await _subscription.setPremium(true);
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseMonthly() async {
    setState(() => _isLoading = true);
    try {
      final success = await _subscription.purchaseMonthly();
      if (success) {
        await _subscription.setPremium(true);
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const Text(
                      '🌡️ HeatBubble Premium',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock all features',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Features Checklist
              _featureItem('Hourly temperature charts'),
              const SizedBox(height: 16),
              _featureItem('Custom heat alerts'),
              const SizedBox(height: 16),
              _featureItem('No ads ever'),
              const SizedBox(height: 16),
              _featureItem('Home screen widget'),
              const SizedBox(height: 16),
              _featureItem('Advanced analytics'),
              const SizedBox(height: 32),

              // Price Cards
              Row(
                children: [
                  // Monthly Card (Left)
                  Expanded(
                    child: _priceCard(
                      title: 'Monthly',
                      price: '\$1.99',
                      period: '/month',
                      isBestValue: false,
                      onTap: _isLoading ? null : _purchaseMonthly,
                      isLoading: _isLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // One-Time Card (Right - Highlighted)
                  Expanded(
                    child: _priceCard(
                      title: 'One-Time',
                      price: '\$2.99',
                      period: 'lifetime',
                      isBestValue: true,
                      onTap: _isLoading ? null : _purchaseOneTime,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main CTA Button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8555)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _purchaseOneTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Unlock Premium - \$2.99',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Restore Purchases
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : () => _subscription.restorePurchases(),
                  child: const Text(
                    'Restore purchases',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureItem(String text) {
    return Row(
      children: [
        Icon(
          LucideIcons.check,
          size: 20,
          color: const Color(0xFFFF6B35),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceCard({
    required String title,
    required String price,
    required String period,
    required bool isBestValue,
    required VoidCallback? onTap,
    required bool isLoading,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isBestValue ? const Color(0xFFFF6B35) : Colors.grey[300]!,
          width: isBestValue ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isBestValue ? const Color(0xFFFFF5F0) : Colors.white,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (isBestValue)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BEST VALUE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: price,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      TextSpan(
                        text: '\n$period',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
