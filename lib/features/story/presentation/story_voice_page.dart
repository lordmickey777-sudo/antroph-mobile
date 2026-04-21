import 'dart:async';

import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/home/presentation/voice_chat_screen.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoryVoicePage extends ConsumerStatefulWidget {
  const StoryVoicePage({
    super.key,
    required this.storyId,
    this.storyTitle,
    this.storySubtitle,
    this.storyImage,
    this.mascotConfig,
    this.isAddedToPlaylist = false,
    this.showMascotFace = true,
  });

  final String storyId;
  final String? storyTitle;
  final String? storySubtitle;
  final String? storyImage;
  final MascotConfig? mascotConfig;
  final bool isAddedToPlaylist;
  final bool showMascotFace;

  @override
  ConsumerState<StoryVoicePage> createState() => _StoryVoicePageState();
}

class _StoryVoicePageState extends ConsumerState<StoryVoicePage> {
  VoiceChatController? _voiceController;
  bool _requestedAutoStart = false;
  bool _lastIsMuted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceController = ref.read(voiceChatControllerProvider.notifier);
      _requestedAutoStart = true;
      unawaited(_ensureConnectedAndMaybeStart());
    });
  }

  Future<void> _ensureConnectedAndMaybeStart() async {
    final controller = ref.read(voiceChatControllerProvider.notifier);
    await controller.ensureStorySessionConnected(widget.storyId);
    if (!mounted) return;
    _unmuteAndMaybeStart();
  }

  void _unmuteAndMaybeStart() {
    final controller = ref.read(voiceChatControllerProvider.notifier);
    final state = ref.read(voiceChatControllerProvider);
    if (state.isMuted) {
      controller.toggleMute();
      return;
    }
    if (state.isSessionReady && !state.isBusy && !state.isRecording) {
      unawaited(controller.startRecording());
    }
  }

  void _openChatSheet(BuildContext context) {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final voiceState = ref.read(voiceChatControllerProvider);
    if (!voiceState.isMuted) {
      voiceController.toggleMute();
    }
    unawaited(voiceController.stopPlayback());
    Navigator.of(context).pop();
  }

  void _openStoryDetails(BuildContext context) {
    showAppBottomSheet(
      context: context,
      builder: (_, scrollController) => StorySheetContent(
        storyId: widget.storyId,
        title: (widget.storyTitle?.isNotEmpty ?? false) ? widget.storyTitle! : 'Story',
        subtitle: widget.storySubtitle ?? '',
        imageAsset: (widget.storyImage?.isNotEmpty ?? false)
            ? widget.storyImage!
            : 'assets/images/default.png',
        mascotConfig: widget.mascotConfig,
        isAdded: widget.isAddedToPlaylist,
        scrollController: scrollController,
      ),
    );
  }

  Future<bool> _handleBack() async {
    final controller = ref.read(voiceChatControllerProvider.notifier);
    final state = ref.read(voiceChatControllerProvider);
    await controller.stopPlayback();
    if (!state.isMuted) {
      controller.toggleMute();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceChatControllerProvider);
    _lastIsMuted = voiceState.isMuted;
    final voiceController = ref.read(voiceChatControllerProvider.notifier);

    ref.listen<VoiceChatState>(voiceChatControllerProvider, (prev, next) {
      if (!_requestedAutoStart) return;
      if (next.isMuted) return;
      if (next.isBusy) return;
      if (!next.isSessionReady) return;
      if (next.isRecording) return;
      final becameReady = !(prev?.isSessionReady ?? false) && next.isSessionReady;
      if (!becameReady) return;
      unawaited(voiceController.startRecording());
    });

    final title = (widget.storyTitle?.isNotEmpty ?? false) ? widget.storyTitle! : 'Aura';

    return WillPopScope(
      onWillPop: _handleBack,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background_2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            flexibleSpace: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF8000000), Color(0x90000000), Color(0x00000000)],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
            title: TypographyText(
              title,
              variant: TypographyVariant.h4,
              color: context.primaryTextColor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              fontSize: 18,
            ),
            actions: [
              IconButton(
                onPressed: () => _openStoryDetails(context),
                icon: const Icon(CupertinoIcons.info_circle),
                color: context.primaryTextColor,
                tooltip: 'Story details',
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: VoiceChatScreen(
              isStoryMode: true,
              mascotConfig: widget.mascotConfig,
              expressionStream: voiceController.mascotExpressionStream,
              showMascotFace: widget.showMascotFace,
              onOpenChat: () => _openChatSheet(context),
              onEnd: () {
                unawaited(voiceController.endStorySession());
                final nav = Navigator.of(context);
                var pops = 0;
                while (nav.canPop() && pops < 2) {
                  nav.pop();
                  pops++;
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
