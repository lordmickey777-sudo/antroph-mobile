import 'dart:async';

import 'package:antroph_mobile/core/navigation/app_route_observer.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/home/presentation/chat_bottom_sheet.dart';
import 'package:antroph_mobile/features/home/presentation/voice_chat_screen.dart';
import 'package:antroph_mobile/features/home/providers/chat_provider.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/models/story_detail.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/widgets/app_action_button.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    this.storyTitle,
    this.storyId,
    this.storySessionId,
    this.mascotConfig,
    this.storySubtitle,
    this.storyImage,
    this.isAddedToPlaylist = false,
  });

  final String? storyTitle;

  /// If provided, starts a new story voice session with this story ID
  final String? storyId;

  /// If provided, resumes an existing story voice session
  final String? storySessionId;
  final MascotConfig? mascotConfig;
  final String? storySubtitle;
  final String? storyImage;
  final bool isAddedToPlaylist;

  /// Whether this chat page is in story mode
  bool get isStoryMode => storyId != null || storySessionId != null;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<void>? _modalRoute;
  bool _storySessionStarted = false;
  bool _showContinueOverlay = false;
  bool _pausedForRoute = false;
  bool _pausedForLifecycle = false;
  String? _lastPrecachedMascotId;
  VoiceChatController? _voiceController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _voiceController = ref.read(voiceChatControllerProvider.notifier);
      _autoStartListening();
    });

    if (widget.isStoryMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initStorySession();
      });
    }
  }

  void _initStorySession() {
    if (_storySessionStarted) return;
    _storySessionStarted = true;

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (widget.storySessionId != null) {
      voiceController.resumeStorySession(widget.storySessionId!);
    } else if (widget.storyId != null) {
      voiceController.startStorySession(widget.storyId!);
    }
  }

  Future<void> _autoStartListening() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Story mode auto-starts via _scheduleAutoListen after AI intro.
    if (widget.isStoryMode) return;

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final voiceState = ref.read(voiceChatControllerProvider);
    if (!voiceState.isBusy && !voiceState.isMuted) {
      voiceController.startRecording();
    }
  }

  void _openChatSheet(
    BuildContext context,
    VoiceChatController voiceController,
    VoiceChatState voiceState,
  ) {
    final wasMuted = voiceState.isMuted;
    if (!wasMuted) {
      voiceController.toggleMute();
    }
    voiceController.stopPlayback();

    showAppBottomSheet(
      context: context,
      backgroundColor: context.backgroundColor,
      builder: (ctx, scrollController) =>
          ChatBottomSheet(scrollController: scrollController),
    ).then((_) {
      if (!wasMuted && mounted) {
        ref.read(voiceChatControllerProvider.notifier).toggleMute();
      }
    });
  }

  void _openStoryDetails(BuildContext context, StoryDetailDto? detail) {
    final storyId = widget.storyId;
    if (storyId == null) return;

    showAppBottomSheet(
      context: context,
      builder: (_, scrollController) => StorySheetContent(
        storyId: storyId,
        title: (detail?.title.isNotEmpty ?? false)
            ? detail!.title
            : (widget.storyTitle?.isNotEmpty ?? false)
            ? widget.storyTitle!
            : 'Story',
        subtitle: (detail?.description.isNotEmpty ?? false)
            ? detail!.description
            : (widget.storySubtitle ?? ''),
        imageAsset: (widget.storyImage?.isNotEmpty ?? false)
            ? widget.storyImage!
            : 'assets/images/default.png',
        mascotConfig: widget.mascotConfig ?? detail?.effectiveMascot,
        isAdded: widget.isAddedToPlaylist,
        isPremium: detail?.isPremium ?? false,
        scrollController: scrollController,
      ),
    );
  }

  void _precacheMascot(MascotConfig mascot) {
    final mascotId = mascot.id.trim();
    if (mascotId.isEmpty || mascotId == _lastPrecachedMascotId) return;
    final riveRef = mascot.riveAssetUrl.trim();
    if (riveRef.isEmpty || riveRef.startsWith('assets/')) return;
    _lastPrecachedMascotId = mascotId;
    unawaited(() async {
      try {
        await ref.read(riveRegistryServiceProvider).cacheMascotConfig(mascot);
      } catch (_) {}
    }());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _modalRoute) {
      if (_modalRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _modalRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    if (_modalRoute != null) {
      appRouteObserver.unsubscribe(this);
    }
    final voiceController = _voiceController;
    if (voiceController != null) {
      final isStoryMode = widget.isStoryMode;
      Future<void>.microtask(() async {
        if (isStoryMode) {
          voiceController.pauseStorySession();
          await voiceController.endStorySession();
        } else {
          await voiceController.stopPlayback();
        }
      });
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _pauseStoryForReturn() {
    ref.read(voiceChatControllerProvider.notifier).pauseStorySession();
  }

  void _showContinuePrompt() {
    if (!mounted) return;
    setState(() => _showContinueOverlay = true);
  }

  Future<void> _continueSpeaking() async {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    setState(() {
      _showContinueOverlay = false;
      _pausedForRoute = false;
      _pausedForLifecycle = false;
    });
    if (widget.isStoryMode) {
      await voiceController.resumePausedSession();
      return;
    }

    ref.read(chatControllerProvider.notifier).resume();
    final voiceState = ref.read(voiceChatControllerProvider);
    if (!voiceState.isBusy && !voiceState.isMuted) {
      voiceController.startRecording();
    }
  }

  void _dismissContinuePrompt() {
    setState(() {
      _showContinueOverlay = false;
      _pausedForRoute = false;
      _pausedForLifecycle = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!widget.isStoryMode) {
        _pausedForLifecycle = true;
        ref.read(chatControllerProvider.notifier).pause();
      }
      if (widget.isStoryMode) {
        _pausedForLifecycle = true;
        _pauseStoryForReturn();
      } else {
        voiceController.stopPlayback();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!widget.isStoryMode) {
        if (_pausedForLifecycle) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showContinuePrompt();
          });
        }
      }
      if (widget.isStoryMode && _pausedForLifecycle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showContinuePrompt();
        });
      }
    }
  }

  @override
  void didPushNext() {
    if (!widget.isStoryMode) {
      _pausedForRoute = true;
      ref.read(chatControllerProvider.notifier).pause();
    }
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (widget.isStoryMode) {
      _pausedForRoute = true;
      _pauseStoryForReturn();
    } else {
      voiceController.stopPlayback();
    }
  }

  @override
  void didPopNext() {
    if (!widget.isStoryMode) {
      if (_pausedForRoute) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showContinuePrompt();
        });
      }
    }
    if (widget.isStoryMode && _pausedForRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showContinuePrompt();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceChatControllerProvider);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);

    final storyDetail = widget.storyId != null
        ? ref.watch(storyDetailProvider(widget.storyId!)).asData?.value
        : null;
    MascotConfig? mascotConfig = widget.mascotConfig;
    final detailedMascot = storyDetail?.effectiveMascot;
    if (widget.storyId != null &&
        (mascotConfig == null ||
            ((detailedMascot?.localAssetPath ?? '').trim().isNotEmpty))) {
      mascotConfig = detailedMascot;
    }
    if (mascotConfig != null) {
      _precacheMascot(mascotConfig);
    }

    final isDark = context.isDarkMode;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 76,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: TypographyText(
            widget.storyTitle ?? 'Voice chat',
            variant: TypographyVariant.h4,
            color: context.primaryTextColor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          actions: [
            if (widget.storyId != null)
              IconButton(
                onPressed: () => _openStoryDetails(context, storyDetail),
                icon: const Icon(CupertinoIcons.info_circle),
                color: context.primaryTextColor,
                tooltip: 'Story details',
              ),
            _ChatButton(
              onTap: () => _openChatSheet(context, voiceController, voiceState),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: VoiceChatScreen(
                isStoryMode: widget.isStoryMode,
                mascotConfig: mascotConfig,
                expressionStream: voiceController.mascotExpressionStream,
                onOpenChat: () =>
                    _openChatSheet(context, voiceController, voiceState),
              ),
            ),
            if (_showContinueOverlay)
              _ContinueSpeakingOverlay(
                onContinue: _continueSpeaking,
                onDismiss: _dismissContinuePrompt,
              ),
          ],
        ),
      ),
    );
  }
}

