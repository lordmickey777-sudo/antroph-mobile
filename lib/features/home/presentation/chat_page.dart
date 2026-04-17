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
  String? _lastPrecachedMascotId;
  VoiceChatController? _voiceController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceController = ref.read(voiceChatControllerProvider.notifier);
      _autoStartListening();
    });

    if (widget.isStoryMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (_voiceController != null) {
      if (widget.isStoryMode) {
        _voiceController!.pauseStorySession();
        _voiceController!.endStorySession();
      } else {
        _voiceController!.stopPlayback();
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!widget.isStoryMode) {
        ref.read(chatControllerProvider.notifier).pause();
      }
      if (widget.isStoryMode) {
        voiceController.pauseStorySession();
      } else {
        voiceController.stopPlayback();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!widget.isStoryMode) {
        ref.read(chatControllerProvider.notifier).resume();
      }
      if (widget.isStoryMode) {
        voiceController.resumePausedSession();
      }
    }
  }

  @override
  void didPushNext() {
    if (!widget.isStoryMode) {
      ref.read(chatControllerProvider.notifier).pause();
    }
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (widget.isStoryMode) {
      voiceController.pauseStorySession();
    } else {
      voiceController.stopPlayback();
    }
  }

  @override
  void didPopNext() {
    if (!widget.isStoryMode) {
      ref.read(chatControllerProvider.notifier).resume();
    }
    if (widget.isStoryMode) {
      ref.read(voiceChatControllerProvider.notifier).resumePausedSession();
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
        body: SafeArea(
          child: VoiceChatScreen(
            isStoryMode: widget.isStoryMode,
            mascotConfig: mascotConfig,
            expressionStream: voiceController.mascotExpressionStream,
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

