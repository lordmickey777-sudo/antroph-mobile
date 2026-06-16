import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'app_router.dart';
import 'core/notifications/push_notification_bootstrap.dart';
import 'core/theme/theme_provider.dart';
import 'features/story/providers/rive_sync_bootstrap_provider.dart';
import 'features/subscription/providers/subscription_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushNotificationBootstrapProvider);
    ref.watch(riveSyncBootstrapProvider);
    ref.watch(subscriptionIdentitySyncProvider);
    final router = ref.watch(routerProvider);

    return PostHogWidget(
      child: MaterialApp.router(
        title: 'Antroph',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        themeMode: ThemeMode.dark,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        builder: (context, child) {
          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child,
          );
        },
      ),
    );
  }
}
