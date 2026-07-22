import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/community_stories/presentation/standard_story_guide_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StandardStoryGuidePage shows guide content and CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const StandardStoryGuidePage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('How to create standard stories'), findsWidgets);
    expect(find.text('Before you write'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Start creating'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Start creating'), findsOneWidget);
  });
}
