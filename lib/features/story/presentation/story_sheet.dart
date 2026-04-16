import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_action_button.dart';
import 'package:antroph_mobile/widgets/premium_star.dart';
import 'package:antroph_mobile/widgets/smooth_card.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/features/story/models/story_detail.dart';
import 'package:antroph_mobile/features/story/providers/story_session_provider.dart';
import 'package:antroph_mobile/features/story/data/stories_cache.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/home/presentation/chat_page.dart';

/// Content widget for the story bottom sheet.
/// Used with [showAppBottomSheet] for consistent sheet styling.
class StorySheetContent extends ConsumerStatefulWidget {
  const StorySheetContent({
    super.key,
    required this.storyId,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.scrollController,
    this.mascotConfig,
    this.users,
    this.views,
    this.isAdded = false,
    this.isPremium = false,
  });

  final String storyId;
  final String title;
  final String subtitle;
  final String imageAsset;
  final ScrollController scrollController;
  final MascotConfig? mascotConfig;
  final int? users;
  final int? views;
  final bool isAdded;
  final bool isPremium;

  @override
  ConsumerState<StorySheetContent> createState() => _StorySheetContentState();
}

class _StorySheetContentState extends ConsumerState<StorySheetContent> {
  late bool _isAdded = widget.isAdded;
  bool _isAddingToPlaylist = false;

  @override
  void didUpdateWidget(covariant StorySheetContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdded != widget.isAdded) {
      _isAdded = widget.isAdded;
    }
  }

  @override
  void dispose() {
    // Clear session when sheet is closed
    ref.read(storySessionProvider.notifier).clearSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final sessionState = ref.watch(storySessionProvider);
    final textColor = context.primaryTextColor;
    final tertiaryColor = context.tertiaryTextColor;
    final detailAsync = ref.watch(storyDetailProvider(widget.storyId));
    final detail = detailAsync.asData?.value;
    final isPremium = widget.isPremium || (detail?.isPremium ?? false);
    final tags = detail?.tags ?? const <String>[];

    return Stack(
      children: [
        CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCard(
                      size: size,
                      imageAsset: widget.imageAsset,
                      sessionState: sessionState,
                      isAdded: _isAdded,
                      isAddingToPlaylist: _isAddingToPlaylist,
                      isPremium: isPremium,
                      onAddToPlaylist: _handleAddToPlaylist,
                      onPlayPressed: _navigateToChat,
                    ),
                    const SizedBox(height: 20),
                    if (tags.isNotEmpty) ...[
                      _TagChips(tags: tags),
                      const SizedBox(height: 12),
                    ],
                    TypographyText(
                      widget.title,
                      variant: TypographyVariant.h2,
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),

                    const SizedBox(height: 16),
                    detailAsync.when(
                      loading: () => const _StoryDetailShimmer(),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TypographyText(
                          'Could not load details.',
                          variant: TypographyVariant.body2,
                          color: tertiaryColor,
                          fontSize: 13,
                        ),
                      ),
                      data: (d) => _StoryDescription(detail: d),
                    ),
                    SizedBox(height: bottom + 40),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Error snackbar
        if (sessionState.error != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _ErrorBanner(
              message: sessionState.error!,
              onDismiss: () => ref.read(storySessionProvider.notifier).clearError(),
            ),
          ),
      ],
    );
  }

  Future<void> _handleAddToPlaylist() async {
    if (_isAddingToPlaylist) return;

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

    setState(() => _isAddingToPlaylist = true);
    try {
      await ref.read(storiesRepositoryProvider).addStoriesToPlaylist(storyIds: [widget.storyId]);
      if (!mounted) return;
      setState(() => _isAdded = true);
      showToast(context, 'Story added to playlist', success: true);
      // Clear cache and refresh stories so the home page reflects the change
      await StoriesCacheService.clear();
      ref.invalidate(storiesHomeSectionsProvider);
    } catch (err) {
      if (!mounted) return;
      showToast(context, 'Failed to add story: $err');
    } finally {
      if (mounted) {
        setState(() => _isAddingToPlaylist = false);
      }
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
          storyTitle: widget.title.isNotEmpty ? widget.title : 'Chat',
          storyId: widget.storyId,
          mascotConfig: widget.mascotConfig,
        ),
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.size,
    required this.imageAsset,
    required this.sessionState,
    required this.isAdded,
    required this.isAddingToPlaylist,
    required this.isPremium,
    required this.onAddToPlaylist,
    required this.onPlayPressed,
  });

  final Size size;
  final String imageAsset;
  final StorySessionState sessionState;
  final bool isAdded;
  final bool isAddingToPlaylist;
  final bool isPremium;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SmoothCard(
      radius: 36,
      child: Stack(
        children: [
          AspectRatio(aspectRatio: 0.85, child: _HeroImage(image: imageAsset)),
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
            left: 20,
            right: 20,
            bottom: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: sessionState.isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: CupertinoActivityIndicator(color: Colors.white),
                    )
                  : _ActionButton(
                      isAdded: isAdded,
                      isLoading: isAddingToPlaylist,
                      onAddPressed: isAddingToPlaylist ? null : onAddToPlaylist,
                      onPlayPressed: onPlayPressed,
                    ),
            ),
          ),
          if (isPremium)
            const Positioned(top: 16, right: 16, child: PremiumStar(size: 24)),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.image});
  final String image;
  bool get _isNetwork => image.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/images/default.png', fit: BoxFit.cover),
      );
    }
    final assetPath = image.isNotEmpty ? image : 'assets/images/default.png';
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Image.asset('assets/images/default.png', fit: BoxFit.cover),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isAdded,
    required this.isLoading,
    required this.onAddPressed,
    required this.onPlayPressed,
  });

  final bool isAdded;
  final bool isLoading;
  final VoidCallback? onAddPressed;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPillButton(
          onPressed: onPlayPressed,
          icon: CupertinoIcons.play_fill,
          label: 'Play',
          backgroundColor: context.actionButtonBackground,
          foregroundColor: context.actionButtonForeground,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          variant: TypographyVariant.body1,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(width: 10),
        _AddToListIconButton(isAdded: isAdded, isLoading: isLoading, onPressed: onAddPressed),
      ],
    );
  }
}

