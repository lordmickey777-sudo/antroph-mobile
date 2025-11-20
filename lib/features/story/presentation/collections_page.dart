import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/widgets/empty_state.dart';
import 'package:antroph_mobile/features/story/models/story_collections_models.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import '../providers/story_collections_provider.dart';

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(storyCollectionsProvider);
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
          onRetry: () => ref.refresh(storyCollectionsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
          return const EmptyState(
            title: 'No collections yet',
            description: 'Keep an eye out for curated series coming your way.',
            assetPath: 'assets/images/antroph_smile.png',
          );
          }
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final collection = items[index];
              return _CollectionCard(
                collection: collection,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CollectionDetailPage(collection: collection),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CollectionDetailPage extends ConsumerWidget {
  const CollectionDetailPage({super.key, required this.collection});

  final StoryCollectionDto collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(storyCollectionDetailProvider(collection.id));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TypographyText(collection.name, variant: TypographyVariant.h2, color: Colors.white),
      ),
      body: asyncDetail.when(
        loading: () => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
        error: (err, st) => _PageError(
          message: 'Unable to load stories for this collection.',
          onRetry: () => ref.refresh(storyCollectionDetailProvider(collection.id)),
        ),
        data: (detail) {
          if (detail.stories.isEmpty) {
          return const EmptyState(
            title: 'Nothing to show yet',
            description: 'This collection does not have stories ready for play.',
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
                  onPlay: () => _openStory(context, story),
                  onLeave: () => Navigator.of(context).pop(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openStory(BuildContext context, StoryCollectionStoryDto story) async {
    await showCupertinoModalBottomSheet(
      context: context,
      expand: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StorySheet(
        storyId: story.storyId,
        title: story.title,
        subtitle: story.subtitle,
        imageAsset: story.imageUrl.isNotEmpty ? story.imageUrl : 'assets/images/default.png',
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.onTap});

  final StoryCollectionDto collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _CollectionImage(url: collection.coverImageUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TypographyText(collection.name, variant: TypographyVariant.body1, color: Colors.white),
                  const SizedBox(height: 4),
                  TypographyText(
                    collection.description,
                    variant: TypographyVariant.body2,
                    color: Colors.white70,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.collections, size: 16, color: Colors.white60),
                      const SizedBox(width: 8),
                      TypographyText('${collection.storyCount} stories', variant: TypographyVariant.body2, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionStoryCard extends StatelessWidget {
  const _CollectionStoryCard({
    required this.story,
    required this.onPlay,
    required this.onLeave,
  });

  final StoryCollectionStoryDto story;
  final VoidCallback onPlay;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _CollectionImage(url: story.imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypographyText(story.title, variant: TypographyVariant.body1, color: Colors.white),
                const SizedBox(height: 4),
                TypographyText(
                  story.subtitle,
                  variant: TypographyVariant.body2,
                  color: Colors.white70,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        onPressed: onPlay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(CupertinoIcons.play_fill, size: 18),
                            SizedBox(width: 6),
                            TypographyText('Play', variant: TypographyVariant.body2, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        onPressed: onLeave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B7D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: TypographyText('Leave story', variant: TypographyVariant.body2, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
        height: 160,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset('assets/images/default.png', fit: BoxFit.cover, height: 160);
        },
      );
    }
    final assetPath = url.isNotEmpty ? url : 'assets/images/default.png';
    return Image.asset(assetPath, fit: BoxFit.cover, height: 160);
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
            child: SizedBox(
              height: 160,
              child: ShimmerBox(),
            ),
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
