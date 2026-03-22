import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/models/user.dart';
import '../auth/state/auth_state.dart';
import 'push_notification_service.dart';

final pushNotificationBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);

  unawaited(service.initialize());

  final initialAuthState = ref.read(authControllerProvider);
  final initialUser = initialAuthState.asData?.value;
  if (initialUser != null) {
    unawaited(service.syncUser(initialUser));
  }

  ref.listen<AsyncValue<AuthUser?>>(authControllerProvider, (previous, next) {
    if (next.isLoading) return;
    unawaited(service.syncUser(next.asData?.value));
  });
});
