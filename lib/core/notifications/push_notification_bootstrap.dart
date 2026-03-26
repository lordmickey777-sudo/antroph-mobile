import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_notification_service.dart';

final pushNotificationBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);

  unawaited(service.initialize());
});
