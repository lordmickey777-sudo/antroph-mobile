import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/app_action_button.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/features/story/presentation/story_chat_flow_page.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';

import '../providers/community_stories_providers.dart';
import '../models/community_story_model.dart';
import '../widgets/community_story_grid_card.dart';
import '../widgets/community_story_list_shimmer.dart';

class CommunityBrowsePage extends ConsumerWidget {
  const CommunityBrowsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncStories = ref.watch(communityBrowseProvider(null));
    final horizontalPadding = AppPadding.horizontal.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF141718)
          : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TypographyText(
          'Community Stories',
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
        loading: () => const CommunityStoryListShimmer(showStatus: false),
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
                onPressed: () => ref.invalidate(communityBrowseProvider(null)),
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
                    Icons.explore_rounded,
                    size: 48,
                    color: context.tertiaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  TypographyText(
                    'No stories published yet',
                    variant: TypographyVariant.body1,
                    color: context.secondaryTextColor,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(communityBrowseProvider(null).future),
            child: GridView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return CommunityStoryGridCard(
                  story: story,
                  onTap: () => _showStoryDetail(context, story),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showStoryDetail(BuildContext context, CommunityStoryDto story) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showAppBottomSheet(
      context: context,
      builder: (context, scrollController) {
        return _CommunityStoryDetail(
          story: story,
          scrollController: scrollController,
          isDark: isDark,
        );
      },
    );
  }
}

class _CommunityStoryDetail extends StatelessWidget {
  const _CommunityStoryDetail({
    required this.story,
    required this.scrollController,
    required this.isDark,
  });

  final CommunityStoryDto story;
  final ScrollController scrollController;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                if (story.coverImageUrl != null &&
                    story.coverImageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      story.coverImageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/default.png',
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Title
                Text(
                  story.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                // Author
                if (story.creatorName != null)
                  Row(
                    children: [
                      if (story.creatorAvatarUrl != null)
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(
                            story.creatorAvatarUrl!,
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: chipBg,
                          child: Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: subtitleColor,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        'by ${story.creatorName}',
                        style: TextStyle(color: subtitleColor, fontSize: 14),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Description
                if (story.description != null && story.description!.isNotEmpty)
                  Text(
                    story.description!,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                const SizedBox(height: 16),

                // Themes
                if (story.themes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: story.themes
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),

                const SizedBox(height: 24),

                // Info row
                Row(
                  children: [
                    if (story.tone != null) ...[
                      Icon(Icons.mood_rounded, size: 16, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        story.tone!,
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (story.targetLength != null) ...[
                      Icon(
                        Icons.repeat_rounded,
                        size: 16,
                        color: subtitleColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${story.targetLength} turns',
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // Play button
                Consumer(
                  builder: (ctx, ref, _) {
                    return AppPillButton(
                      onPressed: () async {
                        var launchMode = InteractiveStoryLaunchMode.create;
                        String? joinCode;
                        if (story.interactionMode == 'group') {
                          final result = await showGroupGameLauncherSheet(ctx);
                          if (!ctx.mounted || result == null) return;
                          launchMode = result.mode;
                          joinCode = result.joinCode;
                        }
                        final authResult = await showAuthGuardSheet(
                          ctx,
                          ref,
                          actionDescription: 'Start a story session',
                        );
                        if (authResult != AuthGuardResult.authenticated &&
                            authResult != AuthGuardResult.loginSuccessful) {
                          return;
                        }
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => StoryChatFlowPage(
                              storyTitle: story.title.isNotEmpty
                                  ? story.title
                                  : 'Chat',
                              storyId: story.id,
                              storySubtitle: story.description,
                              storyImage: story.coverImageUrl,
                              initialInteractionMode: story.interactionMode,
                              interactiveLaunchMode: launchMode,
                              joinCode: joinCode,
                            ),
                          ),
                        );
                      },
                      icon: CupertinoIcons.play_fill,
                      label: 'Continue',
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 28,
                      ),
                      variant: TypographyVariant.body1,
                      fontWeight: FontWeight.w600,
                    );
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
