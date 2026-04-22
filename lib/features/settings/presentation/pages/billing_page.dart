import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:flutter/foundation.dart';

class BillingPage extends StatefulWidget {
  final int selectedIndex;

  const BillingPage({super.key, required this.selectedIndex});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  bool _isProcessing = false;

  void _handlePurchase(SubscriptionService subService) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments are not yet integrated on Web. Please use the mobile app to upgrade.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    String productId = 'aliolo_premium_monthly';
    if (widget.selectedIndex == 2) productId = 'aliolo_premium_yearly';
    else if (widget.selectedIndex == 0) productId = 'aliolo_premium_weekly';

    final product = subService.products.where((p) => p.id == productId).firstOrNull;
    if (product != null) {
      try {
        await subService.buySubscription(product);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase failed: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not available in store.')),
        );
      }
    }
    
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final subService = context.watch<SubscriptionService>();
    final currentPrimaryColor = ThemeService().primaryColor;
    
    String title = context.t('plan_monthly_title');
    String price = r"$8.99";
    String sub = context.t('plan_monthly_tagline');
    String? originalPrice = r"$17.98";
    String? extraInfo = context.t('price_per_week', args: {'price': r'$2.25'});

    if (widget.selectedIndex == 0) {
      title = context.t('plan_weekly_title');
      price = r"$2.99";
      sub = context.t('plan_weekly_tagline');
      originalPrice = r"$5.98";
      extraInfo = null;
    } else if (widget.selectedIndex == 2) {
      title = context.t('plan_yearly_title');
      price = r"$80.99";
      sub = context.t('plan_yearly_tagline');
      originalPrice = r"$161.98";
      extraInfo = context.t('price_per_week', args: {'price': r'$1.56'});
    }

    return AlioloScrollablePage(
      title: Text(context.t('billing_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      appBarColor: currentPrimaryColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.shopping_cart_checkout, size: 64, color: Colors.grey),
              const SizedBox(height: 32),
              Text(
                context.t('confirm_subscription'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // Plan Display (Mirrors selection style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: currentPrimaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: currentPrimaryColor, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          Text(sub, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (originalPrice != null)
                          Text(
                            originalPrice,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          price,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: currentPrimaryColor,
                          ),
                        ),
                        if (extraInfo != null)
                          Text(
                            extraInfo,
                            style: TextStyle(
                              color: currentPrimaryColor.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              Text(
                context.t('billing_disclaimer'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              
              const SizedBox(height: 48),
              if (_isProcessing)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: () => _handlePurchase(subService),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentPrimaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    context.t('subscribe_now'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('cancel'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
      slivers: const [],
    );
  }
}
