import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../../widgets/toast.dart';
import '../providers/subscription_provider.dart';

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
    final hasAccess = await _refreshBackendSubscription(ref);
    if (!context.mounted) return hasAccess;
    if (result == PaywallResult.purchased ||
        result == PaywallResult.restored ||
        (result == PaywallResult.notPresented && hasAccess)) {
      showToast(context, 'Aura by Antroph Pro is active.', success: true);
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
    final hasAccess = await _refreshBackendSubscription(ref);
    if (!context.mounted) return;
    if (hasAccess) {
      showToast(context, 'Aura by Antroph Pro restored.', success: true);
    } else {
      showToast(context, 'No active Aura Pro purchase was found.');
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

Future<bool> _refreshBackendSubscription(WidgetRef ref) async {
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
