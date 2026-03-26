import 'dart:convert';

import 'package:antroph_mobile/features/community_stories/models/community_story_model.dart';
import 'package:antroph_mobile/features/community_stories/widgets/community_story_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          if (key == 'AssetManifest.bin') return null;
          if (key == 'AssetManifest.json') {
            const json =
                '{"assets/images/default.png":["assets/images/default.png"]}';
            final bytes = utf8.encode(json);
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          if (key == 'FontManifest.json') {
            final bytes = utf8.encode('[]');
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          if (key == CommunityStoryGridCard.placeholderAsset) {
            final bytes = base64Decode(b64);
            return ByteData.view(bytes.buffer);
          }
          return null;
        });
  });

  testWidgets('shows placeholder asset when story image is absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityStoryGridCard(story: _story()),
        ),
      ),
    );

    await tester.pump();

    expect(_findPlaceholderAsset(), findsOneWidget);
  });

  testWidgets('shows placeholder asset when story image fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityStoryGridCard(
            story: _story(coverImageUrl: 'https://broken.example.com/image.png'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(_findPlaceholderAsset(), findsOneWidget);
  });
}

CommunityStoryDto _story({String? coverImageUrl}) {
  final now = DateTime(2026, 3, 11);
  return CommunityStoryDto(
    id: 'story-1',
    title: 'Test Story',
    coverImageUrl: coverImageUrl,
    moderationStatus: 'published',
    createdAt: now,
    updatedAt: now,
  );
}

Finder _findPlaceholderAsset() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Image) return false;
    final provider = widget.image;
    return provider is AssetImage &&
        provider.assetName == CommunityStoryGridCard.placeholderAsset;
  });
}