class _AddToListIconButton extends StatelessWidget {
  const _AddToListIconButton({
    required this.isAdded,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isAdded;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withValues(alpha: 0.18);
    final border = Colors.white.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: isAdded || isLoading ? null : onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const CupertinoActivityIndicator(color: Colors.white, radius: 9)
            : Icon(
                isAdded ? CupertinoIcons.checkmark : CupertinoIcons.add,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }
}

/// Renders the description from story detail data.
/// Tags are rendered separately above the title.
class _StoryDescription extends StatelessWidget {
  const _StoryDescription({required this.detail});
  final StoryDetailDto detail;

  @override
  Widget build(BuildContext context) {
    if (detail.description.isEmpty) return const SizedBox.shrink();
    final secondaryTextColor = context.secondaryTextColor;

    return TypographyText(
      detail.description,
      variant: TypographyVariant.body1,
      color: secondaryTextColor,
      fontSize: 14,
      height: 1.35,
    );
  }
}

class _TagChips extends StatelessWidget {
  const _TagChips({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final chipTextColor = isDark ? Colors.white70 : Colors.black54;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
              child: Text(tag, style: TextStyle(color: chipTextColor, fontSize: 13)),
            ),
          )
          .toList(),
    );
  }
}

class _StoryDetailShimmer extends StatelessWidget {
  const _StoryDetailShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            ShimmerBox(width: 70, height: 14, radius: 4),
            SizedBox(width: 16),
            ShimmerBox(width: 60, height: 14, radius: 4),
            SizedBox(width: 16),
            ShimmerBox(width: 50, height: 14, radius: 4),
          ],
        ),
        const SizedBox(height: 16),
        const ShimmerParagraph(lines: 3, lineHeight: 14, lineSpacing: 10, lastLineWidth: 0.7),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: const [
            ShimmerBox(width: 60, height: 28, radius: 20),
            ShimmerBox(width: 80, height: 28, radius: 20),
            ShimmerBox(width: 55, height: 28, radius: 20),
          ],
        ),
      ],
    );
  }
}

/// Error banner widget
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade800,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle_fill, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TypographyText(message, variant: TypographyVariant.body2, color: Colors.white),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
