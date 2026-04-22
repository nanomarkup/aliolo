import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/features/settings/presentation/pages/billing_page.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';

class PremiumUpgradePage extends StatefulWidget {
  const PremiumUpgradePage({super.key});

  @override
  State<PremiumUpgradePage> createState() => _PremiumUpgradePageState();
}

class _PremiumUpgradePageState extends State<PremiumUpgradePage> {
  int _selectedOptionIndex = 1; // Monthly by default

  void _navigateToBilling(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BillingPage(selectedIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subService = context.watch<SubscriptionService>();
    final currentPrimaryColor = ThemeService().primaryColor;

    final List<Map<String, dynamic>> features = [
      {'name': context.t('feature_learn_all'), 'free': true},
      {'name': context.t('feature_community_access'), 'free': true},
      {'name': context.t('feature_spaced_repetition'), 'free': true},
      {'name': context.t('feature_favorites'), 'free': true},
      {'name': context.t('feature_friends'), 'free': true},
      {'name': context.t('feature_feedback'), 'free': true},
      {'name': context.t('feature_creation'), 'free': false},
      {'name': context.t('feature_testing'), 'free': false},
      {'name': context.t('feature_autoplay'), 'free': false},
      {'name': context.t('feature_customize'), 'free': false},
      {'name': context.t('feature_private_mode'), 'free': false},
    ];

    return AlioloScrollablePage(
      title: Text(
        context.t('premium_title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      appBarColor: currentPrimaryColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 80),
              const SizedBox(height: 24),
              Text(
                context.t('premium_unlock_title'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                context.t('premium_unlock_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              if (subService.isPremium) ...[
                Card(
                  color: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('premium_status_active'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subService.expiryDate != null
                                    ? context.t(
                                      'premium_expires_at',
                                      args: {
                                        'date': DateFormat.yMMMMd().format(
                                          subService.expiryDate!,
                                        ),
                                      },
                                    )
                                    : context.t('premium_lifetime'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              _buildSubscriptionOption(
                0, context.t('plan_weekly_title'), r"$2.99", context.t('plan_weekly_tagline'), 
                originalPrice: r"$5.98",
                isActive: subService.activeProductId == 'aliolo_premium_weekly'
              ),
              const SizedBox(height: 12),
              _buildSubscriptionOption(
                1, context.t('plan_monthly_title'), r"$8.99", context.t('plan_monthly_tagline'), 
                originalPrice: r"$17.98", 
                extraInfo: context.t('price_per_week', args: {'price': r'$2.25'}),
                isActive: subService.activeProductId == 'aliolo_premium_monthly'
              ),
              const SizedBox(height: 12),
              _buildSubscriptionOption(
                2, context.t('plan_yearly_title'), r"$80.99", context.t('plan_yearly_tagline'), 
                originalPrice: r"$161.98",
                extraInfo: context.t('price_per_week', args: {'price': r'$1.56'}),
                isActive: subService.activeProductId == 'aliolo_premium_yearly'
              ),

              const SizedBox(height: 40),

              // Always Visible Plan Comparison (After payment options)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        SizedBox(width: 60, child: Text(context.t('feature_free'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                        SizedBox(width: 60, child: Text(context.t('feature_pro'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: currentPrimaryColor))),
                      ],
                    ),
                    const Divider(),
                    ...features.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(f['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                          SizedBox(width: 60, child: Icon(f['free'] ? Icons.check_circle : Icons.cancel, size: 20, color: f['free'] ? Colors.green : Colors.grey[300])),
                          SizedBox(width: 60, child: Icon(Icons.check_circle, size: 20, color: currentPrimaryColor)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
      slivers: const [],
    );
  }

  Widget _buildSubscriptionOption(int index, String title, String price, String sub, {String? originalPrice, String? extraInfo, bool isActive = false}) {
    final isSelected = _selectedOptionIndex == index;
    final currentPrimaryColor = ThemeService().primaryColor;

    return InkWell(
      onTap: () {
        setState(() => _selectedOptionIndex = index);
        _navigateToBilling(index);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive 
              ? Colors.green.withValues(alpha: 0.05)
              : (isSelected ? currentPrimaryColor.withValues(alpha: 0.05) : Theme.of(context).cardColor),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive 
                ? Colors.green 
                : (isSelected ? currentPrimaryColor : Colors.black.withValues(alpha: 0.1)),
            width: isActive || isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.t('current_subscription'),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(sub, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Text(
                  price,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isActive ? Colors.green : currentPrimaryColor,
                  ),
                ),
                if (extraInfo != null)
                  Text(
                    extraInfo,
                    style: TextStyle(
                      color: isActive ? Colors.green.withValues(alpha: 0.7) : currentPrimaryColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
