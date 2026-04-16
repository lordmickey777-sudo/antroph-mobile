import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/premium_star.dart';
import 'package:antroph_mobile/widgets/smooth_card.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/models/story_models.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/features/story/presentation/story_page_shimmer.dart';
import 'package:antroph_mobile/widgets/empty_state.dart';
import 'package:antroph_mobile/widgets/app_action_button.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/features/home/presentation/chat_page.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/widgets/scroll_fade_gradient.dart';
import 'package:antroph_mobile/features/community_stories/providers/community_stories_providers.dart';
import 'package:antroph_mobile/features/community_stories/models/community_story_model.dart';
import 'package:antroph_mobile/features/community_stories/presentation/community_browse_page.dart';

class StoryPage extends ConsumerWidget {
  const StoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(storiesHomeSectionsProvider);
    final asyncContinue = ref.watch(continuePlayingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF141718)
          : const Color(0xFFF5F5F7),
      body: asyncHome.when(
        loading: () => const StoryPageShimmer(),
        error: (err, st) {
          final msg = err is ApiError ? err.message : 'Failed to load stories.';
          return _ErrorView(
            message: msg,
            onRetry: () async {
              ref.invalidate(continuePlayingProvider);
              final refreshed = ref.refresh(storiesHomeSectionsProvider.future);
              await refreshed;
            },
          );
        },
        data: (data) {
          final sections = data.sections;
          final featuredStories = data.featuredStories;
          final continueStories =
              asyncContinue.asData?.value ?? const <ContinuePlayingDto>[];
          if (sections.isEmpty &&
              featuredStories.isEmpty &&
              continueStories.isEmpty) {
            return _EmptyView(
              onRefresh: () async {
                ref.invalidate(continuePlayingProvider);
                final refreshed = ref.refresh(
                  storiesHomeSectionsProvider.future,
                );
                await refreshed;
              },
            );
          }

          return ScrollFadeGradient(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/app_logo.png',
                            width: 38,
                            height: 38,
                          ),
                          const SizedBox(width: 2),
                          TypographyText(
                            'Stories',
                            variant: TypographyVariant.h3,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                CupertinoSliverRefreshControl(
                  onRefresh: () async {
                    ref.invalidate(continuePlayingProvider);
                    final refreshed = ref.refresh(
                      storiesHomeSectionsProvider.future,
                    );
                    await refreshed;
                  },
                ),
                if (continueStories.isNotEmpty)
                  _ContinuePlayingSliver(
                    stories: continueStories,
                    onTap: (story) => _resumeStory(context, ref, story),
                  ),
                if (featuredStories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _FeaturedStoriesCarousel(
                      stories: featuredStories,
                      onTap: (story) => _playFeaturedStory(context, ref, story),
                    ),
                  ),
                for (final section in sections)
                  _SectionSliver(
                    section: section,
                    onTap: (card) => _playStoryCard(context, ref, card),
                  ),
                _CommunityStoriesSliver(),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _playStoryCard(
    BuildContext context,
    WidgetRef ref,
    StoryCardDto card,
  ) async {
    _openStorySheet(
      context,
      storyId: card.storyId,
      title: card.title,
      subtitle: card.subtitle,
      image: card.image,
      mascotConfig: card.mascotConfig,
      isAdded: card.isAdded,
      isPremium: card.isPremium,
    );
  }

  Future<void> _playFeaturedStory(
    BuildContext context,
    WidgetRef ref,
    FeaturedStoryDto story,
  ) async {
    _openStorySheet(
      context,
      storyId: story.id,
      title: story.title,
      subtitle: story.description,
      image: story.coverImageUrl,
      mascotConfig: story.mascotConfig,
      isAdded: story.isAdded,
      isPremium: story.isPremium,
    );
  }

  void _openStorySheet(
    BuildContext context, {
    required String storyId,
    required String title,
    required String subtitle,
    required String image,
    MascotConfig? mascotConfig,
    bool isAdded = false,
    bool isPremium = false,
  }) {
    showAppBottomSheet(
      context: context,
      builder: (_, scrollController) => StorySheetContent(
        storyId: storyId,
        title: title,
        subtitle: subtitle,
        imageAsset: image.isNotEmpty ? image : 'assets/images/default.png',
        mascotConfig: mascotConfig,
        isAdded: isAdded,
        isPremium: isPremium,
        scrollController: scrollController,
      ),
    );
  }

  Future<void> _resumeStory(
    BuildContext context,
    WidgetRef ref,
    ContinuePlayingDto story,
  ) async {
    await _startStory(
      context,
      ref,
      storyId: story.storyId,
      storySessionId: story.sessionId,
      title: story.title,
      subtitle: story.description,
      image: story.coverImageUrl,
    );
  }

  Future<void> _startStory(
    BuildContext context,
    WidgetRef ref, {
    required String storyId,
    required String title,
    String? storySessionId,
    String? subtitle,
    String? image,
    MascotConfig? mascotConfig,
    bool isAddedToPlaylist = false,
  }) async {
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
          storyTitle: title.isNotEmpty ? title : 'Chat',
          storyId: storyId,
          storySessionId: storySessionId,
          storySubtitle: subtitle,
          storyImage: image,
          mascotConfig: mascotConfig,
          isAddedToPlaylist: isAddedToPlaylist,
        ),
      ),
    );
  }
}

