import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/ad_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class CreditCenterViewModel extends ChangeNotifier {
  CreditCenterViewModel({required this.userId}) {
    _init();
  }

  final String userId;
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  RewardedAd? _rewardedAd;
  bool _disposed = false;

  bool isLoadingProducts = false;
  bool isProcessingPurchase = false;
  bool isLoadingAd = false;
  bool adReady = false;
  String? errorMessage;
  String? infoMessage;

  final Map<String, ProductDetails> products = {};
  final Set<String> _processedPurchaseIds = <String>{};

  static const Set<String> creditProductIds = {
    'credits_5',
    'credits_20',
    'credits_100',
    'credits_250',
  };

  // Yeni abonelik product ID'leri (App Store Connect ile eşleşmeli)
  static const Set<String> premiumProductIds = {
    'premium_weekly_v2',
    'premium_monthly_v2',
    'premium_yearly_v2',
  };

  static const Map<String, int> creditAmounts = {
    'credits_5': 5,
    'credits_20': 20,
    'credits_100': 100,
    'credits_250': 250,
  };

  static const Map<String, _PremiumGrant> premiumGrants = {
    'premium_weekly_v2': _PremiumGrant(credits: 5, days: 7),
    'premium_monthly_v2': _PremiumGrant(credits: 40, days: 30),
    'premium_yearly_v2': _PremiumGrant(credits: 200, days: 365),
  };

  Future<void> _init() async {
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (error) {
        _setError('Purchase error: $error');
      },
    );
    await loadProducts();
    await loadRewardedAd();
  }

  Future<void> loadProducts() async {
    isLoadingProducts = true;
    _notify();
    final available = await _iap.isAvailable();
    if (!available) {
      _setError('Store not available');
      isLoadingProducts = false;
      _notify();
      return;
    }

    final response = await _iap.queryProductDetails(
      creditProductIds.union(premiumProductIds),
    );
    if (response.error != null) {
      _setError(response.error!.message);
    }
    products
      ..clear()
      ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));
    isLoadingProducts = false;
    _notify();
  }

  Future<void> loadRewardedAd() async {
    if (isLoadingAd) return;
    isLoadingAd = true;
    adReady = false;
    _notify();

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          adReady = true;
          isLoadingAd = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _setError('Ad failed to show');
              loadRewardedAd();
            },
          );
          _notify();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          isLoadingAd = false;
          _setError('Ad load failed');
          _notify();
        },
      ),
    );
  }

  Future<void> showRewardedAd() async {
    if (!adReady || _rewardedAd == null) {
      _notify();
      await loadRewardedAd();
      return;
    }
    _rewardedAd!.show(
      onUserEarnedReward: (_, __) async {
        await _grantCredits(1, reason: 'rewarded_ad');
        _notify();
      },
    );
  }

  Future<void> purchaseCreditPack(String productId) async {
    final product = products[productId];
    if (product == null) {
      _setError('Product not available. Please try again or check your connection.');
      _notify();
      return;
    }
    isProcessingPurchase = true;
    errorMessage = null;
    _notify();
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  Future<void> purchasePremium(String productId) async {
    final product = products[productId];
    if (product == null) {
      _setError('Product not available. Please try again or check your connection.');
      _notify();
      return;
    }
    isProcessingPurchase = true;
    errorMessage = null;
    _notify();
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  String priceForProduct(String productId, String fallback) {
    final product = products[productId];
    return product?.price ?? fallback;
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          isProcessingPurchase = true;
          _notify();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handlePurchase(purchase);
          break;
        case PurchaseStatus.error:
          isProcessingPurchase = false;
          _setError(purchase.error?.message ?? 'Purchase failed');
          _notify();
          break;
        case PurchaseStatus.canceled:
          isProcessingPurchase = false;
          _notify();
          break;
      }
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    final purchaseId = purchase.purchaseID ?? purchase.verificationData.serverVerificationData;
    if (purchaseId.isNotEmpty && _processedPurchaseIds.contains(purchaseId)) {
      return;
    }

    if (creditProductIds.contains(purchase.productID)) {
      final amount = creditAmounts[purchase.productID] ?? 0;
      if (amount > 0) {
        await _grantCredits(amount, reason: 'iap_credit_pack');
        _setInfo('+$amount credits');
      }
    }

    if (premiumProductIds.contains(purchase.productID)) {
      final grant = premiumGrants[purchase.productID];
      if (grant != null) {
        await _grantPremium(grant);
        _setInfo('Premium activated');
      }
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
    if (purchaseId.isNotEmpty) {
      _processedPurchaseIds.add(purchaseId);
    }
    isProcessingPurchase = false;
    _notify();
  }

  Future<void> _grantCredits(int amount, {required String reason}) async {
    await _firestore.collection('users').doc(userId).update({
      'credits': FieldValue.increment(amount),
      'lastCreditReason': reason,
    });
  }

  Future<void> _grantPremium(_PremiumGrant grant) async {
    final now = DateTime.now();
    final doc = await _firestore.collection('users').doc(userId).get();
    final current = (doc.data()?['premiumExpiresAt'] as Timestamp?)?.toDate();
    final base = (current != null && current.isAfter(now)) ? current : now;
    final expiresAt = base.add(Duration(days: grant.days));
    await _firestore.collection('users').doc(userId).update({
      'isPremium': true,
      'premiumExpiresAt': Timestamp.fromDate(expiresAt),
      'credits': FieldValue.increment(grant.credits),
      'lastPremiumGrantAt': Timestamp.fromDate(now),
    });
  }

  String _rewardedAdUnitId() => AdConfig.rewardedAdUnitId();

  void _setError(String message) {
    errorMessage = message;
  }

  void _setInfo(String message) {
    infoMessage = message;
  }

  void clearInfo() {
    infoMessage = null;
    _notify();
  }

  void clearError() {
    errorMessage = null;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _purchaseSub?.cancel();
    _rewardedAd?.dispose();
    super.dispose();
  }
}

class _PremiumGrant {
  const _PremiumGrant({required this.credits, required this.days});
  final int credits;
  final int days;
}
