# RevenueCat Setup for Aura by Antroph

This project uses RevenueCat Flutter SDK `10.1.1` and RevenueCat UI for hosted
Paywalls and Customer Center. The implementation is in:

- `lib/features/subscription/subscription_service.dart`
- `lib/features/subscription/providers/subscription_provider.dart`
- `lib/features/subscription/presentation/revenuecat_actions.dart`
- `lib/features/profile/presentation/subscription_page.dart`

## 1. Pub Packages

The required Pub installation command has been run:

```bash
flutter pub add purchases_flutter purchases_ui_flutter
```

Imports used by the app:

```dart
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
```

## 2. API Keys

Debug and release builds use the current platform's public SDK key by default.
For local debug builds only, set `REVENUECAT_USE_TEST_STORE=true` to use the
RevenueCat Test Store instead. Release builds always ignore that flag and use
Apple or Google:

```dotenv
REVENUECAT_USE_TEST_STORE=false
REVENUECAT_TEST_API_KEY=test_HSuFXrcgoDIhGaDMeEFIQOBnhqo
REVENUECAT_APPLE_API_KEY=appl_your_public_sdk_key
REVENUECAT_GOOGLE_API_KEY=goog_your_public_sdk_key
```

The SDK initializes during application bootstrap:

```dart
final useTestStore = !kReleaseMode && AppEnv.revenueCatUseTestStore;
final platformApiKey = useTestStore
    ? AppEnv.revenueCatTestApiKey
    : Platform.isIOS
    ? AppEnv.revenueCatAppleApiKey
    : AppEnv.revenueCatGoogleApiKey;
if (platformApiKey.isEmpty) {
  throw StateError('A RevenueCat platform API key is required.');
}
await SubscriptionService.instance.init(apiKey: platformApiKey);
```

RevenueCat public SDK keys are intended to be bundled in clients. Never put a
RevenueCat secret API key into a Flutter app.

## 3. RevenueCat Dashboard Configuration

Create or connect the Aura iOS and Android apps in the RevenueCat project. For
store builds, create the matching products in App Store Connect and Google
Play first, then import them into RevenueCat.

Use these product identifiers consistently across stores:

| Display name | Product identifier | Product type |
| --- | --- | --- |
| Lifetime | `lifetime` | Non-consumable / lifetime |
| Yearly | `yearly` | Auto-renewing annual subscription |
| Monthly | `monthly` | Auto-renewing monthly subscription |

Create one entitlement:

| Display name | Identifier used in code |
| --- | --- |
| aura_by_antroph_pro | `Aura by Antroph Pro` |

Attach all three products (`lifetime`, `yearly`, and `monthly`) to
`Aura by Antroph Pro`. This is essential: purchases only unlock the app when
the corresponding product grants the entitlement.

Create an Offering, for example with identifier `default`:

| Package | Product |
| --- | --- |
| `$rc_monthly` | `monthly` |
| `$rc_annual` | `yearly` |
| `$rc_lifetime` | `lifetime` |

Mark the Offering as **Current**. In **Paywalls**, create and publish a paywall
for this Offering. Hosted paywalls show store-localized pricing and let product
or presentation changes ship without an app update.

## 4. Platform Configuration

Already applied in this app:

- `ios/Podfile` has iOS deployment target `15.5`, which supports current
  Paywalls.
- `ios/Runner.xcodeproj/project.pbxproj` enables In-App Purchase capability.
- `android/app/src/main/AndroidManifest.xml` includes
  `com.android.vending.BILLING` and already uses `singleTop` launch mode.
- `android/app/src/main/kotlin/com/antroph/aura/MainActivity.kt` extends
  `FlutterFragmentActivity`, which RevenueCat Paywalls require on Android.

## 5. Entitlement and Customer Info Checks

The app never grants Pro based only on a selected product or a successful UI
transition. It checks the active RevenueCat entitlement:

```dart
bool hasProAccess(CustomerInfo customerInfo) {
  return customerInfo.entitlements.active.containsKey(
    SubscriptionService.entitlementIdentifier,
  );
}
```

Retrieve fresh customer information:

```dart
final customerInfo = await SubscriptionService.instance.getCustomerInfo();
final isPro = SubscriptionService.instance.hasProAccess(customerInfo);
```

`customerInfoProvider` also installs
`Purchases.addCustomerInfoUpdateListener`, so renewals, restores, expiration,
and purchases update gated UI without manually caching entitlement booleans.

## 6. Present the RevenueCat Paywall

The story gate and Subscription page call the native hosted paywall only when
Pro is not active:

```dart
final result = await RevenueCatUI.presentPaywallIfNeeded(
  SubscriptionService.entitlementIdentifier,
);
final customerInfo =
    await ref.read(customerInfoProvider.notifier).refresh();
final unlocked = customerInfo != null &&
    SubscriptionService.instance.hasProAccess(customerInfo);
```

After a purchase or restore, the app rechecks customer info before unlocking
premium content. Platform exceptions are converted to useful messages for
cancelled, pending, offline, unavailable-product and disallowed-purchase cases.

## 7. Restore and Customer Center

Restore remains available on the Subscription page:

```dart
final customerInfo = await Purchases.restorePurchases();
final restored = customerInfo.entitlements.active.containsKey(
  SubscriptionService.entitlementIdentifier,
);
```

Customer Center is useful once subscribers need self-service management,
restore help, cancellation feedback, or retention offers. This app exposes it
from the Subscription page:

```dart
await RevenueCatUI.presentCustomerCenter(
  onRestoreCompleted: (customerInfo) {
    ref.read(customerInfoProvider.notifier).apply(customerInfo);
  },
);
```

Configure Customer Center in the RevenueCat dashboard before exposing it to
production users. RevenueCat documents Customer Center as available on its Pro
and Enterprise plans.

## 8. Customer Identity

Anonymous RevenueCat users can purchase before signing in. When an Aura user
is authenticated, `subscriptionIdentitySyncProvider` calls:

```dart
final result = await Purchases.logIn(auraUserId);
```

On sign-out it calls `Purchases.logOut()` only when the RevenueCat user is not
already anonymous. Use stable backend user IDs, never email addresses, for
RevenueCat identity.

## 9. Testing and Release Checklist

1. In RevenueCat Test Store, confirm all three products attach to
   `Aura by Antroph Pro` and the current Offering has a published Paywall.
2. On a device, purchase monthly, yearly and lifetime in separate test users;
   verify the Subscription page changes to **Pro active**.
3. Verify **Restore Purchases**, expired/cancelled access behavior, and
   Customer Center restore behavior.
4. Test Android purchase flows that leave the app for payment verification.
5. Before App Store or Play Store distribution, provide platform public SDK
   keys, store credentials/products, sandbox/store test accounts, legal links
   in the Paywall, and configure Customer Center.

## Official Documentation

- Installation: https://www.revenuecat.com/docs/getting-started/installation/flutter
- Entitlements: https://www.revenuecat.com/docs/getting-started/entitlements
- Paywalls: https://www.revenuecat.com/docs/tools/paywalls
- Displaying Paywalls: https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls
- Customer Center: https://www.revenuecat.com/docs/tools/customer-center