class _FeaturedStoryCard extends StatelessWidget {
  const _FeaturedStoryCard({
    required this.story,
    required this.onTap,
    this.textOpacity = 1.0,
  });

  final FeaturedStoryDto story;
  final VoidCallback onTap;
  final double textOpacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: GestureDetector(
        onTap: onTap,
        child: SmoothCard(
          radius: 36,
          child: AspectRatio(
            aspectRatio: 0.85,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                _StoryImage(image: story.coverImageUrl),
                // Modern gradient overlay
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
                if (story.isPremium)
                  const Positioned(
                    top: 16,
                    right: 16,
                    child: PremiumStar(size: 24),
                  ),
                // Content at bottom
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Opacity(
                    opacity: textOpacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TypographyText(
                          story.title,
                          variant: TypographyVariant.h2,
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        const SizedBox(height: 10),
                        if (story.description.isNotEmpty)
                          TypographyText(
                            story.description,
                            variant: TypographyVariant.body1,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            maxLines: 2,
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.play_fill,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 8),
                              TypographyText(
                                'Tap to start',
                                variant: TypographyVariant.body2,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _FeaturedStoriesCarousel extends StatefulWidget {
  const _FeaturedStoriesCarousel({required this.stories, required this.onTap});

  final List<FeaturedStoryDto> stories;
  final void Function(FeaturedStoryDto story) onTap;

  @override
  State<_FeaturedStoriesCarousel> createState() =>
      _FeaturedStoriesCarouselState();
}

class _FeaturedStoriesCarouselState extends State<_FeaturedStoriesCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoAdvanceTimer();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvanceTimer() {
    _autoAdvanceTimer?.cancel();
    if (widget.stories.length <= 1) return;
    _autoAdvanceTimer = Timer(const Duration(seconds: 5), _advanceToNextPage);
  }

  void _advanceToNextPage() {
    if (!mounted) return;
    final nextPage = (_currentPage + 1) % widget.stories.length;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    _startAutoAdvanceTimer();
  }

  void _onUserInteraction() {
    _startAutoAdvanceTimer();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppPadding.large.of(context);

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.width * 1.1,
          child: AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              return GestureDetector(
                onPanDown: (_) => _onUserInteraction(),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _onUserInteraction();
                  },
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.stories.length,
                  itemBuilder: (context, index) {
                    final story = widget.stories[index];

                    // Calculate text opacity based on how centered this card is
                    double textOpacity = 1.0;
                    if (_pageController.position.haveDimensions) {
                      final page =
                          _pageController.page ?? _currentPage.toDouble();
                      final distance = (page - index).abs();
                      // Fade out quickly as we scroll away (opacity goes from 1 to 0 as distance goes from 0 to 0.5)
                      textOpacity = (1.0 - (distance * 2)).clamp(0.0, 1.0);
                    }

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding * 0.1,
                      ),
                      child: _FeaturedStoryCard(
                        story: story,
                        onTap: () => widget.onTap(story),
                        textOpacity: textOpacity,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (widget.stories.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.stories.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87)
                        : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionSliver extends StatelessWidget {
  const _SectionSliver({required this.section, required this.onTap});

  final StorySectionDto section;
  final Future<void> Function(StoryCardDto) onTap;
  static const double _cardListHeight = 170;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: TypographyText(
              section.title,
              variant: TypographyVariant.body1,
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            height: _cardListHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = section.items[index];
                return _StoryCard(item: item, onTap: () => onTap(item));
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: section.items.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinuePlayingSliver extends StatelessWidget {
  const _ContinuePlayingSliver({required this.stories, required this.onTap});

  final List<ContinuePlayingDto> stories;
  final Future<void> Function(ContinuePlayingDto story) onTap;
  static const double _cardListHeight = 190;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: TypographyText(
              'Continue Listening',
              variant: TypographyVariant.body1,
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            height: _cardListHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = stories[index];
                return _ContinueStoryCard(item: item, onTap: () => onTap(item));
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: stories.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.item, required this.onTap});

  final StoryCardDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 125,
        child: SmoothCard(
          radius: 24,
          child: AspectRatio(
            aspectRatio: 0.75,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: _StoryImage(image: item.image)),
                // Gradient overlay for title readability
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                // Title at bottom left
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: TypographyText(
                    item.title,
                    variant: TypographyVariant.body1,
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    maxLines: 2,
                  ),
                ),
                if (item.isPremium)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: PremiumStar(size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueStoryCard extends StatelessWidget {
  const _ContinueStoryCard({required this.item, required this.onTap});

  final ContinuePlayingDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = item.progressPercentage.clamp(0, 100).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: SmoothCard(
          radius: 26,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _StoryImage(image: item.coverImageUrl)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.28, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TypographyText(
                    '${progress.round()}%',
                    variant: TypographyVariant.body2,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypographyText(
                      item.title,
                      variant: TypographyVariant.body1,
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
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

class _StoryImage extends StatelessWidget {
  const _StoryImage({required this.image});
  final String image;
  bool get _isNetwork => image.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return _StoryImageShimmer(
        child: Image.network(
          image,
          fit: BoxFit.cover,
          frameBuilder: _frameBuilder,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset('assets/images/default.png', fit: BoxFit.cover);
          },
        ),
      );
    }
    // Fallback to asset path from API examples or local assets
    final assetPath = image.isNotEmpty ? image : 'assets/images/default.png';
    return _StoryImageShimmer(
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        frameBuilder: _frameBuilder,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset('assets/images/default.png', fit: BoxFit.cover);
        },
      ),
    );
  }

  Widget _frameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: child,
    );
  }
}

class _StoryImageShimmer extends StatelessWidget {
  const _StoryImageShimmer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [const ShimmerBox(radius: 0), child],
    );
  }
}

class _CommunityStoriesSliver extends ConsumerWidget {
  const _CommunityStoriesSliver();

  static const double _cardWidth = 200;
  static const double _cardHeight = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncCommunity = ref.watch(communityBrowseProvider(null));

    return asyncCommunity.when(
      loading: () =>
          const SliverToBoxAdapter(child: _CommunityStoriesSliverShimmer()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (stories) {
        if (stories.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TypographyText(
                      'Community Stories',
                      variant: TypographyVariant.body1,
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CommunityBrowsePage(),
                        ),
                      ),
                      child: TypographyText(
                        'See All',
                        variant: TypographyVariant.body2,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _cardHeight,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: stories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    return _CommunityStoryCompactCard(
                      story: story,
                      width: _cardWidth,
                      isDark: isDark,
                      onTap: () => _openCommunityStory(context, story),
                      onPlay: () => _playCommunityStory(context, ref, story),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _playCommunityStory(
    BuildContext context,
    WidgetRef ref,
    CommunityStoryDto story,
  ) async {
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Start a story session',
    );
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          storyTitle: story.title.isNotEmpty ? story.title : 'Chat',
          storyId: story.id,
        ),
      ),
    );
  }

  void _openCommunityStory(BuildContext context, CommunityStoryDto story) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showAppBottomSheet(
      context: context,
      builder: (context, scrollController) => CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child:
                        story.coverImageUrl != null &&
                            story.coverImageUrl!.isNotEmpty
                        ? Image.network(
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
                          )
                        : Image.asset(
                            'assets/images/default.png',
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    story.title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (story.creatorName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'by ${story.creatorName}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (story.description != null &&
                      story.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      story.description!,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (story.themes.isNotEmpty) ...[
                    const SizedBox(height: 16),
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
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Consumer(
                    builder: (ctx, ref, _) {
                      return AppPillButton(
                        onPressed: () => _playCommunityStory(ctx, ref, story),
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
      ),
    );
  }
}

class _CommunityStoriesSliverShimmer extends StatelessWidget {
  const _CommunityStoriesSliverShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: ShimmerBox(width: 180, height: 20, radius: 6),
        ),
        SizedBox(
          height: _CommunityStoriesSliver._cardHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                StoryCardShimmer(width: _CommunityStoriesSliver._cardWidth),
                SizedBox(width: 12),
                StoryCardShimmer(width: _CommunityStoriesSliver._cardWidth),
                SizedBox(width: 12),
                StoryCardShimmer(width: _CommunityStoriesSliver._cardWidth),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommunityStoryCompactCard extends StatelessWidget {
  const _CommunityStoryCompactCard({
    required this.story,
    required this.width,
    required this.isDark,
    required this.onTap,
    this.onPlay,
  });

  final CommunityStoryDto story;
  final double width;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  Widget _buildCoverImage() {
    final coverUrl = story.coverImageUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Image.network(
        coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/images/default.png', fit: BoxFit.cover),
      );
    }
    final thumb = story.riveElement?.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty && thumb.startsWith('http')) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/images/default.png', fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/images/default.png', fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: SmoothCard(
          radius: 24,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover image (fallback to rive thumbnail, then default asset)
              _buildCoverImage(),

              // Gradient overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Title + author
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (story.creatorName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        story.creatorName!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Play button
              if (onPlay != null)
                Positioned(
                  right: 6,
                  top: 6,
                  child: AppCircleIconButton(
                    onPressed: onPlay,
                    icon: CupertinoIcons.play_fill,
                    size: 34,
                    iconSize: 18,
                    backgroundColor: context.actionButtonBackground,
                    foregroundColor: context.actionButtonForeground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
        const SliverFillRemaining(
          child: EmptyState(
            title: 'No stories available yet',
            description: 'Check back later so you don\'t miss new releases.',
            assetPath: 'assets/images/antroph_happy.png',
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRetry),
        SliverFillRemaining(
          child: EmptyState(
            title: message,
            description: 'Tap below to try again.',
            assetPath: 'assets/images/antroph_surprised.png',
            actionLabel: 'Retry',
            onAction: () => onRetry(),
          ),
        ),
      ],
    );
  }
}
