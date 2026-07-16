import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:antroph_mobile/core/auth/utils/auth_guard.dart';
import 'package:antroph_mobile/core/network/error_formatter.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_action_button.dart';
import 'package:antroph_mobile/widgets/blurred_fade_image.dart';
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
import 'package:antroph_mobile/features/story/presentation/solo_interactive_history_view.dart';
import 'package:antroph_mobile/features/story/presentation/story_chat_flow_page.dart';
import 'package:antroph_mobile/features/subscription/providers/subscription_provider.dart';
import 'package:antroph_mobile/features/subscription/presentation/revenuecat_actions.dart';

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
    this.cachedDescription,
    this.mascotConfig,
    this.users,
    this.views,
    this.isAdded = false,
    this.isPremium = false,
    this.userCanAccess = true,
    this.activeGameCode,
  });

  final String storyId;
  final String title;
  final String subtitle;
  final String? cachedDescription;
  final String imageAsset;
  final ScrollController scrollController;
  final MascotConfig? mascotConfig;
  final int? users;
  final int? views;
  final bool isAdded;
  final bool isPremium;
  final bool userCanAccess;
  final String? activeGameCode;

  @override
  ConsumerState<StorySheetContent> createState() => _StorySheetContentState();
}

class _StorySheetContentState extends ConsumerState<StorySheetContent> {
  late bool _isAdded = widget.isAdded;
  late final StorySessionNotifier _storySessionNotifier;
  bool _isAddingToPlaylist = false;
  bool _didPresentPremiumPrompt = false;

  @override
  void initState() {
    super.initState();
    _storySessionNotifier = ref.read(storySessionProvider.notifier);
  }

