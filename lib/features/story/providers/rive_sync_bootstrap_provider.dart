import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'story_providers.dart';

final riveSyncBootstrapProvider = Provider<void>((ref) {
  final registry = ref.watch(riveRegistryServiceProvider);
  unawaited(
    () async {
      await registry.reconcileLocalCache();
      await registry.syncManifest();
    }().catchError((_) {}),
  );
});