class _ContinueSpeakingOverlay extends StatelessWidget {
  const _ContinueSpeakingOverlay({
    required this.onContinue,
    required this.onDismiss,
  });

  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final panelColor = isDark ? const Color(0xFF171717) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final mutedText = isDark ? Colors.white70 : Colors.black54;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.52),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.actionButtonBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.mic_fill,
                        color: context.actionButtonForeground,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TypographyText(
                      'Continue speaking with Aura?',
                      variant: TypographyVariant.h4,
                      color: context.primaryTextColor,
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w800,
                    ),
                    const SizedBox(height: 8),
                    TypographyText(
                      'Your conversation was paused while you were away.',
                      variant: TypographyVariant.body2,
                      color: mutedText,
                      textAlign: TextAlign.center,
                      fontSize: 13,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppPillButton(
                            label: 'No',
                            onPressed: onDismiss,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.09)
                                : Colors.black.withValues(alpha: 0.06),
                            foregroundColor: context.primaryTextColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppPillButton(
                            label: 'Yes',
                            icon: CupertinoIcons.play_fill,
                            onPressed: onContinue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Open chat',
      icon: Icon(
        Icons.chat_bubble_outline_rounded,
        color: context.primaryTextColor,
        size: 22,
      ),
    );
  }
}