  @override
  void didUpdateWidget(covariant StorySheetContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdded != widget.isAdded) {
      _isAdded = widget.isAdded;
    }
  }

  @override
  void dispose() {
    // Clear after unmount so Riverpod is not mutated while the widget tree is
    // finalizing.
    Future<void>.microtask(_storySessionNotifier.clearSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final sessionState = ref.watch(storySessionProvider);
    final textColor = context.primaryTextColor;
    final tertiaryColor = context.tertiaryTextColor;
    final detailAsync = widget.userCanAccess
        ? ref.watch(storyDetailProvider(widget.storyId))
        : null;
    final detail = detailAsync?.asData?.value;
    final isDetailReady =
        widget.userCanAccess && detailAsync?.hasValue == true && detail != null;
    final isPremium =
        widget.isPremium ||
        !widget.userCanAccess ||
        (detail?.isPremium ?? false);
    final tags = detail?.tags ?? const <String>[];

    final isSubscribedAsync = ref.watch(isSubscribedProvider);
    final isSubscribed = isSubscribedAsync.asData?.value ?? false;

    final isLocked = !widget.userCanAccess || (isPremium && !isSubscribed);
    if (!_didPresentPremiumPrompt && isSubscribedAsync.hasValue && isLocked) {
      _didPresentPremiumPrompt = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handlePremiumUnlock();
      });
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -60,
          left: 0,
          right: 0,
          height: size.height * 1 + 60,
          child: IgnorePointer(
            child: _SoftImageBackdrop(imageAsset: widget.imageAsset),
          ),
        ),
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
                      isPlayEnabled: isLocked || isDetailReady,
                      tags: tags,
                      onAddToPlaylist: _handleAddToPlaylist,
                      onPlayPressed: () => _handlePlayOrUnlock(isLocked),
                    ),
                    const SizedBox(height: 20),
                    TypographyText(
                      widget.title,
                      variant: TypographyVariant.h2,
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),

                    const SizedBox(height: 16),
                    if ((widget.activeGameCode ?? '').trim().isNotEmpty) ...[
                      _ActiveGameCodeCard(code: widget.activeGameCode!.trim()),
                      const SizedBox(height: 16),
                    ],
                    if (!widget.userCanAccess)
                      _CachedStoryDescription(
                        text: widget.cachedDescription ?? widget.subtitle,
                      )
                    else
                      detailAsync!.when(
                        loading: () => _CachedStoryDescription(
                          text: widget.cachedDescription ?? widget.subtitle,
                        ),
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
              onDismiss: () =>
                  ref.read(storySessionProvider.notifier).clearError(),
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
      await ref
          .read(storiesRepositoryProvider)
          .addStoriesToPlaylist(storyIds: [widget.storyId]);
      if (!mounted) return;
      setState(() => _isAdded = true);
      showToast(context, 'Story added to playlist', success: true);
      // Clear cache and refresh stories so the home page reflects the change
      await StoriesCacheService.clear();
      ref.invalidate(storiesHomeSectionsProvider);
    } catch (err) {
      if (!mounted) return;
      final message = err is ApiError ? err.message : err.toString();
      showToast(context, 'Failed to add story: $message');
    } finally {
      if (mounted) {
        setState(() => _isAddingToPlaylist = false);
      }
    }
  }

  Future<void> _handlePlayOrUnlock(bool isLocked) async {
    if (isLocked) {
      await _handlePremiumUnlock();
      return;
    }
    StoryDetailDto? detail = ref
        .read(storyDetailProvider(widget.storyId))
        .asData
        ?.value;
    if (detail == null) {
      try {
        detail = await ref.read(storyDetailProvider(widget.storyId).future);
      } catch (_) {
        detail = null;
      }
      if (!mounted) return;
    }
    if (detail?.interactionMode == 'group') {
      await _showGroupGameLauncher();
      return;
    }
    if ((detail?.interactionMode ?? 'narrative') != 'narrative') {
      await _showSoloInteractiveLauncher();
      return;
    }
    await _navigateToChat();
  }

  Future<void> _handlePremiumUnlock() async {
    final authResult = await showAuthGuardSheet(
      context,
      ref,
      actionDescription: 'Unlock premium stories',
    );
    if (!mounted) return;
    if (authResult != AuthGuardResult.authenticated &&
        authResult != AuthGuardResult.loginSuccessful) {
      return;
    }

    final openStory = await presentAuraProPaywall(context, ref);
    if (openStory && mounted) await _navigateToChat();
  }

  Future<void> _showGroupGameLauncher() async {
    final result = await showGroupGameLauncherSheet(context);
    if (!mounted || result == null) return;
    await _navigateToChat(launchMode: result.mode, joinCode: result.joinCode);
  }

  Future<void> _showSoloInteractiveLauncher() async {
    final result = await showSoloInteractiveLauncherSheet(
      context,
      storyId: widget.storyId,
    );
    if (!mounted || result == null) return;
    await _navigateToChat(
      storySessionId:
          result.action == SoloInteractiveLaunchAction.continueSession
          ? result.sessionId
          : null,
      soloStartFreshOnLaunch:
          result.action == SoloInteractiveLaunchAction.startFresh,
      soloOpenHistoryOnLaunch:
          result.action == SoloInteractiveLaunchAction.viewHistory,
    );
  }

  Future<void> _navigateToChat({
    InteractiveStoryLaunchMode launchMode = InteractiveStoryLaunchMode.create,
    String? joinCode,
    String? storySessionId,
    bool soloStartFreshOnLaunch = false,
    bool soloOpenHistoryOnLaunch = false,
  }) async {
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

    final initialInteractionMode = ref
        .read(storyDetailProvider(widget.storyId))
        .asData
        ?.value
        .interactionMode;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryChatFlowPage(
          storyTitle: widget.title.isNotEmpty ? widget.title : 'Chat',
          storyId: widget.storyId,
          storySessionId: storySessionId,
          mascotConfig: widget.mascotConfig,
          storySubtitle: widget.subtitle,
          storyImage: widget.imageAsset,
          isAddedToPlaylist: _isAdded,
          initialInteractionMode: initialInteractionMode,
          interactiveLaunchMode: launchMode,
          joinCode: joinCode,
          soloStartFreshOnLaunch: soloStartFreshOnLaunch,
          soloOpenHistoryOnLaunch: soloOpenHistoryOnLaunch,
        ),
      ),
    );
  }
}

