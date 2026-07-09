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
import 'package:antroph_mobile/features/story/presentation/story_chat_flow_page.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/widgets/scroll_fade_gradient.dart';
import 'package:antroph_mobile/features/story/data/story_search_storage_service.dart';
import 'package:antroph_mobile/features/community_stories/providers/community_stories_providers.dart';
import 'package:antroph_mobile/features/community_stories/models/community_story_model.dart';
import 'package:antroph_mobile/features/community_stories/presentation/community_browse_page.dart';
import 'package:antroph_mobile/features/community_stories/data/community_stories_cache.dart';

class StoryPage extends ConsumerStatefulWidget {
  const StoryPage({super.key});

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage>
    with AutomaticKeepAliveClientMixin {
  final _searchLauncherKey = GlobalKey(debugLabel: 'story_search_launcher');
  Rect? _searchLauncherRect;
  bool _isSearchOpen = false;

  @override
  bool get wantKeepAlive => true;

  void _syncSearchLauncherRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box =
          _searchLauncherKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (_searchLauncherRect == rect) return;
      setState(() => _searchLauncherRect = rect);
    });
  }

  Future<void> _refreshStoriesHome() async {
    await CommunityStoriesCacheService.clear(categoryId: null);
    ref.invalidate(communityBrowseProvider(null));
    await Future.wait([
      ref.read(storiesHomeSectionsProvider.notifier).refreshNow(),
      ref.read(continuePlayingProvider.notifier).refreshNow(),
      ref.read(communityBrowseProvider(null).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          return _ErrorView(message: msg, onRetry: _refreshStoriesHome);
        },
        data: (data) {
          _syncSearchLauncherRect();
          final rawContinueStories =
              asyncContinue.asData?.value ?? const <ContinuePlayingDto>[];
          final sections = data.sections;
          final featuredStories = data.featuredStories;
          final continueStories = rawContinueStories;
          if (sections.isEmpty &&
              featuredStories.isEmpty &&
              continueStories.isEmpty &&
              data.featuredStories.isEmpty) {
            return _EmptyView(onRefresh: _refreshStoriesHome);
          }

          return Stack(
            children: [
              ScrollFadeGradient(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: _refreshStoriesHome,
                    ),
                    SliverToBoxAdapter(
                      child: _StoryHomeHeader(
                        isDark: isDark,
                        searchLauncherKey: _searchLauncherKey,
                        isSearchFloating: _isSearchOpen,
                        onSearchTap: () => setState(() => _isSearchOpen = true),
                      ),
                    ),
                    if (featuredStories.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _FeaturedStoriesCarousel(
                          stories: featuredStories,
                          onTap: (story) =>
                              _playFeaturedStory(context, ref, story),
                        ),
                      ),
                    if (continueStories.isNotEmpty)
                      _ContinuePlayingSliver(
                        stories: continueStories,
                        onTap: (story) => _resumeStory(context, ref, story),
                      ),
                    for (final section in sections)
                      _SectionSliver(
                        section: section,
                        onTap: (card) => _playStoryCard(context, ref, card),
                      ),
                    const _CommunityStoriesSliver(searchQuery: ''),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
              _StorySearchLayer(
                isDark: isDark,
                isOpen: _isSearchOpen,
                launcherRect: _searchLauncherRect,
                sections: data.sections,
                featuredStories: data.featuredStories,
                onOpen: () => setState(() => _isSearchOpen = true),
                onCloseComplete: () {
                  if (mounted) setState(() => _isSearchOpen = false);
                },
                onSelected: (selection) async {
                  switch (selection) {
                    case _StorySearchStorySelection(:final story):
                      await _playStoryCard(context, ref, story);
                    case _StorySearchFeaturedSelection(:final story):
                      await _playFeaturedStory(context, ref, story);
                  }
                },
              ),
            ],
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
        builder: (_) => StoryChatFlowPage(
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

class _StoryHomeHeader extends StatelessWidget {
  const _StoryHomeHeader({
    required this.isDark,
    required this.searchLauncherKey,
    required this.isSearchFloating,
    required this.onSearchTap,
  });

  final bool isDark;
  final GlobalKey searchLauncherKey;
  final bool isSearchFloating;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/app_logo.png',
                  width: 38,
                  height: 38,
                ),
                const SizedBox(width: 2),
                TypographyText(
                  'Explore',
                  variant: TypographyVariant.h3,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              key: searchLauncherKey,
              width: double.infinity,
              height: 40,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: isSearchFloating ? 0 : 1,
                child: _MorphingStorySearchField(
                  isOpen: false,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  iconColor: isDark ? Colors.white54 : Colors.black45,
                  controller: null,
                  focusNode: null,
                  onTapClosed: onSearchTap,
                  onChanged: null,
                  onSubmitted: null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _StorySearchSelection {
  const _StorySearchSelection();
}

class _StorySearchStorySelection extends _StorySearchSelection {
  const _StorySearchStorySelection(this.story);
  final StoryCardDto story;
}

class _StorySearchFeaturedSelection extends _StorySearchSelection {
  const _StorySearchFeaturedSelection(this.story);
  final FeaturedStoryDto story;
}

class _StorySearchLayer extends StatefulWidget {
  const _StorySearchLayer({
    required this.isDark,
    required this.isOpen,
    required this.launcherRect,
    required this.sections,
    required this.featuredStories,
    required this.onOpen,
    required this.onCloseComplete,
    required this.onSelected,
  });

  final bool isDark;
  final bool isOpen;
  final Rect? launcherRect;
  final List<StorySectionDto> sections;
  final List<FeaturedStoryDto> featuredStories;
  final VoidCallback onOpen;
  final VoidCallback onCloseComplete;
  final ValueChanged<_StorySearchSelection> onSelected;

  @override
  State<_StorySearchLayer> createState() => _StorySearchLayerState();
}

class _StorySearchLayerState extends State<_StorySearchLayer> {
  static const _openSearchBarDuration = Duration(milliseconds: 1120);
  static const _closeSearchBarDuration = Duration(milliseconds: 360);
  static const _openBodySlideDuration = Duration(milliseconds: 680);
  static const _closeBodySlideDuration = Duration(milliseconds: 260);
  static const _openBodyFadeDuration = Duration(milliseconds: 560);
  static const _closeBodyFadeDuration = Duration(milliseconds: 220);

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  List<StoryRecentSearch> _recentSearches = const [];
  String _query = '';
  _SearchSuggestion? _selectedSuggestion;
  bool _hasEntered = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _loadRecentSearches();
    if (widget.isOpen) _open();
  }

  @override
  void didUpdateWidget(covariant _StorySearchLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOpen && widget.isOpen) _open();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final recents = await StorySearchStorageService.loadRecentSearchItems();
    if (!mounted) return;
    setState(() => _recentSearches = recents);
  }

  Future<void> _saveSearch(
    String value, {
    StoryRecentSearchType type = StoryRecentSearchType.text,
    String? image,
  }) async {
    await StorySearchStorageService.saveSearch(value, type: type, image: image);
    await _loadRecentSearches();
  }

  Future<void> _clearRecentSearches() async {
    await StorySearchStorageService.clearRecentSearches();
    if (!mounted) return;
    setState(() => _recentSearches = const []);
  }

  void _open() {
    _isClosing = false;
    _controller.clear();
    setState(() {
      _query = '';
      _selectedSuggestion = null;
      _hasEntered = true;
    });
  }

  Future<void> _close([_StorySearchSelection? selection]) async {
    if (_isClosing) return;
    _isClosing = true;
    _focusNode.unfocus();
    if (mounted) setState(() => _hasEntered = false);
    await Future<void>.delayed(_closeSearchBarDuration);
    if (!mounted) return;
    setState(() => _isClosing = false);
    widget.onCloseComplete();
    if (selection != null) widget.onSelected(selection);
  }

  void _navigateToSelection(_StorySearchSelection selection) {
    _focusNode.unfocus();
    widget.onSelected(selection);
  }

  void _goBack() {
    if (_query.trim().isNotEmpty || _selectedSuggestion != null) {
      _controller.clear();
      setState(() {
        _query = '';
        _selectedSuggestion = null;
      });
      return;
    }
    unawaited(_close());
  }

  void _handleBackgroundTap() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      return;
    }
    if (_query.trim().isNotEmpty || _selectedSuggestion != null) return;
    unawaited(_close());
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _selectedSuggestion = null;
    });
  }

  Future<void> _submitQuery(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _query = trimmed;
      _selectedSuggestion = null;
      _controller.clear();
    });
  }

  Future<void> _selectRecent(String value) async {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    await _submitQuery(value);
  }

  Future<void> _selectSuggestion(_SearchSuggestion suggestion) async {
    if (suggestion.type == _SearchSuggestionType.story) {
      await _saveSearch(
        suggestion.value,
        type: StoryRecentSearchType.story,
        image: suggestion.image,
      );
    }
    if (!mounted) return;
    _controller.text = suggestion.value;
    _controller.selection = TextSelection.collapsed(
      offset: suggestion.value.length,
    );
    setState(() {
      _query = suggestion.value;
      _selectedSuggestion = suggestion;
    });
  }

  Future<void> _selectCategory(String category) async {
    await _selectSuggestion(
      _SearchSuggestion(value: category, type: _SearchSuggestionType.category),
    );
  }

  Future<void> _openStory(StoryCardDto story) async {
    await _saveSearch(
      story.title,
      type: StoryRecentSearchType.story,
      image: story.image,
    );
    if (!mounted) return;
    _navigateToSelection(_StorySearchStorySelection(story));
  }

  Future<void> _openFeaturedStory(FeaturedStoryDto story) async {
    await _saveSearch(
      story.title,
      type: StoryRecentSearchType.featured,
      image: story.coverImageUrl,
    );
    if (!mounted) return;
    _navigateToSelection(_StorySearchFeaturedSelection(story));
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _normalizeSearchQuery(_query);
    final hasQuery = normalizedQuery.isNotEmpty;
    final clearAllFontSize = _overlayResponsiveFont(
      context,
      14,
      min: 12,
      max: 14,
    );
    final selectedSuggestion = _selectedSuggestion;
    final suggestions = hasQuery
        ? _buildSearchSuggestions(
            sections: widget.sections,
            query: normalizedQuery,
          )
        : const <_SearchSuggestion>[];
    final showSuggestionPanel =
        hasQuery && selectedSuggestion == null && suggestions.isNotEmpty;
    final sections = selectedSuggestion != null
        ? _filterStorySectionsBySuggestion(widget.sections, selectedSuggestion)
        : _filterStorySections(widget.sections, normalizedQuery);
    final featuredStories = selectedSuggestion != null
        ? const <FeaturedStoryDto>[]
        : _filterFeaturedStories(widget.featuredStories, normalizedQuery);
    final categories = widget.sections
        .where((section) => !_isUtilityStorySection(section.title))
        .map((section) => section.title)
        .where((title) => title.trim().isNotEmpty)
        .toList();
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final safeTop = mediaQuery.padding.top;
    final launcherRect =
        widget.launcherRect ??
        Rect.fromLTWH(20, safeTop + 64, screenWidth - 40, 40);
    final targetSearchRect = Rect.fromLTWH(
      54,
      safeTop + 12,
      screenWidth - 66,
      40,
    );
    final currentSearchRect = _hasEntered ? targetSearchRect : launcherRect;
    final searchBarDuration = _isClosing
        ? _closeSearchBarDuration
        : _openSearchBarDuration;
    final bodySlideDuration = _isClosing
        ? _closeBodySlideDuration
        : _openBodySlideDuration;
    final bodyFadeDuration = _isClosing
        ? _closeBodyFadeDuration
        : _openBodyFadeDuration;
    final fixedSuggestionTop = targetSearchRect.bottom + 12;
    final fixedSuggestionHeight = !showSuggestionPanel
        ? 0.0
        : (suggestions.length * 44.0) + (suggestions.length - 1);
    final bodyTopPadding = showSuggestionPanel
        ? fixedSuggestionTop + fixedSuggestionHeight + 18
        : safeTop + 78;

    final overlayActive = widget.isOpen || _hasEntered || _isClosing;

    return Positioned.fill(
      child: PopScope(
        canPop: !overlayActive,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && overlayActive) _goBack();
        },
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: !overlayActive,
              child: AnimatedOpacity(
                duration: bodyFadeDuration,
                curve: Curves.easeOutCubic,
                opacity: _hasEntered ? 1 : 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _handleBackgroundTap,
                  child: const SizedBox.expand(
                    child: ColoredBox(color: Colors.black),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              ignoring: !overlayActive,
              child: Padding(
                padding: EdgeInsets.only(top: bodyTopPadding),
                child: AnimatedSlide(
                  duration: bodySlideDuration,
                  curve: Curves.easeOutCubic,
                  offset: _hasEntered ? Offset.zero : const Offset(0, 0.025),
                  child: AnimatedOpacity(
                    duration: bodyFadeDuration,
                    curve: Curves.easeOutCubic,
                    opacity: _hasEntered ? 1 : 0,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (!hasQuery) ...[
                          _OverlaySectionHeader(
                            title: 'Recent searches',
                            trailing: _recentSearches.isEmpty
                                ? null
                                : TextButton(
                                    onPressed: _clearRecentSearches,
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFF1F1F1F),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(
                                      'Clear all',
                                      style: TextStyle(
                                        fontSize: clearAllFontSize,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 18),
                          _RecentSearchesRow(
                            searches: _recentSearches,
                            onSelected: _selectRecent,
                          ),
                          const SizedBox(height: 34),
                          const _OverlaySectionHeader(title: 'Categories'),
                          const SizedBox(height: 18),
                          _CategoryRows(
                            categories: categories,
                            onTap: _selectCategory,
                          ),
                        ] else ...[
                          if (featuredStories.isNotEmpty ||
                              sections.isNotEmpty) ...[
                            if (featuredStories.isNotEmpty)
                              _SearchFeaturedResultsSection(
                                stories: featuredStories,
                                onTap: _openFeaturedStory,
                              ),
                            for (final section in sections)
                              if (section.items.isNotEmpty)
                                _SearchStoryResultsSection(
                                  section: section,
                                  onTap: _openStory,
                                ),
                          ] else
                            _EmptyOverlayMessage(query: _query),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: fixedSuggestionTop,
              child: IgnorePointer(
                ignoring: !overlayActive || !showSuggestionPanel,
                child: AnimatedSlide(
                  duration: bodySlideDuration,
                  curve: Curves.easeOutCubic,
                  offset: _hasEntered ? Offset.zero : const Offset(0, 0.04),
                  child: AnimatedOpacity(
                    duration: bodyFadeDuration,
                    curve: Curves.easeOutCubic,
                    opacity: _hasEntered && showSuggestionPanel ? 1 : 0,
                    child: _SearchSuggestionsDropdown(
                      suggestions: suggestions,
                      onSelected: _selectSuggestion,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: targetSearchRect.top - 2,
              width: 38,
              height: 44,
              child: IgnorePointer(
                ignoring: !overlayActive,
                child: AnimatedOpacity(
                  duration: bodyFadeDuration,
                  curve: Curves.easeOutCubic,
                  opacity: _hasEntered ? 1 : 0,
                  child: IconButton(
                    onPressed: _goBack,
                    icon: const Icon(CupertinoIcons.chevron_left),
                    color: Colors.white,
                    iconSize: 30,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: searchBarDuration,
              curve: Curves.easeOutCubic,
              left: currentSearchRect.left,
              top: currentSearchRect.top,
              width: currentSearchRect.width,
              height: currentSearchRect.height,
              child: IgnorePointer(
                ignoring: !overlayActive,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 80),
                  opacity: overlayActive ? 1 : 0,
                  child: _MorphingStorySearchField(
                    isOpen: overlayActive,
                    backgroundColor: const Color(0xFF1F1F1F),
                    iconColor: const Color(0xFFB6B6B6),
                    controller: _controller,
                    focusNode: _focusNode,
                    onTapClosed: widget.onOpen,
                    onChanged: _setQuery,
                    onSubmitted: _submitQuery,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MorphingStorySearchField extends StatelessWidget {
  const _MorphingStorySearchField({
    required this.isOpen,
    required this.backgroundColor,
    required this.iconColor,
    required this.controller,
    required this.focusNode,
    required this.onTapClosed,
    required this.onChanged,
    required this.onSubmitted,
  });

  final bool isOpen;
  final Color backgroundColor;
  final Color iconColor;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final VoidCallback onTapClosed;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !isOpen,
      textField: isOpen,
      label: 'Search stories',
      child: GestureDetector(
        onTap: isOpen ? null : onTapClosed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(CupertinoIcons.search, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: isOpen
                      ? TextField(
                          key: const ValueKey('story_search_input'),
                          controller: controller!,
                          focusNode: focusNode!,
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                          textInputAction: TextInputAction.search,
                          cursorColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search stories or categories',
                            hintStyle: TextStyle(
                              color: Color(0xFF8D8D8D),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : TypographyText(
                          'Search stories or categories',
                          key: const ValueKey('story_search_launcher_text'),
                          variant: TypographyVariant.body2,
                          color: iconColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          maxLines: 1,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlaySectionHeader extends StatelessWidget {
  const _OverlaySectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final fontSize = _overlayResponsiveFont(context, 20, min: 17, max: 20);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _RecentSearchesRow extends StatelessWidget {
  const _RecentSearchesRow({required this.searches, required this.onSelected});

  final List<StoryRecentSearch> searches;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final emptyFontSize = _overlayResponsiveFont(context, 14, min: 12, max: 14);

    if (searches.isEmpty) {
      return Text(
        'Searches you make will appear here.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.54),
          fontSize: emptyFontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final avatarRadius = _overlayResponsiveSize(context, 30, min: 25, max: 30);
    final avatarFontSize = _overlayResponsiveFont(
      context,
      18,
      min: 15,
      max: 18,
    );
    final labelFontSize = _overlayResponsiveFont(context, 13, min: 11, max: 13);

    return SizedBox(
      height: avatarRadius * 2 + 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: searches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final search = searches[index];
          final image = search.image?.trim() ?? '';
          return GestureDetector(
            onTap: () => onSelected(search.value),
            child: SizedBox(
              width: 94,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: _recentColor(search.value),
                    child: ClipOval(
                      child: image.isEmpty
                          ? Center(
                              child: Text(
                                search.value.trim().isEmpty
                                    ? '?'
                                    : search.value
                                          .trim()
                                          .characters
                                          .first
                                          .toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: avatarFontSize,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          : SizedBox.expand(child: _StoryImage(image: image)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    search.value,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _recentColor(String value) {
    const colors = [
      Color(0xFF7A3628),
      Color(0xFF214B6D),
      Color(0xFF4E3A7D),
      Color(0xFF276749),
      Color(0xFF6B4A1E),
    ];
    return colors[value.hashCode.abs() % colors.length];
  }
}

class _CategoryRows extends StatelessWidget {
  const _CategoryRows({required this.categories, required this.onTap});

  final List<String> categories;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _EmptyOverlayMessage(query: 'categories');
    }
    return Column(
      children: [
        for (var index = 0; index < categories.length; index++) ...[
          _OverlayActionRow(
            icon: _categoryIcon(categories[index], index),
            title: categories[index],
            onTap: () => onTap(categories[index]),
          ),
          if (index != categories.length - 1) const _OverlayDivider(),
        ],
      ],
    );
  }

  IconData _categoryIcon(String category, int index) {
    final normalizedCategory = _normalizeSearchQuery(category);
    if (normalizedCategory.contains('culinary') ||
        normalizedCategory.contains('food') ||
        normalizedCategory.contains('cooking') ||
        normalizedCategory.contains('kitchen')) {
      return Icons.restaurant_menu;
    }
    if (normalizedCategory.contains('habit') ||
        normalizedCategory.contains('formation')) {
      return CupertinoIcons.mic;
    }

    const icons = [
      CupertinoIcons.book,
      CupertinoIcons.sparkles,
      CupertinoIcons.heart,
      CupertinoIcons.moon_stars,
      CupertinoIcons.person_2,
      CupertinoIcons.compass,
      CupertinoIcons.chat_bubble_2,
      CupertinoIcons.lightbulb,
    ];
    return icons[index % icons.length];
  }
}

class _SearchSuggestionsDropdown extends StatelessWidget {
  const _SearchSuggestionsDropdown({
    required this.suggestions,
    required this.onSelected,
  });

  final List<_SearchSuggestion> suggestions;
  final ValueChanged<_SearchSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Colors.white.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < suggestions.length; index++) ...[
            _SearchSuggestionTile(
              suggestion: suggestions[index],
              onTap: () => onSelected(suggestions[index]),
            ),
            if (index != suggestions.length - 1)
              Divider(height: 1, color: dividerColor),
          ],
        ],
      ),
    );
  }
}

class _SearchSuggestionTile extends StatelessWidget {
  const _SearchSuggestionTile({required this.suggestion, required this.onTap});

  final _SearchSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = suggestion.type == _SearchSuggestionType.category
        ? CupertinoIcons.square_grid_2x2
        : CupertinoIcons.book;
    final label = suggestion.type == _SearchSuggestionType.category
        ? 'Category'
        : 'Story';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Colors.white54),
            const SizedBox(width: 10),
            Expanded(
              child: TypographyText(
                suggestion.value,
                variant: TypographyVariant.body2,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 10),
            TypographyText(
              label,
              variant: TypographyVariant.body2,
              color: Colors.white54,
              fontSize: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayActionRow extends StatelessWidget {
  const _OverlayActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rowHeight = _overlayResponsiveSize(context, 58, min: 52, max: 58);
    final iconSize = _overlayResponsiveSize(context, 26, min: 22, max: 26);
    final titleFontSize = _overlayResponsiveFont(context, 16, min: 14, max: 16);
    final trailingIconSize = _overlayResponsiveSize(
      context,
      24,
      min: 21,
      max: 24,
    );

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: rowHeight,
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC2C2C2), size: iconSize),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.arrow_up_left_circle,
              color: const Color(0xFFB6B6B6),
              size: trailingIconSize,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchStoryResultsSection extends StatelessWidget {
  const _SearchStoryResultsSection({
    required this.section,
    required this.onTap,
  });

  final StorySectionDto section;
  final ValueChanged<StoryCardDto> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverlaySectionHeader(title: section.title),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final itemWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: 16,
                children: [
                  for (final story in section.items)
                    _StoryCard(
                      item: story,
                      width: itemWidth,
                      onTap: () => onTap(story),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchFeaturedResultsSection extends StatelessWidget {
  const _SearchFeaturedResultsSection({
    required this.stories,
    required this.onTap,
  });

  final List<FeaturedStoryDto> stories;
  final ValueChanged<FeaturedStoryDto> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OverlaySectionHeader(title: 'Featured'),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final story = stories[index];
                return SizedBox(
                  width: 170,
                  child: _FeaturedStoryCard(
                    story: story,
                    onTap: () => onTap(story),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemCount: stories.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayDivider extends StatelessWidget {
  const _OverlayDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
      indent: 58,
    );
  }
}

class _EmptyOverlayMessage extends StatelessWidget {
  const _EmptyOverlayMessage({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final fontSize = _overlayResponsiveFont(context, 14, min: 12, max: 14);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'No matches for "$query".',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.58),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

double _overlayResponsiveFont(
  BuildContext context,
  double base, {
  required double min,
  required double max,
}) {
  return _overlayResponsiveSize(context, base, min: min, max: max);
}

double _overlayResponsiveSize(
  BuildContext context,
  double base, {
  required double min,
  required double max,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final scale = (width / 390).clamp(0.86, 1.0);
  return (base * scale).clamp(min, max);
}

class _FeaturedStoryCard extends StatelessWidget {
  const _FeaturedStoryCard({required this.story, required this.onTap});

  final FeaturedStoryDto story;
  final VoidCallback onTap;

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
                _StoryImage(image: story.coverImageUrl),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 86,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: TypographyText(
                    story.title,
                    variant: TypographyVariant.body1,
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    maxLines: 2,
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

  @override
  void didUpdateWidget(covariant _FeaturedStoriesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stories.length != oldWidget.stories.length) {
      if (_currentPage >= widget.stories.length) {
        _currentPage = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
      _startAutoAdvanceTimer();
    }
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

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding * 0.1,
                      ),
                      child: _FeaturedStoryCard(
                        story: story,
                        onTap: () => widget.onTap(story),
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
  const _StoryCard({required this.item, required this.onTap, this.width = 125});

  final StoryCardDto item;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
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
    // Removed ShimmerBox to prevent "double shimmer" or flickers when navigating.
    // The image itself handles its own fade-in via frameBuilder.
    return child;
  }
}

class _CommunityStoriesSliver extends ConsumerWidget {
  const _CommunityStoriesSliver({required this.searchQuery});

  final String searchQuery;

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
        final filteredStories = _filterCommunityStories(stories, searchQuery);
        if (filteredStories.isEmpty) {
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
                  itemCount: filteredStories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final story = filteredStories[index];
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
    var launchMode = InteractiveStoryLaunchMode.create;
    String? joinCode;
    if (story.interactionMode == 'group') {
      final result = await showGroupGameLauncherSheet(context);
      if (!context.mounted || result == null) return;
      launchMode = result.mode;
      joinCode = result.joinCode;
    }
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
        builder: (_) => StoryChatFlowPage(
          storyTitle: story.title.isNotEmpty ? story.title : 'Chat',
          storyId: story.id,
          storySubtitle: story.description,
          storyImage: story.coverImageUrl,
          interactiveLaunchMode: launchMode,
          joinCode: joinCode,
        ),
      ),
    );
  }

  void _openCommunityStory(BuildContext context, CommunityStoryDto story) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _capitalizeFirstLetter(story.title);
    final description = _capitalizeFirstLetter(story.description ?? '');
    final creatorName = _capitalizeFirstLetter(story.creatorName ?? '');

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
                    child: AspectRatio(
                      aspectRatio: 0.85,
                      child:
                          story.coverImageUrl != null &&
                              story.coverImageUrl!.isNotEmpty
                          ? Image.network(
                              story.coverImageUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/default.png',
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/images/default.png',
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (creatorName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'By $creatorName',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      description,
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

String _capitalizeFirstLetter(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

String _normalizeSearchQuery(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

enum _SearchSuggestionType { category, story }

class _SearchSuggestion {
  const _SearchSuggestion({
    required this.value,
    required this.type,
    this.categoryTitle,
    this.storyId,
    this.image,
  });

  final String value;
  final _SearchSuggestionType type;
  final String? categoryTitle;
  final String? storyId;
  final String? image;
}

List<_SearchSuggestion> _buildSearchSuggestions({
  required List<StorySectionDto> sections,
  required String query,
}) {
  if (query.isEmpty) return const [];

  final suggestions = <_SearchSuggestion>[];
  final seen = <String>{};

  void add(
    String value,
    _SearchSuggestionType type, {
    String? categoryTitle,
    String? storyId,
    String? image,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final normalized = _normalizeSearchQuery(trimmed);
    if (!normalized.contains(query)) return;
    final normalizedCategory = _normalizeSearchQuery(categoryTitle ?? '');
    final normalizedStoryId = _normalizeSearchQuery(storyId ?? '');
    final key = type == _SearchSuggestionType.story
        ? '${type.name}:${normalizedStoryId.isEmpty ? normalized : normalizedStoryId}'
        : '${type.name}:$normalizedCategory:$normalized';
    if (!seen.add(key)) return;
    suggestions.add(
      _SearchSuggestion(
        value: trimmed,
        type: type,
        categoryTitle: categoryTitle,
        storyId: storyId,
        image: image,
      ),
    );
  }

  for (final section in sections) {
    if (_isUtilityStorySection(section.title)) continue;
    add(section.title, _SearchSuggestionType.category);
    for (final story in section.items) {
      add(
        story.title,
        _SearchSuggestionType.story,
        categoryTitle: section.title,
        storyId: story.storyId,
        image: story.image,
      );
    }
  }

  return suggestions.take(5).toList();
}

bool _matchesQuery(String query, Iterable<String?> values) {
  if (query.isEmpty) return true;
  return values.any((value) {
    final normalized = _normalizeSearchQuery(value ?? '');
    return normalized.isNotEmpty && normalized.contains(query);
  });
}

List<StorySectionDto> _filterStorySections(
  List<StorySectionDto> sections,
  String query,
) {
  if (query.isEmpty) return sections;
  return sections
      .map((section) {
        final categoryMatches = _matchesQuery(query, [section.title]);
        if (categoryMatches) return section;

        final items = section.items
            .where((story) => _matchesStoryCard(story, query))
            .toList();
        return StorySectionDto(title: section.title, items: items);
      })
      .where((section) => section.items.isNotEmpty)
      .toList();
}

List<StorySectionDto> _filterStorySectionsBySuggestion(
  List<StorySectionDto> sections,
  _SearchSuggestion suggestion,
) {
  final value = _normalizeSearchQuery(suggestion.value);
  if (value.isEmpty) return sections;

  if (suggestion.type == _SearchSuggestionType.category) {
    return sections
        .where((section) => _normalizeSearchQuery(section.title) == value)
        .toList();
  }

  final category = _normalizeSearchQuery(suggestion.categoryTitle ?? '');
  final preferredSections = sections.where((section) {
    if (_isUtilityStorySection(section.title)) return false;
    if (category.isEmpty) return true;
    return _normalizeSearchQuery(section.title) == category;
  }).toList();
  final candidateSections = preferredSections.isNotEmpty
      ? preferredSections
      : sections.where((section) => !_isUtilityStorySection(section.title));

  return candidateSections
      .map((section) {
        final items = section.items.where((story) {
          final suggestionStoryId = suggestion.storyId?.trim();
          if (suggestionStoryId != null && suggestionStoryId.isNotEmpty) {
            return story.storyId == suggestionStoryId ||
                story.id == suggestionStoryId;
          }
          return _normalizeSearchQuery(story.title) == value;
        }).toList();
        return StorySectionDto(title: section.title, items: items);
      })
      .where((section) => section.items.isNotEmpty)
      .toList();
}

bool _isUtilityStorySection(String title) {
  final normalized = _normalizeSearchQuery(title);
  return normalized.contains('playlist') ||
      normalized.contains('collection') ||
      normalized.contains('continue') ||
      normalized.contains('recommend') ||
      normalized.contains('trending') ||
      normalized.contains('popular');
}

List<FeaturedStoryDto> _filterFeaturedStories(
  List<FeaturedStoryDto> stories,
  String query,
) {
  if (query.isEmpty) return stories;
  return stories
      .where(
        (story) => _matchesQuery(query, [
          story.title,
          story.description,
          story.author,
          story.aiRole,
          story.interactionMode,
          story.riveElement?.name,
          story.riveElement?.category,
        ]),
      )
      .toList();
}

List<CommunityStoryDto> _filterCommunityStories(
  List<CommunityStoryDto> stories,
  String query,
) {
  if (query.isEmpty) return stories;
  return stories
      .where((story) => _matchesCommunityStory(story, query))
      .toList();
}

bool _matchesStoryCard(StoryCardDto story, String query) {
  return _matchesQuery(query, [
    story.title,
    story.subtitle,
    story.aiRole,
    story.interactionMode,
    story.riveElement?.name,
    story.riveElement?.category,
  ]);
}

bool _matchesCommunityStory(CommunityStoryDto story, String query) {
  return _matchesQuery(query, [
    story.title,
    story.description,
    story.author,
    story.creatorName,
    story.categoryId,
    story.difficulty,
    story.tone,
    story.interactionMode,
    story.aiRole,
    story.riveElement?.name,
    story.riveElement?.category,
    ...story.tags,
    ...story.themes,
    ...story.characters,
  ]);
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
            actionLabel: 'Retry',
            onAction: () => onRetry(),
          ),
        ),
      ],
    );
  }
}
