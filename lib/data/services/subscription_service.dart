import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'auth_service.dart';

class SubscriptionService extends ChangeNotifier {
  static const productIds = {
    'aliolo_premium_weekly',
    'aliolo_premium_monthly',
    'aliolo_premium_yearly',
  };

  final InAppPurchase? _iap = kIsWeb ? null : InAppPurchase.instance;
  final _cfClient = getIt<CloudflareHttpClient>();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  DateTime? _expiryDate;
  DateTime? get expiryDate => _expiryDate;

  String? _activeProductId;
  String? get activeProductId => _activeProductId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  String? _lastCheckedUserId;

  SubscriptionService() {
    if (!kIsWeb && _iap != null) {
      _purchaseSubscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (error) => AppLogger.log('Purchase stream error: $error'),
      );
    }

    getIt<AuthService>().addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final user = getIt<AuthService>().currentUser;
    if (user?.serverId != _lastCheckedUserId) {
      init();
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
      _expiryDate = null;
      _activeProductId = null;
      notifyListeners();
      return;
    }

    try {
      final response = await _cfClient.client.get('/api/subscriptions');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final status = data['status'] as String?;
        final expiryValue = data['expiry_date'] ?? data['effective_until'];
        final expiry =
            expiryValue == null ? null : DateTime.tryParse(expiryValue.toString());

        _activeProductId = data['product_id'] as String?;
        _expiryDate = expiry;
        _isPremium =
            status == 'active' &&
            (expiry == null || expiry.isAfter(DateTime.now()));
      } else {
        _isPremium = false;
        _expiryDate = null;
        _activeProductId = null;
      }
    } catch (e) {
      AppLogger.log('Error checking subscription: $e');
      _isPremium = false;
      _expiryDate = null;
      _activeProductId = null;
    }
    notifyListeners();
  }

  Future<void> loadProducts() async {
    if (kIsWeb || _iap == null) return;

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        _products = [];
        notifyListeners();
        return;
      }

      final response = await _iap.queryProductDetails(productIds);
      _products = response.productDetails;
      notifyListeners();
    } catch (e) {
      AppLogger.log('Error loading store products: $e');
      _products = [];
      notifyListeners();
    }
  }

  ProductDetails? productForProductId(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<void> buySubscriptionByProductId(String productId) async {
    if (kIsWeb) {
      await _openPaddleCheckout(productId);
      return;
    }

    if (_iap == null) {
      throw Exception('In-app purchases are not available on this platform.');
    }

    var product = productForProductId(productId);
    if (product == null) {
      await loadProducts();
      product = productForProductId(productId);
    }
    if (product == null) {
      throw Exception('Product is not available in the store.');
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _openPaddleCheckout(String productId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _cfClient.client.post(
        '/api/subscriptions/paddle/checkout',
        data: {'productId': productId},
      );

      final checkoutUrl = response.data?['checkout_url']?.toString();
      if (response.statusCode != 200 || checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception(response.data?['error'] ?? 'Paddle checkout is not configured.');
      }

      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Could not open Paddle checkout.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _isLoading = true;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _isLoading = false;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyPurchaseOnBackend(purchase);
      }

      if (purchase.pendingCompletePurchase && _iap != null) {
        await _iap.completePurchase(purchase);
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _verifyPurchaseOnBackend(PurchaseDetails purchase) async {
    try {
      final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      final endpoint =
          isApple ? '/api/subscriptions/apple/verify' : '/api/subscriptions/google/verify';

      final response = await _cfClient.client.post(
        endpoint,
        data: {
          'purchaseToken': purchase.verificationData.serverVerificationData,
          'productId': purchase.productID,
          'orderId': purchase.purchaseID,
          'source': purchase.verificationData.source,
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

  Future<void> restorePurchases() async {
    if (kIsWeb || _iap == null) return;
    await _iap.restorePurchases();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    getIt<AuthService>().removeListener(_onAuthChanged);
    super.dispose();
  }
}
