import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'auth_service.dart';

class SubscriptionService extends ChangeNotifier {
  final InAppPurchase? _iap = kIsWeb ? null : InAppPurchase.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  SubscriptionService() {
    if (!kIsWeb && _iap != null) {
      final purchaseUpdated = _iap!.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          // handle error
        },
      );
    }
  }

  Future<void> init() async {
    await checkSubscriptionStatus();
    if (!kIsWeb) {
      await loadProducts();
    }
  }

  Future<void> checkSubscriptionStatus() async {
    final user = getIt<AuthService>().currentUser;
    if (user == null) {
      _isPremium = false;
      notifyListeners();
      return;
    }

    try {
      final response = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', user.serverId!)
          .maybeSingle();

      if (response != null) {
        final status = response['status'] as String;
        final expiry = response['expiry_date'] != null 
            ? DateTime.parse(response['expiry_date']) 
            : null;
        
        _isPremium = status == 'active' && (expiry == null || expiry.isAfter(DateTime.now()));
      } else {
        _isPremium = false;
      }
    } catch (e) {
      _isPremium = false;
    }
    notifyListeners();
  }

  Future<void> loadProducts() async {
    if (kIsWeb || _iap == null) return;
    const Set<String> kIds = {'aliolo_premium_monthly', 'aliolo_premium_yearly'};
    final response = await _iap!.queryProductDetails(kIds);
    _products = response.productDetails;
    notifyListeners();
  }

  Future<void> buySubscription(ProductDetails product) async {
    if (kIsWeb || _iap == null) return;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap!.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _isLoading = true;
        notifyListeners();
      } else {
        if (purchase.status == PurchaseStatus.error) {
          _isLoading = false;
          notifyListeners();
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          
          // Verify with Backend
          bool success = await _verifyPurchaseOnBackend(purchase);
          if (success) {
            _isPremium = true;
          }
        }
        
        if (purchase.pendingCompletePurchase) {
          await _iap!.completePurchase(purchase);
        }
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _verifyPurchaseOnBackend(PurchaseDetails purchase) async {
    try {
      // Call Supabase Edge Function to verify with Google Play API
      final response = await _supabase.functions.invoke(
        'verify-google-purchase',
        body: {
          'purchaseToken': purchase.verificationData.serverVerificationData,
          'productId': purchase.productID,
          'orderId': purchase.purchaseID,
        },
      );

      if (response.status == 200) {
        await checkSubscriptionStatus();
        return true;
      }
    } catch (e) {
      debugPrint('Error verifying purchase: $e');
    }
    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
