import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class InAppPurchaseAttemptResult {
  const InAppPurchaseAttemptResult._({
    required this.success,
    required this.cancelled,
    required this.message,
    this.platform,
    this.productId,
    this.purchaseId,
    this.verificationData,
    this.verificationSource,
    this.transactionDateMillis,
  });

  final bool success;
  final bool cancelled;
  final String? message;
  final String? platform;
  final String? productId;
  final String? purchaseId;
  final String? verificationData;
  final String? verificationSource;
  final int? transactionDateMillis;

  factory InAppPurchaseAttemptResult.success({
    required String platform,
    required String productId,
    required String? purchaseId,
    required String verificationData,
    required String verificationSource,
    required int? transactionDateMillis,
  }) {
    return InAppPurchaseAttemptResult._(
      success: true,
      cancelled: false,
      message: null,
      platform: platform,
      productId: productId,
      purchaseId: purchaseId,
      verificationData: verificationData,
      verificationSource: verificationSource,
      transactionDateMillis: transactionDateMillis,
    );
  }

  factory InAppPurchaseAttemptResult.failure(String message) {
    return InAppPurchaseAttemptResult._(
      success: false,
      cancelled: false,
      message: message,
    );
  }

  factory InAppPurchaseAttemptResult.cancelled([String? message]) {
    return InAppPurchaseAttemptResult._(
      success: false,
      cancelled: true,
      message: message ?? 'Purchase was cancelled.',
    );
  }
}

class InAppPurchaseService {
  static const Duration _purchaseTimeout = Duration(minutes: 4);
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  Future<InAppPurchaseAttemptResult> buyProduct({
    required String productId,
  }) async {
    if (kIsWeb) {
      return InAppPurchaseAttemptResult.failure(
        'In-app purchase is only available on Android and iOS.',
      );
    }

    final String? platform = _platformKey();
    if (platform == null) {
      return InAppPurchaseAttemptResult.failure(
        'This platform does not support in-app purchases.',
      );
    }

    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      return InAppPurchaseAttemptResult.failure(
        'Store is currently unavailable on this device.',
      );
    }

    final ProductDetailsResponse detailsResponse = await _inAppPurchase
        .queryProductDetails(<String>{productId});
    if (detailsResponse.error != null) {
      return InAppPurchaseAttemptResult.failure(detailsResponse.error!.message);
    }

    if (detailsResponse.notFoundIDs.contains(productId) ||
        detailsResponse.productDetails.isEmpty) {
      return InAppPurchaseAttemptResult.failure(
        'Configured in-app product is not available in the store listing.',
      );
    }

    final ProductDetails product = detailsResponse.productDetails.firstWhere(
      (ProductDetails item) => item.id == productId,
      orElse: () => detailsResponse.productDetails.first,
    );

    final Completer<InAppPurchaseAttemptResult> completer =
        Completer<InAppPurchaseAttemptResult>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _inAppPurchase.purchaseStream.listen(
      (List<PurchaseDetails> updates) async {
        for (final PurchaseDetails purchase in updates) {
          if (purchase.productID != product.id) {
            continue;
          }

          if (purchase.status == PurchaseStatus.pending) {
            continue;
          }

          if (purchase.pendingCompletePurchase) {
            try {
              await _inAppPurchase.completePurchase(purchase);
            } catch (_) {
              // Keep processing; this should not block server verification.
            }
          }

          if (purchase.status == PurchaseStatus.error) {
            if (!completer.isCompleted) {
              completer.complete(
                InAppPurchaseAttemptResult.failure(
                  purchase.error?.message ??
                      'Purchase failed. Please try again.',
                ),
              );
            }
            return;
          }

          if (purchase.status == PurchaseStatus.canceled) {
            if (!completer.isCompleted) {
              completer.complete(InAppPurchaseAttemptResult.cancelled());
            }
            return;
          }

          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            final String verificationData = purchase
                .verificationData
                .serverVerificationData
                .trim();
            if (verificationData.isEmpty) {
              if (!completer.isCompleted) {
                completer.complete(
                  InAppPurchaseAttemptResult.failure(
                    'Purchase verification data is missing.',
                  ),
                );
              }
              return;
            }

            if (!completer.isCompleted) {
              completer.complete(
                InAppPurchaseAttemptResult.success(
                  platform: platform,
                  productId: purchase.productID,
                  purchaseId: purchase.purchaseID,
                  verificationData: verificationData,
                  verificationSource: purchase.verificationData.source,
                  transactionDateMillis: int.tryParse(
                    purchase.transactionDate ?? '',
                  ),
                ),
              );
            }
            return;
          }
        }
      },
      onError: (Object _) {
        if (!completer.isCompleted) {
          completer.complete(
            InAppPurchaseAttemptResult.failure(
              'Unable to receive store purchase updates.',
            ),
          );
        }
      },
      cancelOnError: false,
    );

    try {
      final bool launched = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!launched) {
        return InAppPurchaseAttemptResult.failure(
          'Unable to open store checkout for this product.',
        );
      }

      return await completer.future.timeout(
        _purchaseTimeout,
        onTimeout: () => InAppPurchaseAttemptResult.failure(
          'Purchase timed out. Please check your store account and try again.',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  String? _platformKey() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }
}
