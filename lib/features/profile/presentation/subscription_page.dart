import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../subscription/models/subscription_models.dart';
import '../../subscription/presentation/revenuecat_actions.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../subscription/subscription_service.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(backendSubscriptionProvider);
    final hasPro = subscription.maybeWhen(
      data: (value) => value.isActive,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Aura Pro')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(backendSubscriptionProvider);
          await ref.read(customerInfoProvider.notifier).refresh();
          await ref.read(backendSubscriptionProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _StatusCard(subscription: subscription),
            const SizedBox(height: 24),
            const Text(
              SubscriptionService.entitlementDisplayName,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasPro
                  ? 'Your premium access is enabled on this account.'
                  : 'View available plans and pricing in the secure checkout.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            if (!hasPro)
              FilledButton(
                onPressed: () => presentAuraProPaywall(context, ref),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('View Plans'),
                ),
              ),
            if (hasPro)
              FilledButton(
                onPressed: () => presentAuraCustomerCenter(context, ref),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Manage Subscription'),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => restoreAuraPurchases(context, ref),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Restore Purchases'),
              ),
            ),
            if (!hasPro) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => presentAuraCustomerCenter(context, ref),
                child: const Text('Purchase help and management'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.subscription});

  final AsyncValue<SubscriptionStatus> subscription;

  @override
  Widget build(BuildContext context) {
    final value = subscription.value;
    final hasPro = value?.isActive ?? false;
    final expiration = value?.expiresAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasPro ? 'Pro active' : 'Free plan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            if (subscription.isLoading) const LinearProgressIndicator(),
            if (subscription.hasError)
              const Text('Could not refresh your subscription status.'),
            if (hasPro && expiration != null)
              Text('Access through ${_displayDate(expiration)}'),
            if (hasPro && expiration == null) const Text('Premium access'),
            if (value?.isCancelledButActive == true)
              Text(
                'Cancelled. Access remains until ${_displayDate(expiration)}.',
              ),
            if (value?.hasBillingIssue == true &&
                value?.gracePeriodExpiresAt != null)
              Text(
                'Payment issue. Update by ${_displayDate(value!.gracePeriodExpiresAt)}.',
              ),
          ],
        ),
      ),
    );
  }

  static String _displayDate(DateTime? value) {
    if (value == null) return 'the end of your billing period';
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