class _ActiveGameCodeCard extends StatelessWidget {
  const _ActiveGameCodeCard({required this.code});

  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      showToast(context, 'Game code copied', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _copy(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.link,
                  color: Color(0xFF22C55E),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypographyText(
                      'Game code',
                      variant: TypographyVariant.body2,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 4),
                    TypographyText(
                      code,
                      variant: TypographyVariant.h3,
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.doc_on_doc,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<GroupGameLaunchResult?> showGroupGameLauncherSheet(
  BuildContext context,
) {
  return showModalBottomSheet<GroupGameLaunchResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GroupGameLauncherSheet(),
  );
}

class GroupGameLaunchResult {
  const GroupGameLaunchResult({required this.mode, this.joinCode});

  final InteractiveStoryLaunchMode mode;
  final String? joinCode;
}

class _GroupGameLauncherSheet extends StatefulWidget {
  const _GroupGameLauncherSheet();

  @override
  State<_GroupGameLauncherSheet> createState() =>
      _GroupGameLauncherSheetState();
}

class _GroupGameLauncherSheetState extends State<_GroupGameLauncherSheet> {
  final _codeController = TextEditingController();
  bool _showCodeInput = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _createGame() {
    Navigator.of(
      context,
    ).pop(const GroupGameLaunchResult(mode: InteractiveStoryLaunchMode.create));
  }

  void _joinPublicRoom() {
    Navigator.of(context).pop(
      const GroupGameLaunchResult(mode: InteractiveStoryLaunchMode.joinPublic),
    );
  }

  void _submitCode() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    Navigator.of(context).pop(
      GroupGameLaunchResult(
        mode: InteractiveStoryLaunchMode.joinByCode,
        joinCode: code,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final canJoin = _codeController.text.trim().isNotEmpty;
    final surface = isDark ? const Color(0xFF111315) : Colors.white;
    final mutedText = isDark ? Colors.white60 : Colors.black54;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(constraints.maxWidth, 520.0);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(
                    width: width,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TypographyText(
                          'Join room',
                          variant: TypographyVariant.h3,
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        const SizedBox(height: 8),
                        TypographyText(
                          'Jump into a public room or play privately with a custom code.',
                          variant: TypographyVariant.body2,
                          color: mutedText,
                          fontSize: 14,
                        ),
                        const SizedBox(height: 22),
                        _GroupGameLauncherTile(
                          icon: CupertinoIcons.sparkles,
                          logoAsset: 'assets/images/app_logo.png',
                          title: 'Join public room',
                          subtitle: 'Match into any vacant room at random.',
                          onTap: _joinPublicRoom,
                        ),
                        const SizedBox(height: 12),
                        _GroupGameLauncherTile(
                          icon: CupertinoIcons.person_2_fill,
                          title: 'Create custom room',
                          subtitle: 'Start a private room and share the code.',
                          onTap: _createGame,
                        ),
                        const SizedBox(height: 12),
                        _GroupGameLauncherTile(
                          icon: CupertinoIcons.link,
                          title: 'Join custom room',
                          subtitle: 'Enter a room code from the host.',
                          onTap: () => setState(() => _showCodeInput = true),
                          isSelected: _showCodeInput,
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: !_showCodeInput
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _codeController,
                                          autofocus: true,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          textInputAction: TextInputAction.go,
                                          onSubmitted: (_) => _submitCode(),
                                          decoration: InputDecoration(
                                            hintText: 'Room code',
                                            filled: true,
                                            fillColor: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.05,
                                                  ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 14,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton.filled(
                                        onPressed: canJoin ? _submitCode : null,
                                        icon: const Icon(
                                          CupertinoIcons.arrow_right,
                                        ),
                                        tooltip: 'Join game',
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupGameLauncherTile extends StatelessWidget {
  const _GroupGameLauncherTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.logoAsset,
    this.isSelected = false,
  });

  final IconData icon;
  final String? logoAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final accent = isSelected ? const Color(0xFF22C55E) : null;
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: isSelected ? 0.12 : 0.07)
          : Colors.black.withValues(alpha: isSelected ? 0.08 : 0.04),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      accent?.withValues(alpha: 0.18) ??
                      (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white),
                  shape: BoxShape.circle,
                ),
                child: logoAsset == null
                    ? Icon(
                        icon,
                        color:
                            accent ?? (isDark ? Colors.white : Colors.black87),
                        size: 21,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(
                          logoAsset!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            icon,
                            color:
                                accent ??
                                (isDark ? Colors.white : Colors.black87),
                            size: 21,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypographyText(
                      title,
                      variant: TypographyVariant.body1,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 3),
                    TypographyText(
                      subtitle,
                      variant: TypographyVariant.body2,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 13,
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 18),
            ],
          ),
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
    required this.isPlayEnabled,
    required this.tags,
    required this.onAddToPlaylist,
    required this.onPlayPressed,
  });

  final Size size;
  final String imageAsset;
  final StorySessionState sessionState;
  final bool isAdded;
  final bool isAddingToPlaylist;
  final bool isPremium;
  final bool isPlayEnabled;
  final List<String> tags;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SmoothCard(
      radius: 36,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 0.85,
            child: BlurredFadeImage(
              imageBuilder: (_) => _HeroImage(image: imageAsset),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0),
                  Colors.black.withValues(alpha: 0.04),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.5, 1],
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
                      isPlayEnabled: isPlayEnabled,
                      onAddPressed: isAddingToPlaylist ? null : onAddToPlaylist,
                      onPlayPressed: onPlayPressed,
                    ),
            ),
          ),
          if (isPremium)
            const Positioned(
              right: 20,
              bottom: 34,
              child: PremiumStar(size: 24),
            ),
          if (tags.isNotEmpty)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: _TagChips(tags: tags),
            ),
        ],
      ),
    );
  }
}

