import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/auth/state/auth_state.dart';
import '../data/subscription_repository.dart';
import '../models/subscription_models.dart';
import '../subscription_service.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});

final offeringsProvider = FutureProvider<Offerings>((ref) {
  final service = ref.read(subscriptionServiceProvider);
  return service.getOfferings();
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final backendSubscriptionProvider = FutureProvider<SubscriptionStatus>((
  ref,
) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null || user.id.isEmpty || user.id == 'self') {
    return SubscriptionStatus.free();
  }
  return ref.read(subscriptionRepositoryProvider).getCurrentSubscription();
});

class CustomerInfoNotifier extends AsyncNotifier<CustomerInfo> {
  late final SubscriptionService _service;
  late final CustomerInfoUpdateListener _listener;

  @override
  Future<CustomerInfo> build() async {
    _service = ref.read(subscriptionServiceProvider);
    if (!await _service.isConfigured) {
      throw StateError('RevenueCat is not configured.');
    }
    _listener = (customerInfo) {
      state = AsyncData(customerInfo);
    };
    _service.addCustomerInfoUpdateListener(_listener);
    ref.onDispose(() {
      _service.removeCustomerInfoUpdateListener(_listener);
    });
    return _service.getCustomerInfo();
  }

  Future<CustomerInfo?> refresh() async {
    state = const AsyncLoading();
    try {
      final customerInfo = await _service.getCustomerInfo();
      state = AsyncData(customerInfo);
      return customerInfo;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  void apply(CustomerInfo customerInfo) {
    state = AsyncData(customerInfo);
  }
}

final customerInfoProvider =
    AsyncNotifierProvider<CustomerInfoNotifier, CustomerInfo>(
      CustomerInfoNotifier.new,
    );

final subscriptionIdentitySyncProvider = FutureProvider<void>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  final service = ref.read(subscriptionServiceProvider);
  if (!await service.isConfigured) {
    ref.invalidate(backendSubscriptionProvider);
    return;
  }
  CustomerInfo? customerInfo;

  if (user != null && user.id.isNotEmpty && user.id != 'self') {
    customerInfo = await service.logIn(user.id);
  } else {
    customerInfo = await service.logOut();
  }

  if (customerInfo != null) {
    ref.read(customerInfoProvider.notifier).apply(customerInfo);
  }
  ref.invalidate(backendSubscriptionProvider);
});

final isSubscribedProvider = Provider<AsyncValue<bool>>((ref) {
  return ref
      .watch(backendSubscriptionProvider)
      .whenData((value) => value.isActive);
});

class PurchaseNotifier extends AsyncNotifier<void> {
  late final SubscriptionService _service;

  @override
  FutureOr<void> build() {
    _service = ref.read(subscriptionServiceProvider);
  }

  Future<bool> purchasePackage(Package package) async {
    state = const AsyncLoading();
    try {
      final customerInfo = await _service.purchasePackage(package);
      ref.read(customerInfoProvider.notifier).apply(customerInfo);
      final unlocked = await _refreshBackendSubscriptionAfterStoreUpdate();
      state = unlocked
          ? const AsyncData(null)
          : AsyncError(
              Exception(
                'Purchase succeeded, but Premium access is not active yet. '
                'Please wait a moment and try again.',
              ),
              StackTrace.current,
            );
      return unlocked;
    } on PlatformException catch (error, stackTrace) {
      if (_service.isCancellation(error)) {
        state = const AsyncData(null);
        return false;
      }
      state = AsyncError(error, stackTrace);
      return false;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    state = const AsyncLoading();
    try {
      final customerInfo = await _service.restorePurchases();
      ref.read(customerInfoProvider.notifier).apply(customerInfo);
      final unlocked = await _refreshBackendSubscriptionAfterStoreUpdate();
      state = const AsyncData(null);
      return unlocked;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> _refreshBackendSubscriptionAfterStoreUpdate() async {
    ref.invalidate(backendSubscriptionProvider);
    try {
      var status = await ref.read(backendSubscriptionProvider.future);
      if (status.isActive) return true;

      await Future<void>.delayed(const Duration(seconds: 2));
      ref.invalidate(backendSubscriptionProvider);
      status = await ref.read(backendSubscriptionProvider.future);
      return status.isActive;
    } catch (_) {
      return false;
    }
  }
}

final purchaseProvider = AsyncNotifierProvider<PurchaseNotifier, void>(
  PurchaseNotifier.new,
);
