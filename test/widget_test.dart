// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/app.dart';
import 'package:antroph_mobile/core/notifications/push_notification_bootstrap.dart';
import 'package:antroph_mobile/features/story/providers/rive_sync_bootstrap_provider.dart';
import 'package:antroph_mobile/features/subscription/providers/subscription_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Provide a transparent 1x1 PNG for any asset load in tests
    const b64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+WQGkAAAAASUVORK5CYII=';
    const strCodec = StringCodec();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          final key = strCodec.decodeMessage(message);
          if (key == null) return null;
          if (key == 'AssetManifest.bin') {
            // Let framework fall back to JSON
            return null;
          }
          if (key == 'AssetManifest.json') {
            // Minimal manifest referencing the images used by tests.
            const json =
                '{"assets/images/app_logo.png":["assets/images/app_logo.png"],"assets/images/app_logo.png":["assets/images/app_logo.png"]}';
            final bytes = utf8.encode(json);
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          if (key == 'FontManifest.json') {
            final bytes = utf8.encode('[]');
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          if (key.endsWith('app_logo.png') || key.endsWith('app_logo.png')) {
            final bytes = base64Decode(b64);
            return ByteData.view(bytes.buffer);
          }
          return null;
        });
  });

  testWidgets('App shows splash screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationBootstrapProvider.overrideWith((ref) {}),
          riveSyncBootstrapProvider.overrideWith((ref) {}),
          subscriptionIdentitySyncProvider.overrideWith((ref) async {}),
        ],
        child: const App(),
      ),
    );
    // First frame: splash should be visible
    expect(find.text('Aura 1.0'), findsOneWidget);
  });
}
