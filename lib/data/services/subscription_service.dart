import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'auth_service.dart';

class SubscriptionService extends ChangeNotifier {
  final InAppPurchase? _iap = kIsWeb ? null : InAppPurchase.instance;
  final _cfClient = getIt<CloudflareHttpClient>();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  DateTime? _expiryDate;
  DateTime? get expiryDate => _expiryDate;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  String? _lastCheckedUserId;

  SubscriptionService() {
    if (!kIsWeb && _iap != null) {
      final purchaseUpdated = _iap!.purchaseStream;
      _purchaseSubscription = purchaseUpdated.listen(
        _onPurchaseUpdate,
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (error) {
          AppLogger.log('Purchase stream error: $error');
        },
      );
    }
    
    getIt<AuthService>().addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final user = getIt<AuthService>().currentUser;
    if (user?.serverId != _lastCheckedUserId) {
      checkSubscriptionStatus();
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
    _lastCheckedUserId = user?.serverId;

    if (user == null || user.serverId == null) {
      _isPremium = false;
      notifyListeners();
      return;
    }

    try {
      final response = await _cfClient.client.get('/api/subscriptions');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final status = data['status'] as String;
        final expiry = data['expiry_date'] != null 
            ? DateTime.parse(data['expiry_date']) 
            : null;
        
        _expiryDate = expiry;
        _isPremium = status == 'active' && (expiry == null || expiry.isAfter(DateTime.now()));
      } else {
        _isPremium = false;
        _expiryDate = null;
      }
    } catch (e) {
      AppLogger.log('Error checking subscription: $e');
      _isPremium = false;
      _expiryDate = null;
    }
    notifyListeners();
  }

  Future<void> loadProducts() async {
    if (kIsWeb || _iap == null) return;
    try {
      const Set<String> kIds = {'aliolo_premium_weekly', 'aliolo_premium_monthly', 'aliolo_premium_yearly'};
      final response = await _iap!.queryProductDetails(kIds);
      _products = response.productDetails;
      notifyListeners();
    } catch (e) {
      AppLogger.log('Error loading products: $e');
    }
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
      final response = await _cfClient.client.post(
        '/api/subscriptions/verify',
        data: {
          'purchaseToken': purchase.verificationData.serverVerificationData,
          'productId': purchase.productID,
          'orderId': purchase.purchaseID,
        },
      );

      if (response.statusCode == 200) {
        await checkSubscriptionStatus();
        return true;
      }
    } catch (e) {
      AppLogger.log('Error verifying purchase: $e');
    }
    return false;
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    getIt<AuthService>().removeListener(_onAuthChanged);
    super.dispose();
  }
}
