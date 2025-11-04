import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart' as l;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/logging/logger.dart';

typedef AppRunner = Future<void> Function();

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
        WidgetsFlutterBinding.ensureInitialized();
        // Initialize logger
        Log.init();
        await runAppCallback();
      },
      (error, stack) {
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
          WidgetsFlutterBinding.ensureInitialized();
          // Initialize logger
          Log.init();
          await runAppCallback();
        },
        (error, stack) async {
          l.Logger().e('Uncaught error', error: error, stackTrace: stack);
          await Sentry.captureException(error, stackTrace: stack);
        },
      );
    },
  );
}
