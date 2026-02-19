import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/features/story/models/story_models.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/features/story/data/stories_cache.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/features/story/presentation/story_page_shimmer.dart';
import 'package:antroph_mobile/widgets/empty_state.dart';
import 'package:antroph_mobile/widgets/app_action_button.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/features/home/presentation/chat_page.dart';
import 'package:antroph_mobile/widgets/scroll_fade_gradient.dart';
import 'package:antroph_mobile/features/community_stories/providers/community_stories_providers.dart';
import 'package:antroph_mobile/features/community_stories/models/community_story_model.dart';
import 'package:antroph_mobile/features/community_stories/presentation/community_browse_page.dart';

class StoryPage extends ConsumerWidget {
  const StoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(storiesHomeSectionsProvider);
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
            onRetry: () => ref.refresh(storiesHomeSectionsProvider.future),
          );
        },
        data: (data) {
          final sections = data.sections;
          final featuredStories = data.featuredStories;
          if (sections.isEmpty && featuredStories.isEmpty) {
            return const _EmptyView();
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
                  onRefresh: () =>
                      ref.refresh(storiesHomeSectionsProvider.future),
                ),
                if (featuredStories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _FeaturedStoriesCarousel(
                      stories: featuredStories,
                      onTap: (story) => _openFeaturedStory(context, story),
                    ),
                  ),
                for (final section in sections)
                  _SectionSliver(
                    section: section,
                    onTap: (card) => _openStory(context, card),
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

  Future<void> _openStory(BuildContext context, StoryCardDto card) async {
    await showAppBottomSheet(
      context: context,
      builder: (_, scrollController) => StorySheetContent(
        storyId: card.storyId,
        title: card.title,
        subtitle: card.subtitle,
        imageAsset: card.image,
        mascotConfig: card.mascotConfig,
        users: card.users,
        views: card.views,
        isAdded: card.isAdded,
        scrollController: scrollController,
      ),
    );
  }

  Future<void> _openFeaturedStory(
    BuildContext context,
    FeaturedStoryDto story,
  ) async {
    await showAppBottomSheet(
      context: context,
      builder: (_, scrollController) => StorySheetContent(
        storyId: story.id,
        title: story.title,
        subtitle: story.description,
        imageAsset: story.coverImageUrl,
        mascotConfig: story.mascotConfig,
        users: 0,
        views: 0,
        isAdded: story.isAdded,
        scrollController: scrollController,
      ),
    );
  }
}

class _FeaturedStoryCard extends ConsumerStatefulWidget {
  const _FeaturedStoryCard({
    required this.story,
    required this.onTap,
    this.textOpacity = 1.0,
  });

  final FeaturedStoryDto story;
  final VoidCallback onTap;
  final double textOpacity;

  @override
  ConsumerState<_FeaturedStoryCard> createState() => _FeaturedStoryCardState();
}

class _FeaturedStoryCardState extends ConsumerState<_FeaturedStoryCard> {
  late bool _isAdded = widget.story.isAdded;
  bool _isAdding = false;

  @override
  void didUpdateWidget(covariant _FeaturedStoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.isAdded != widget.story.isAdded) {
      _isAdded = widget.story.isAdded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SmoothClipRRect(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
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
                  child: Opacity(
                    opacity: widget.textOpacity,
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
                        AppPillButton(
                          onPressed: _isAdding
                              ? null
                              : _isAdded
                              ? _navigateToChat
                              : _handleAddToPlaylist,
                          isLoading: _isAdding,
                          icon: _isAdded
                              ? CupertinoIcons.play_fill
                              : CupertinoIcons.add,
                          label: _isAdding
                              ? 'Adding...'
                              : (_isAdded ? 'Continue' : 'My List'),
                          backgroundColor: context.actionButtonBackground,
                          foregroundColor: context.actionButtonForeground,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                          variant: TypographyVariant.body1,
                          fontWeight: FontWeight.w600,
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

  Future<void> _handleAddToPlaylist() async {
    if (_isAdding || _isAdded) return;

    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Add stories to your playlist',
    );
    if (!mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    setState(() => _isAdding = true);
    try {
      await ref
          .read(storiesRepositoryProvider)
          .addStoriesToPlaylist(storyIds: [widget.story.id]);
      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _isAdded = true;
      });
      await StoriesCacheService.clear();
      ref.invalidate(storiesHomeSectionsProvider);
    } catch (err) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      showToast(context, 'Failed to add story: $err');
    }
  }

  Future<void> _navigateToChat() async {
    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Start a story session',
    );
    if (!mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          storyTitle: widget.story.title.isNotEmpty
              ? widget.story.title
              : 'Chat',
          storyId: widget.story.id,
          mascotConfig: widget.story.mascotConfig,
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

class _StoryCard extends ConsumerStatefulWidget {
  const _StoryCard({required this.item, required this.onTap});

  final StoryCardDto item;
  final VoidCallback onTap;

  @override
  ConsumerState<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends ConsumerState<_StoryCard> {
  bool _isAdding = false;
  late bool _isAdded = widget.item.isAdded;

  @override
  void didUpdateWidget(covariant _StoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.isAdded != widget.item.isAdded) {
      _isAdded = widget.item.isAdded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardRadius = 16.0;
    final item = widget.item;
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 125,
        child: SmoothClipRRect(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
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
                // Button at top right
                Positioned(
                  right: 6,
                  top: 6,
                  child: AppCircleIconButton(
                    onPressed: _isAdding
                        ? null
                        : _isAdded
                        ? _navigateToChat
                        : _handleAddToPlaylist,
                    isLoading: _isAdding,
                    icon: _isAdded
                        ? CupertinoIcons.play_fill
                        : CupertinoIcons.add,
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
      ),
    );
  }

  Future<void> _handleAddToPlaylist() async {
    if (_isAdding || _isAdded) return;

    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Add stories to your playlist',
    );
    if (!mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

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
      await StoriesCacheService.clear();
      ref.invalidate(storiesHomeSectionsProvider);
    } catch (err) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      showToast(context, 'Failed to add story: $err');
    }
  }

  Future<void> _navigateToChat() async {
    // Check auth first
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Start a story session',
    );
    if (!mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          storyTitle: widget.item.title.isNotEmpty ? widget.item.title : 'Chat',
          storyId: widget.item.storyId,
          mascotConfig: widget.item.mascotConfig,
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
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.1);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(16),
            ),
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
      ),
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
