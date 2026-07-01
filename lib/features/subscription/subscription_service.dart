import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Centralizes RevenueCat identifiers and SDK calls for Aura Pro access.
class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  factory SubscriptionService() => instance;

  static const entitlementIdentifier = 'Aura by Antroph Pro';
  static const entitlementDisplayName = 'Premium';
  static const monthlyPackageIdentifier = r'$rc_monthly';
  static const quarterlyPackageIdentifier = r'$rc_three_month';
  static const annualPackageIdentifier = r'$rc_annual';

  bool _initialized = false;

  Future<bool> get isConfigured async {
    if (_initialized) return true;
    try {
      _initialized = await Purchases.isConfigured;
      return _initialized;
    } catch (_) {
      return false;
    }
  }

  Future<void> init({required String apiKey, String? appUserId}) async {
    if (await isConfigured) {
      _initialized = true;
      return;
    }
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('A RevenueCat public SDK API key is required.');
    }

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    final configuration = PurchasesConfiguration(apiKey);
    if (appUserId != null && appUserId.isNotEmpty) {
      configuration.appUserID = appUserId;
    }
    await Purchases.configure(configuration);
    _initialized = true;
  }

  bool hasProAccess(CustomerInfo customerInfo) {
    return customerInfo.entitlements.active.containsKey(entitlementIdentifier);
  }

  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  void addCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  void removeCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) {
    Purchases.removeCustomerInfoUpdateListener(listener);
  }

  Future<Offerings> getOfferings() => Purchases.getOfferings();

  Future<CustomerInfo> purchasePackage(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  Future<CustomerInfo> logIn(String appUserId) async {
    final result = await Purchases.logIn(appUserId);
    return result.customerInfo;
  }

  Future<CustomerInfo?> logOut() async {
    if (await Purchases.isAnonymous) return null;
    return Purchases.logOut();
  }

  String userFacingError(PlatformException error) {
    switch (_errorCode(error)) {
      case PurchasesErrorCode.purchaseCancelledError:
        return 'Purchase cancelled.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Your purchase is pending approval.';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'This plan is not available right now.';
      case PurchasesErrorCode.networkError:
      case PurchasesErrorCode.offlineConnectionError:
        return 'Check your internet connection and try again.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.configurationError:
        return 'RevenueCat is not configured for this store yet. Check the API key, products, and offering setup.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  bool isCancellation(PlatformException error) {
    return _errorCode(error) == PurchasesErrorCode.purchaseCancelledError;
  }

  PurchasesErrorCode _errorCode(PlatformException error) {
    try {
      return PurchasesErrorHelper.getErrorCode(error);
    } on FormatException {
      return PurchasesErrorCode.unknownError;
    }
  }
}
