import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/widgets/aliolo_page.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumUpgradePage extends StatelessWidget {
  const PremiumUpgradePage({super.key});

  @override
  Widget build(BuildContext context) {
    final subService = context.watch<SubscriptionService>();
    final mainColor = const Color(0xFF1D4289);

    return AlioloPage(
      title: const Text('Aliolo Premium'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const Icon(Icons.stars, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Unlock Full Potential',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Get unlimited cards, advanced statistics, and early access to new math engines.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),
                if (subService.isPremium)
                  const Card(
                    color: Colors.green,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 16),
                          Text(
                            'You are an Aliolo Premium member!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (subService.products.isEmpty)
                  const CircularProgressIndicator()
                else
                  ...subService.products.map((product) => _buildProductCard(context, product, mainColor)),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Maybe Later'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductDetails product, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        title: Text(product.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(product.description),
        trailing: ElevatedButton(
          onPressed: () => context.read<SubscriptionService>().buySubscription(product),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Text(product.price),
        ),
      ),
    );
  }
}
