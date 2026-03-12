import 'dart:convert';

import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/community_stories/presentation/create_story_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const b64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+WQGkAAAAASUVORK5CYII=';
  const strCodec = StringCodec();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          final key = strCodec.decodeMessage(message);
          if (key == null) return null;
          if (key == 'AssetManifest.bin') {
            final manifest = <Object?, Object?>{
              'assets/images/app_logo.png': <Object?>[
                <Object?, Object?>{'asset': 'assets/images/app_logo.png'},
              ],
              'assets/images/btn1.png': <Object?>[
                <Object?, Object?>{'asset': 'assets/images/btn1.png'},
              ],
              'assets/images/btn2.png': <Object?>[
                <Object?, Object?>{'asset': 'assets/images/btn2.png'},
              ],
            };
            final encoded = const StandardMessageCodec().encodeMessage(manifest)!;
            return encoded;
          }
          if (key == 'AssetManifest.json') {
            const json =
                '{"assets/images/app_logo.png":["assets/images/app_logo.png"],"assets/images/btn1.png":["assets/images/btn1.png"],"assets/images/btn2.png":["assets/images/btn2.png"]}';
            final bytes = utf8.encode(json);
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          if (key == 'FontManifest.json') {
            final bytes = utf8.encode('[]');
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          if (key == 'assets/images/app_logo.png' ||
              key == 'assets/images/btn1.png' ||
              key == 'assets/images/btn2.png') {
            final bytes = base64Decode(b64);
            return ByteData.view(bytes.buffer);
          }
          return null;
        });
  });

  testWidgets('CreateStoryPage renders primary actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const CreateStoryPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('How to create stories'), findsOneWidget);
    expect(find.text('Bring stories to life'), findsOneWidget);
    expect(find.text('New Story'), findsOneWidget);
    expect(find.text('My Stories'), findsOneWidget);
  });
}