class _SoftImageBackdrop extends StatelessWidget {
  const _SoftImageBackdrop({required this.imageAsset});

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 1.0),
          Colors.black.withValues(alpha: 0.82),
          Colors.black.withValues(alpha: 0.55),
          Colors.black.withValues(alpha: 0.32),
          Colors.black.withValues(alpha: 0.16),
          Colors.black.withValues(alpha: 0.06),
          Colors.black.withValues(alpha: 0.015),
          Colors.transparent,
        ],
        stops: const [0.0, 0.15, 0.3, 0.45, 0.58, 0.7, 0.8, 0.9],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
        child: Opacity(
          opacity: 0.38,
          child: SizedBox.expand(child: _HeroImage(image: imageAsset)),
        ),
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
    required this.isPlayEnabled,
    required this.onAddPressed,
    required this.onPlayPressed,
  });

  final bool isAdded;
  final bool isLoading;
  final bool isPlayEnabled;
  final VoidCallback? onAddPressed;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPillButton(
          onPressed: isPlayEnabled ? onPlayPressed : null,
          icon: CupertinoIcons.play_fill,
          label: isPlayEnabled ? 'Play' : '...',
          backgroundColor: context.actionButtonBackground,
          foregroundColor: context.actionButtonForeground,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          variant: TypographyVariant.body1,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(width: 10),
        _AddToListIconButton(
          isAdded: isAdded,
          isLoading: isLoading,
          onPressed: onAddPressed,
        ),
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

class _CachedStoryDescription extends StatelessWidget {
  const _CachedStoryDescription({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final description = text.trim();
    if (description.isEmpty) return const _StoryDetailShimmer();
    return TypographyText(
      description,
      variant: TypographyVariant.body1,
      color: context.secondaryTextColor,
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
    final chipBg = Colors.black.withValues(alpha: 0.58);
    final chipBorder = Colors.white.withValues(alpha: 0.05);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: chipBorder),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
        const ShimmerParagraph(
          lines: 3,
          lineHeight: 14,
          lineSpacing: 10,
          lastLineWidth: 0.7,
        ),
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
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TypographyText(
              message,
              variant: TypographyVariant.body2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              CupertinoIcons.xmark,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
