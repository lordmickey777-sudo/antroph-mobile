import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../../widgets/toast.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_provider.dart';

Future<bool> ensureAuraSubscriptionTier(
  BuildContext context,
  WidgetRef ref, {
  String requiredTier = SubscriptionTier.starter,
}) async {
  final current = ref.read(backendSubscriptionProvider).asData?.value;
  if (current != null && current.tierAtLeast(requiredTier)) {
    return true;
  }

  final status = await _readBackendSubscription(ref);
  if (status.tierAtLeast(requiredTier)) return true;
  if (!context.mounted) return false;

  final opened = await presentAuraProPaywall(context, ref);
  if (!opened) return false;

  final refreshed = await _readBackendSubscription(ref);
  return refreshed.tierAtLeast(requiredTier);
}

Future<bool> presentAuraProPaywall(BuildContext context, WidgetRef ref) async {
  final service = ref.read(subscriptionServiceProvider);
  try {
    if (!await service.isConfigured) {
      if (context.mounted) {
        showToast(context, 'Subscriptions are unavailable right now.');
      }
      return false;
    }

    if (!context.mounted) return false;
    final result = await RevenueCatUI.presentPaywall(displayCloseButton: true);
    await ref.read(customerInfoProvider.notifier).refresh();
    final status = await _refreshBackendSubscription(ref, force: true);
    final hasAccess = status.isActive;
    if (!context.mounted) return hasAccess;
    if (result == PaywallResult.purchased ||
        result == PaywallResult.restored ||
        (result == PaywallResult.notPresented && hasAccess)) {
      showToast(context, '${_tierName(status)} is active.', success: true);
    } else if (result == PaywallResult.error) {
      showToast(context, 'The purchase could not be completed.');
    }
    return hasAccess;
  } on PlatformException catch (error) {
    if (context.mounted && !service.isCancellation(error)) {
      showToast(context, service.userFacingError(error));
    }
    return false;
  } catch (_) {
    if (context.mounted) {
      showToast(context, 'The paywall could not be opened. Please try again.');
    }
    return false;
  }
}

Future<void> presentAuraCustomerCenter(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(subscriptionServiceProvider);
  try {
    await RevenueCatUI.presentCustomerCenter(
      onRestoreCompleted: (customerInfo) {
        ref.read(customerInfoProvider.notifier).apply(customerInfo);
        ref.invalidate(backendSubscriptionProvider);
      },
    );
    await ref.read(customerInfoProvider.notifier).refresh();
    ref.invalidate(backendSubscriptionProvider);
    await ref.read(backendSubscriptionProvider.future);
  } on PlatformException catch (error) {
    if (context.mounted) {
      showToast(context, service.userFacingError(error));
    }
  } catch (_) {
    if (context.mounted) {
      showToast(context, 'Subscription management is unavailable right now.');
    }
  }
}

Future<void> restoreAuraPurchases(BuildContext context, WidgetRef ref) async {
  final service = ref.read(subscriptionServiceProvider);
  try {
    final customerInfo = await service.restorePurchases();
    ref.read(customerInfoProvider.notifier).apply(customerInfo);
    final status = await _refreshBackendSubscription(ref, force: true);
    final hasAccess = status.isActive;
    if (!context.mounted) return;
    if (hasAccess) {
      showToast(context, '${_tierName(status)} restored.', success: true);
    } else {
      showToast(context, 'No active Aura subscription was found.');
    }
  } on PlatformException catch (error) {
    if (context.mounted) {
      showToast(context, service.userFacingError(error));
    }
  } catch (_) {
    if (context.mounted) {
      showToast(context, 'Could not restore purchases. Please try again.');
    }
  }
}

Future<SubscriptionStatus> _refreshBackendSubscription(
  WidgetRef ref, {
  bool force = false,
}) async {
  try {
    var status = await refreshBackendSubscription(
      ref,
      forceRevenueCatSync: force,
    );
    if (status.isActive) return status;

    await Future<void>.delayed(const Duration(seconds: 2));
    status = await refreshBackendSubscription(ref, forceRevenueCatSync: force);
    return status;
  } catch (_) {
    return SubscriptionStatus.free();
  }
}

Future<SubscriptionStatus> _readBackendSubscription(WidgetRef ref) async {
  try {
    return await ref.read(backendSubscriptionProvider.future);
  } catch (_) {
    return SubscriptionStatus.free();
  }
}

String _tierName(SubscriptionStatus status) {
  return 'Aura ${SubscriptionTier.displayName(status.tier)}';
}
