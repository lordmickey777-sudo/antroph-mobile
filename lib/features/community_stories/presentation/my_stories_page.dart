import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';

import '../models/community_story_model.dart';
import '../providers/community_stories_providers.dart';
import '../widgets/community_story_grid_card.dart';
import 'story_editor_page.dart';
import 'story_form_page.dart';
import 'story_preview_page.dart';

class MyStoriesPage extends ConsumerStatefulWidget {
  const MyStoriesPage({super.key});

  @override
  ConsumerState<MyStoriesPage> createState() => _MyStoriesPageState();
}

class _MyStoriesPageState extends ConsumerState<MyStoriesPage> {
  bool _deleting = false;

  bool _canDelete(CommunityStoryDto story) {
    final status = story.moderationStatus;
    return status == 'pending' ||
        status == 'rejected' ||
        status == 'pending_update';
  }

  Future<void> _confirmDelete(CommunityStoryDto story) async {
    await showAppActionSheet(
      context: context,
      title: 'Delete Story',
      actions: [
        AppActionSheetItem(
          label: 'Delete "${story.title}"',
          icon: CupertinoIcons.trash,
          isDestructive: true,
          onTap: () => _executeDelete(story),
        ),
      ],
    );
  }

  Future<void> _executeDelete(CommunityStoryDto story) async {
    if (_deleting) return;
    setState(() => _deleting = true);

    try {
      final repo = ref.read(communityStoriesRepositoryProvider);
      await repo.deleteStory(story.id);
      ref.invalidate(myStoriesProvider);
      if (mounted) {
        showToast(context, 'Story deleted', success: true);
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiError ? e.message : e.toString();
        showToast(context, 'Failed to delete story: $message', success: false);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _navigateToStory(CommunityStoryDto story) {
    final status = story.moderationStatus;
    if (status == 'pending' ||
        status == 'rejected' ||
        status == 'pending_update') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoryEditorPage(storyId: story.id)),
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
  }

  @override
  Widget build(BuildContext context) {
    final asyncStories = ref.watch(myStoriesProvider);
    final horizontalPadding = AppPadding.horizontal.of(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TypographyText(
          'My Stories',
          variant: TypographyVariant.h4,
          color: context.primaryTextColor,
        ),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: context.primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.primaryTextColor),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final result = await showAuthGuardSheet(
                context,
                ref,
                actionDescription: 'Create a new story',
              );
              if (!context.mounted) return;
              if (result == AuthGuardResult.authenticated ||
                  result == AuthGuardResult.loginSuccessful) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoryFormPage()),
                );
              }
            },
          ),
        ],
      ),
      body: asyncStories.when(
        loading: () => _buildGridShimmer(context, horizontalPadding),
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
            child: GridView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return CommunityStoryGridCard(
                  story: story,
                  onTap: () => _navigateToStory(story),
                  onLongPress: _canDelete(story)
                      ? () => _confirmDelete(story)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridShimmer(BuildContext context, double horizontalPadding) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return ShimmerLoadingPage(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => SmoothClipRRect(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 0.5),
          child: Container(
            color: context.cardBackground,
            child: Column(
              children: [
                const Expanded(
                  child: ShimmerBox(
                    radius: 0,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerText(height: 14),
                      SizedBox(height: 4),
                      ShimmerBox(width: 60, height: 11, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
