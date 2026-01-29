import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/widgets/empty_state.dart';
import 'package:antroph_mobile/features/home/presentation/chat_page.dart';
import 'package:antroph_mobile/features/story/models/story_playlists_models.dart';
import 'package:antroph_mobile/features/story/presentation/story_player_page.dart';
import '../providers/story_playlists_provider.dart';
import '../providers/story_providers.dart';
import '../data/stories_cache.dart';

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(storyPlaylistsProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const TypographyText(
          'My collections',
          variant: TypographyVariant.h2,
          color: Colors.white,
        ),
      ),
      body: collections.when(
        loading: () => const CollectionsPageShimmer(),
        error: (err, st) => _PageError(
          message: 'Unable to load collections.',
          onRetry: () => ref.refresh(storyPlaylistsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              title: 'No collections yet',
              description:
                  'Keep an eye out for curated series coming your way.',
              assetPath: 'assets/images/antroph_smile.png',
            );
          }
          final horizontalPadding = AppPadding.horizontal.of(context);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentWidth.content),
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: horizontalPadding),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
              final collection = items[index];
              return _CollectionCard(
                  collection: collection,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CollectionDetailPage(collection: collection),
                    ),
                  ),
                  onStartChat: () => _startChatForCollection(context, ref, collection),
                  onRemove: () =>
                      _removeCollectionStories(context, ref, collection),
                );
              },
            ),
          ),
        );
        },
      ),
    );
  }

  Future<void> _startChatForCollection(
    BuildContext context,
    WidgetRef ref,
    PlaylistDto collection,
  ) async {
    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Start a story session',
    );
    if (!context.mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    // Use the collection id as the story id since each playlist item is a story
    final storyId = collection.id;
    if (storyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start story'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          storyTitle: collection.name.isNotEmpty ? collection.name : 'Chat',
          storyId: storyId,
        ),
      ),
    );
  }

  Future<void> _removeCollectionStories(
    BuildContext context,
    WidgetRef ref,
    PlaylistDto collection,
  ) async {
    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Remove stories from collection',
    );
    if (!context.mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    final id = collection.id;
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stories to remove'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }
    final repo = ref.read(storiesRepositoryProvider);
    try {
      // Optimistically refresh to remove it from UI quickly.
      ref.invalidate(storyPlaylistsProvider);
      await StoriesCacheService.clear();
      ref.invalidate(storiesHomeSectionsProvider);
      await repo.removeStoriesFromCollection(storyIds: [id]);
      ref.invalidate(storyPlaylistsProvider);
      await StoriesCacheService.clear();
      ref.invalidate(storiesHomeSectionsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove stories'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class CollectionDetailPage extends ConsumerWidget {
  const CollectionDetailPage({super.key, required this.collection});

  final PlaylistDto collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(playlistDetailProvider(collection.id));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TypographyText(
          collection.name,
          variant: TypographyVariant.h2,
          color: Colors.white,
        ),
      ),
      body: asyncDetail.when(
        loading: () => const Center(
          child: CupertinoActivityIndicator(color: Colors.white),
        ),
        error: (err, st) => _PageError(
          message: 'Unable to load stories for this collection.',
          onRetry: () => ref.refresh(playlistDetailProvider(collection.id)),
        ),
        data: (detail) {
          if (detail.stories.isEmpty) {
            return const EmptyState(
              title: 'Nothing to show yet',
              description:
                  'This collection does not have stories ready for play.',
              assetPath: 'assets/images/antroph_neutral.png',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: detail.stories.length,
            itemBuilder: (context, index) {
              final story = detail.stories[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CollectionStoryCard(
                  story: story,
                  onPlay: () => _startStory(context, ref, story),
                  onStartChat: () => _startChatForStory(context, ref, story),
                  onRemove: () =>
                      _removeStoryFromCollection(context, ref, story),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startStory(
    BuildContext context,
    WidgetRef ref,
    PlaylistStoryDto story,
  ) async {
    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Start a story session',
    );
    if (!context.mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StoryPlayerPage(story: story)));
  }

  Future<void> _startChatForStory(
    BuildContext context,
    WidgetRef ref,
    PlaylistStoryDto story,
  ) async {
    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Start a story session',
    );
    if (!context.mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          storyTitle: story.title.isNotEmpty ? story.title : 'Chat',
          storyId: story.storyId,
        ),
      ),
    );
  }

  Future<void> _removeStoryFromCollection(
    BuildContext context,
    WidgetRef ref,
    PlaylistStoryDto story,
  ) async {
    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Remove story from collection',
    );
    if (!context.mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    final repo = ref.read(storiesRepositoryProvider);
    try {
      await repo.removeStoriesFromCollection(storyIds: [story.storyId]);
      ref.invalidate(playlistDetailProvider(collection.id));
      ref.invalidate(storyPlaylistsProvider);
      await StoriesCacheService.clear();
      ref.invalidate(storiesHomeSectionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story removed from collection'),
            backgroundColor: Color(0xFF2A2A2A),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove story'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onStartChat,
    required this.onRemove,
  });

  final PlaylistDto collection;
  final VoidCallback onTap;
  final VoidCallback onStartChat;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onStartChat,
      child: SmoothClipRRect(
        smoothness: 0.6,
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
        child: AspectRatio(
          aspectRatio: 1.4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              _CollectionImage(url: collection.coverImageUrl),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _StyledPopupMenu(
                  onRemove: onRemove,
                  removeLabel: 'Remove from collection',
                ),
              ),
              // Content at bottom
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypographyText(
                      collection.name,
                      variant: TypographyVariant.h3,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onStartChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              CupertinoIcons.play_fill,
                              color: Colors.black,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            TypographyText(
                              'Start story',
                              variant: TypographyVariant.body1,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionStoryCard extends StatelessWidget {
  const _CollectionStoryCard({
    required this.story,
    required this.onPlay,
    required this.onStartChat,
    required this.onRemove,
  });

  final PlaylistStoryDto story;
  final VoidCallback onPlay;
  final VoidCallback onStartChat;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: SmoothClipRRect(
        smoothness: 0.6,
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
        child: AspectRatio(
          aspectRatio: 1.4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              _CollectionImage(url: story.imageUrl),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // More options menu at top right
              Positioned(
                top: 8,
                right: 8,
                child: _StyledPopupMenu(
                  onRemove: onRemove,
                  removeLabel: 'Remove from collection',
                ),
              ),
              // Content at bottom
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypographyText(
                      story.title,
                      variant: TypographyVariant.h3,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    if (story.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      TypographyText(
                        story.subtitle,
                        variant: TypographyVariant.body2,
                        color: Colors.white.withValues(alpha: 0.85),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onPlay,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  CupertinoIcons.play_fill,
                                  color: Colors.black,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                TypographyText(
                                  'Play',
                                  variant: TypographyVariant.body1,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: onStartChat,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  CupertinoIcons.chat_bubble_2_fill,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                TypographyText(
                                  'Chat',
                                  variant: TypographyVariant.body1,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionImage extends StatelessWidget {
  const _CollectionImage({required this.url});

  final String url;

  bool get _isNetwork => url.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/default.png',
            fit: BoxFit.cover,
            width: double.infinity,
          );
        },
      );
    }
    final assetPath = url.isNotEmpty ? url : 'assets/images/default.png';
    return Image.asset(assetPath, fit: BoxFit.cover, width: double.infinity);
  }
}

class _StyledPopupMenu extends StatelessWidget {
  const _StyledPopupMenu({required this.onRemove, required this.removeLabel});

  final Future<void> Function() onRemove;
  final String removeLabel;

  Future<void> _showActionsSheet(BuildContext context) async {
    await showAppActionSheet(
      context: context,
      actions: [
        AppActionSheetItem(
          label: removeLabel,
          icon: CupertinoIcons.trash,
          isDestructive: true,
          onTap: () => onRemove(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showActionsSheet(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: message,
      description: 'Let\'s try again and refresh the list.',
      assetPath: 'assets/images/antroph_frown.png',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

class CollectionsPageShimmer extends StatelessWidget {
  const CollectionsPageShimmer({super.key, this.cards = 3});

  final int cards;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: cards,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => const _CollectionCardShimmer(),
    );
  }
}

class _CollectionCardShimmer extends StatelessWidget {
  const _CollectionCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(height: 160, child: ShimmerBox()),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 180, height: 18),
                SizedBox(height: 8),
                ShimmerBox(width: 220, height: 12),
                SizedBox(height: 4),
                ShimmerBox(width: 140, height: 12),
                SizedBox(height: 12),
                ShimmerBox(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
