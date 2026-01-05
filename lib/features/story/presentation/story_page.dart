import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/features/story/models/story_models.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/features/story/presentation/story_page_shimmer.dart';
import 'package:antroph_mobile/widgets/empty_state.dart';
import 'package:antroph_mobile/features/home/presentation/chat_page.dart';

class StoryPage extends ConsumerWidget {
  const StoryPage({super.key});

  static const _bg = Color(0xFF121516);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(storiesHomeSectionsProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            asyncHome.when(
              loading: () => const StoryPageShimmer(),
              error: (err, st) {
                final msg = err is ApiError ? err.message : 'Failed to load stories.';
                return _ErrorView(
                  message: msg,
                  onRetry: () => ref.refresh(storiesHomeSectionsProvider.future),
                );
              },
              data: (data) {
                final sections = data.sections;
                final featuredStory = data.featuredStory;
                if (sections.isEmpty && featuredStory == null) return const _EmptyView();

                return RefreshIndicator.adaptive(
                  color: Colors.white,
                  backgroundColor: _bg,
                  onRefresh: () => ref.refresh(storiesHomeSectionsProvider.future),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Row(
                            children: [
                              Image.asset('assets/images/app_logo.png', width: 38, height: 38),
                              const SizedBox(width: 2),
                              const TypographyText(
                                'Stories',
                                variant: TypographyVariant.h3,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (featuredStory != null)
                        SliverToBoxAdapter(
                          child: _FeaturedStoryCard(
                            story: featuredStory,
                            onTap: () => _openFeaturedStory(context, featuredStory),
                          ),
                        ),
                      for (final section in sections)
                        _SectionSliver(
                          section: section,
                          onTap: (card) => _openStory(context, card),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStory(BuildContext context, StoryCardDto card) async {
    await showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder: (_) => StorySheet(
        storyId: card.storyId,
        title: card.title,
        subtitle: card.subtitle,
        imageAsset: card.image,
        users: card.users,
        views: card.views,
      ),
    );
  }

  Future<void> _openFeaturedStory(BuildContext context, FeaturedStoryDto story) async {
    await showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder: (_) => StorySheet(
        storyId: story.id,
        title: story.title,
        subtitle: story.description,
        imageAsset: story.coverImageUrl,
        users: 0,
        views: 0,
      ),
    );
  }
}

class _FeaturedStoryCard extends ConsumerStatefulWidget {
  const _FeaturedStoryCard({required this.story, required this.onTap});

  final FeaturedStoryDto story;
  final VoidCallback onTap;

  @override
  ConsumerState<_FeaturedStoryCard> createState() => _FeaturedStoryCardState();
}

class _FeaturedStoryCardState extends ConsumerState<_FeaturedStoryCard> {
  late bool _isAdded = widget.story.isAdded;
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 8, 30, 24),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SmoothClipRRect(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
          child: AspectRatio(
            aspectRatio: 0.85,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                _StoryImage(image: widget.story.coverImageUrl),
                // Modern gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // Content at bottom
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TypographyText(
                        widget.story.title,
                        variant: TypographyVariant.h2,
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 10),
                      if (widget.story.description.isNotEmpty)
                        TypographyText(
                          widget.story.description,
                          variant: TypographyVariant.body1,
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          maxLines: 2,
                        ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _isAdding
                            ? null
                            : _isAdded
                            ? () {
                                HapticFeedback.mediumImpact();
                                _navigateToChat();
                              }
                            : () {
                                HapticFeedback.mediumImpact();
                                _handleAddToPlaylist();
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: _isAdding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CupertinoActivityIndicator(radius: 10),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isAdded ? CupertinoIcons.play_fill : CupertinoIcons.add,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    TypographyText(
                                      _isAdded ? 'Play' : 'My List',
                                      variant: TypographyVariant.body1,
                                      color: Colors.black,
                                      fontSize: 16,
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
      ),
    );
  }

  Future<void> _handleAddToPlaylist() async {
    if (_isAdding || _isAdded) return;
    setState(() => _isAdding = true);
    try {
      await ref.read(storiesRepositoryProvider).addStoriesToPlaylist(storyIds: [widget.story.id]);
      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _isAdded = true;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add story: $err')));
    }
  }

  void _navigateToChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(storyTitle: widget.story.title.isNotEmpty ? widget.story.title : 'Chat'),
      ),
    );
  }
}

class _SectionSliver extends StatelessWidget {
  const _SectionSliver({required this.section, required this.onTap});

  final StorySectionDto section;
  final Future<void> Function(StoryCardDto) onTap;
  static const double _sectionHeight = 220;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: _sectionHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            _SideLabel(text: section.title),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(right: 10),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = section.items[index];
                  return _StoryCard(item: item, onTap: () => onTap(item));
                },
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemCount: section.items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Opacity(
        opacity: 0.8,
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(left: 100.0),
            child: TypographyText(
              text,
              variant: TypographyVariant.body1,
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends ConsumerStatefulWidget {
  const _StoryCard({required this.item, required this.onTap});

  final StoryCardDto item;
  final VoidCallback onTap;

  @override
  ConsumerState<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends ConsumerState<_StoryCard> {
  bool _isAdding = false;
  bool _isAdded = false;

  @override
  Widget build(BuildContext context) {
    const cardRadius = 16.0;
    final item = widget.item;
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 125,
        child: Column(
          children: [
            // Card visual
            SmoothClipRRect(
              smoothness: 0.6,
              borderRadius: BorderRadius.circular(cardRadius),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
              child: AspectRatio(
                aspectRatio: 0.8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(child: _StoryImage(image: item.image)),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: GestureDetector(
                        onTap: _isAdding
                            ? null
                            : _isAdded
                            ? () {
                                HapticFeedback.lightImpact();
                                _navigateToChat();
                              }
                            : () {
                                HapticFeedback.lightImpact();
                                _handleAddToPlaylist();
                              },
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _isAdding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CupertinoActivityIndicator(radius: 9),
                                  )
                                : _isAdded
                                ? const Icon(
                                    CupertinoIcons.play_fill,
                                    size: 18,
                                    color: Colors.black,
                                  )
                                : const Icon(CupertinoIcons.add, size: 18, color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TypographyText(
                    item.title,
                    variant: TypographyVariant.body1,
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddToPlaylist() async {
    if (_isAdding || _isAdded) return;
    setState(() => _isAdding = true);
    try {
      await ref
          .read(storiesRepositoryProvider)
          .addStoriesToPlaylist(storyIds: [widget.item.storyId]);
      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _isAdded = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Story added to playlist')));
    } catch (err) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add story: $err')));
    }
  }

  void _navigateToChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(storyTitle: widget.item.title.isNotEmpty ? widget.item.title : 'Chat'),
      ),
    );
  }
}

class _StoryImage extends StatelessWidget {
  const _StoryImage({required this.image});
  final String image;
  bool get _isNetwork => image.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset('assets/images/default.png', fit: BoxFit.cover);
        },
      );
    }
    // Fallback to asset path from API examples or local assets
    final assetPath = image.isNotEmpty ? image : 'assets/images/default.png';
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset('assets/images/default.png', fit: BoxFit.cover);
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'No stories available yet',
      description: 'Check back later so you don\'t miss new releases.',
      assetPath: 'assets/images/antroph_happy.png',
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: message,
      description: 'Tap below to try again.',
      assetPath: 'assets/images/antroph_surprised.png',
      actionLabel: 'Retry',
      onAction: () => onRetry(),
    );
  }
}
