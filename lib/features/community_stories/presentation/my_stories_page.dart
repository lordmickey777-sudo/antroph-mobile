import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

import '../providers/community_stories_providers.dart';
import '../widgets/community_story_card.dart';
import '../widgets/community_story_list_shimmer.dart';
import 'story_editor_page.dart';
import 'story_preview_page.dart';

class MyStoriesPage extends ConsumerWidget {
  const MyStoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncStories = ref.watch(myStoriesProvider);
    final horizontalPadding = AppPadding.horizontal.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF141718)
          : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TypographyText(
          'My Stories',
          variant: TypographyVariant.h4,
          color: isDark ? Colors.white : Colors.black,
        ),
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: asyncStories.when(
        loading: () => const CommunityStoryListShimmer(showStatus: true),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load stories',
                style: TextStyle(color: context.secondaryTextColor),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(myStoriesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stories) {
          if (stories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 48,
                    color: context.tertiaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  TypographyText(
                    'No stories yet',
                    variant: TypographyVariant.body1,
                    color: context.secondaryTextColor,
                  ),
                  const SizedBox(height: 4),
                  TypographyText(
                    'Create your first story to get started',
                    variant: TypographyVariant.body2,
                    color: context.tertiaryTextColor,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myStoriesProvider.future),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              itemCount: stories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final story = stories[index];
                return CommunityStoryCard(
                  story: story,
                  showStatus: true,
                  onTap: () {
                    final status = story.moderationStatus;
                    if (status == 'pending' ||
                        status == 'rejected' ||
                        status == 'pending_update') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StoryEditorPage(storyId: story.id),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StoryPreviewPage(
                            storyId: story.id,
                            storyTitle: story.title,
                            riveElement: story.riveElement,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
