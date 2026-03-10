import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';

import '../models/community_story_model.dart';
import '../providers/community_stories_providers.dart';
import '../widgets/community_story_card.dart';
import '../widgets/community_story_list_shimmer.dart';
import 'story_editor_page.dart';
import 'story_preview_page.dart';

class MyStoriesPage extends ConsumerStatefulWidget {
  const MyStoriesPage({super.key});

  @override
  ConsumerState<MyStoriesPage> createState() => _MyStoriesPageState();
}

class _MyStoriesPageState extends ConsumerState<MyStoriesPage> {
  final _listKey = GlobalKey<AnimatedListState>();
  List<CommunityStoryDto>? _stories;
  bool _deleting = false;

  void _syncStories(List<CommunityStoryDto> fresh) {
    if (_stories == null) {
      _stories = List.of(fresh);
      return;
    }
    // Only reset if the upstream list changed (e.g. pull-to-refresh).
    if (_stories!.length != fresh.length ||
        !_stories!.every((s) => fresh.any((f) => f.id == s.id))) {
      _stories = List.of(fresh);
    }
  }

  bool _canDelete(CommunityStoryDto story) {
    final status = story.moderationStatus;
    return status == 'pending' || status == 'rejected' || status == 'pending_update';
  }

  Future<void> _confirmDelete(CommunityStoryDto story, int index) async {
    await showAppActionSheet(
      context: context,
      title: 'Delete Story',
      actions: [
        AppActionSheetItem(
          label: 'Delete "${story.title}"',
          icon: CupertinoIcons.trash,
          isDestructive: true,
          onTap: () => _executeDelete(story, index),
        ),
      ],
    );
  }

  Future<void> _executeDelete(CommunityStoryDto story, int index) async {
    if (_deleting) return;
    setState(() => _deleting = true);

    try {
      final repo = ref.read(communityStoriesRepositoryProvider);
      await repo.deleteStory(story.id);

      // Animate removal from list.
      final removed = _stories!.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildRemovedCard(removed, animation),
        duration: const Duration(milliseconds: 350),
      );

      ref.invalidate(myStoriesProvider);
      if (mounted) {
        showToast(context, 'Story deleted', success: true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), success: false);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _buildRemovedCard(CommunityStoryDto story, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: CommunityStoryCard(
            story: story,
            showStatus: true,
            compact: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        loading: () => const CommunityStoryListShimmer(showStatus: true, compact: true),
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
                onPressed: () {
                  _stories = null;
                  ref.invalidate(myStoriesProvider);
                },
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

          _syncStories(stories);

          return RefreshIndicator(
            onRefresh: () async {
              _stories = null;
              return ref.refresh(myStoriesProvider.future);
            },
            child: AnimatedList(
              key: _listKey,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              initialItemCount: _stories!.length,
              itemBuilder: (context, index, animation) {
                if (index >= _stories!.length) return const SizedBox.shrink();
                final story = _stories![index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: CommunityStoryCard(
                    story: story,
                    showStatus: true,
                    compact: true,
                    onTap: () => _navigateToStory(story),
                    onLongPress: _canDelete(story)
                        ? () => _confirmDelete(story, index)
                        : null,
                    trailing: _canDelete(story)
                        ? IconButton(
                            icon: Icon(
                              CupertinoIcons.ellipsis_vertical,
                              color: context.tertiaryTextColor,
                              size: 18,
                            ),
                            onPressed: () => _confirmDelete(story, index),
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _navigateToStory(CommunityStoryDto story) {
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
  }
}
