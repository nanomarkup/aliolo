import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  final List<Map<String, dynamic>> _features = [
    {'name': 'Learn any subject or collection', 'free': true},
    {'name': 'Access to community subjects', 'free': true},
    {'name': 'Spaced Repetition (SM-2)', 'free': true},
    {'name': 'Favorite items on dashboard', 'free': true},
    {'name': 'Invite and connect with friends', 'free': true},
    {'name': 'Direct feedback and suggestions', 'free': true},
    {'name': 'Unlimited daily XP goals', 'free': false},
    {'name': 'Create folders, subjects and collections', 'free': false},
    {'name': 'Test subjects and collections', 'free': false},
    {'name': 'Auto-Play mode', 'free': false},
    {'name': 'Customize learning and testing', 'free': false},
    {'name': 'Private profile mode', 'free': false},
  ];

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

    return AlioloScrollablePage(
      title: const Text('Aliolo Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              const Text(
                'Unlock Full Access',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Master subjects faster with advanced testing, creation tools, and unlimited goals.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              if (subService.isPremium) ...[
                Card(
                  color: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'You are an Aliolo Premium member! Enjoy unlimited access to all features.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              _buildSubscriptionOption(
                0, "Weekly Access", r"$2.99", "Best for quick goals", 
                originalPrice: r"$5.98"
              ),
              const SizedBox(height: 12),
              _buildSubscriptionOption(
                1, "Monthly Access", r"$8.99", "Most popular choice", 
                originalPrice: r"$17.98", 
                extraInfo: r"($2.25 / Week)"
              ),
              const SizedBox(height: 12),
              _buildSubscriptionOption(
                2, "Yearly Access", r"$80.99", "Save 33% per month", 
                originalPrice: r"$161.98",
                extraInfo: r"($1.56 / Week)"
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
                        SizedBox(width: 50, child: Text('FREE', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                        SizedBox(width: 50, child: Text('PRO', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: currentPrimaryColor))),
                      ],
                    ),
                    const Divider(),
                    ..._features.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(f['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                          SizedBox(width: 50, child: Icon(f['free'] ? Icons.check_circle : Icons.cancel, size: 16, color: f['free'] ? Colors.green : Colors.grey[300])),
                          SizedBox(width: 50, child: Icon(Icons.check_circle, size: 16, color: currentPrimaryColor)),
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

  Widget _buildSubscriptionOption(int index, String title, String price, String sub, {String? originalPrice, String? extraInfo}) {
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
          color: isSelected ? currentPrimaryColor.withValues(alpha: 0.05) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? currentPrimaryColor : Colors.black.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    color: currentPrimaryColor,
                  ),
                ),
                if (extraInfo != null)
                  Text(
                    extraInfo,
                    style: TextStyle(
                      color: currentPrimaryColor.withValues(alpha: 0.7),
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
