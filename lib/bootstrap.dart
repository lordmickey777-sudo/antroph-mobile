import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart' as l;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/analytics/posthog_service.dart';
import 'core/env/env.dart';
import 'firebase_options.dart';

import 'core/logging/logger.dart';

typedef AppRunner = Future<void> Function();

Future<void> _initializeCoreServices() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await AppEnv.load();
  Log.init();
  await PostHogService.setup();
}

Future<void> bootstrap(AppRunner runAppCallback) async {
  final sentryDsn = const String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
  final release = const String.fromEnvironment(
    'APP_RELEASE',
    defaultValue: 'dev',
  );

  if (sentryDsn.isEmpty) {
    // Run without Sentry
    l.Logger().i('Starting app without Sentry (no DSN provided).');
    await runZonedGuarded(
      () async {
        await _initializeCoreServices();
        await runAppCallback();
      },
      (error, stack) {
        unawaited(
          PostHogService.captureRunZonedGuardedError(
            error: error,
            stackTrace: stack,
          ),
        );
        l.Logger().e('Uncaught error', error: error, stackTrace: stack);
      },
    );
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 0.2; // adjust as needed
      options.profilesSampleRate = 0.1;
      options.release = release;
    },
    appRunner: () async {
      await runZonedGuarded(
        () async {
          await _initializeCoreServices();
          await runAppCallback();
        },
        (error, stack) async {
          unawaited(
            PostHogService.captureRunZonedGuardedError(
              error: error,
              stackTrace: stack,
            ),
          );
          l.Logger().e('Uncaught error', error: error, stackTrace: stack);
          await Sentry.captureException(error, stackTrace: stack);
        },
      );
    },
  );
}
