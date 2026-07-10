import 'dart:async';
import 'dart:math' as math;

import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/models/realtime_voice_bridge_models.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/chat_bubble.dart';
import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/models/story_detail.dart';
import 'package:antroph_mobile/features/story/models/story_session.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/features/story/presentation/story_voice_page.dart';
import 'package:antroph_mobile/features/story/providers/interactive_story_provider.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/features/story/widgets/interactive_story_renderer.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

enum InteractiveStoryLaunchMode { create, joinByCode, joinPublic }

bool _usesDynamicStoryOptions(StoryDetailDto detail) {
  final template = (detail.interactiveConfig['template'] as String?)?.trim();
  if (template == 'dynamic_story_menu') return true;
  final title = detail.title.toLowerCase();
  if (_isBeneathTheSurfaceTitle(title)) return true;
  final context = detail.context.toLowerCase();
  return context.contains('three stories to explore') &&
      context.contains('generate three') &&
      context.contains('story');
}

bool _isBeneathTheSurfaceTitle(String title) {
  return title.toLowerCase().contains('beneath the surface');
}

class StoryChatFlowPage extends ConsumerStatefulWidget {
  const StoryChatFlowPage({
    super.key,
    required this.storyId,
    this.storyTitle,
    this.storySessionId,
    this.mascotConfig,
    this.storySubtitle,
    this.storyImage,
    this.isAddedToPlaylist = false,
    this.initialInteractionMode,
    this.voicePageBuilder,
    this.interactiveLaunchMode = InteractiveStoryLaunchMode.create,
    this.joinCode,
  });

  final String storyId;
  final String? storyTitle;
  final String? storySessionId;
  final MascotConfig? mascotConfig;
  final String? storySubtitle;
  final String? storyImage;
  final bool isAddedToPlaylist;
  final String? initialInteractionMode;
  final WidgetBuilder? voicePageBuilder;
  final InteractiveStoryLaunchMode interactiveLaunchMode;
  final String? joinCode;

  @override
  ConsumerState<StoryChatFlowPage> createState() => _StoryChatFlowPageState();
}

class _StoryChatFlowPageState extends ConsumerState<StoryChatFlowPage>
    with WidgetsBindingObserver {
  bool _sessionStarted = false;
  bool _isLeavingGame = false;
  bool _isExitingStory = false;
  bool _connectionErrorDialogOpen = false;
  int _storyConnectionRetryAttempts = 0;
  int _textHistoryRevision = 0;
  String? _lastReadyStorySessionId;
  String? _textStorySessionId;
  VoiceChatController? _voiceController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _voiceController = ref.read(voiceChatControllerProvider.notifier);
      _initStorySessionAndChatMode();
    });
  }

  void _initStorySessionAndChatMode() {
    if (_sessionStarted) return;
    _sessionStarted = true;
    unawaited(_initByStoryMode());
  }

  Future<void> _initByStoryMode() async {
    var interactionMode = 'narrative';
    try {
      final detail = await ref.read(storyDetailProvider(widget.storyId).future);
      if (!mounted) return;
      interactionMode = detail.interactionMode;
    } catch (_) {
      if (!mounted) return;
      interactionMode = 'narrative';
    }

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (interactionMode != 'narrative') {
      unawaited(voiceController.stopPlayback());
      final voiceState = ref.read(voiceChatControllerProvider);
      if (!voiceState.isMuted) {
        voiceController.toggleMute();
      }
      return;
    }

    // Text-first narrative mode uses the REST story API. Keep voice idle and
    // silent until the user explicitly opens voice mode.
    unawaited(voiceController.stopPlayback());
    final voiceState = ref.read(voiceChatControllerProvider);
    if (!voiceState.isMuted) {
      voiceController.toggleMute();
    }
  }

  void _openStoryDetails(BuildContext context) {
    final session = ref.read(interactiveStoryProvider).session;
    showAppBottomSheet(
      context: context,
      builder: (_, scrollController) => StorySheetContent(
        storyId: widget.storyId,
        title: (widget.storyTitle?.isNotEmpty ?? false)
            ? widget.storyTitle!
            : 'Story',
        subtitle: widget.storySubtitle ?? '',
        imageAsset: (widget.storyImage?.isNotEmpty ?? false)
            ? widget.storyImage!
            : 'assets/images/default.png',
        mascotConfig: widget.mascotConfig,
        isAdded: widget.isAddedToPlaylist,
        activeGameCode: session?.joinCode,
        scrollController: scrollController,
      ),
    );
  }

  Future<void> _openVoicePage() async {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final voiceState = ref.read(voiceChatControllerProvider);

    unawaited(
      voiceController.ensureStorySessionConnected(
        widget.storyId,
        preferredSessionId: _textStorySessionId ?? widget.storySessionId,
      ),
    );

    // Ensure we aren't recording while transitioning.
    if (!voiceState.isMuted) {
      voiceController.toggleMute();
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            widget.voicePageBuilder ??
            (_) => StoryVoicePage(
              storyId: widget.storyId,
              storyTitle: widget.storyTitle,
              storySubtitle: widget.storySubtitle,
              storyImage: widget.storyImage,
              mascotConfig: widget.mascotConfig,
              isAddedToPlaylist: widget.isAddedToPlaylist,
            ),
      ),
    );

    if (!mounted) return;
    setState(() => _textHistoryRevision += 1);
  }

  bool _isInteractiveStory() {
    final detail = ref.read(storyDetailProvider(widget.storyId)).asData?.value;
    final mode =
        detail?.interactionMode ??
        ref.read(interactiveStoryProvider).session?.interactionMode ??
        'narrative';
    return mode != 'narrative';
  }

  Future<void> _handleBackPressed() async {
    if (_isInteractiveStory()) {
      await _leaveGame(confirm: true);
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (_) => const _LeaveGameDialog(
        title: 'Leave this story?',
        message:
            'You will exit the story chat and return to the story details page.',
        icon: CupertinoIcons.book_fill,
        iconBackground: Colors.white24,
        iconColor: Colors.white,
      ),
    );
    if (shouldLeave != true || !mounted) return;

    final navigator = Navigator.of(context);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    _isExitingStory = true;
    await voiceController.endStorySession();
    await voiceController.stopPlayback();
    if (mounted) {
      navigator.pop();
    }
  }

  Future<void> _leaveGame({bool confirm = false}) async {
    if (_isLeavingGame) return;

    final navigator = Navigator.of(context);
    final shouldLeave = confirm
        ? await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return const _LeaveGameDialog();
            },
          )
        : true;

    if (shouldLeave != true || !mounted) return;

    final loadingNavigator = Navigator.of(context, rootNavigator: true);
    setState(() => _isLeavingGame = true);
    unawaited(_showLeavingGameDialog());
    await ref.read(interactiveStoryProvider.notifier).leaveSession();

    if (!mounted) return;
    if (loadingNavigator.canPop()) {
      loadingNavigator.pop();
    }
    setState(() => _isLeavingGame = false);

    final leftSession = ref.read(interactiveStoryProvider).session == null;
    if (leftSession && mounted) {
      navigator.pop();
    }
  }

  Future<void> _showLeavingGameDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const PopScope(canPop: false, child: _LeavingGameDialog());
      },
    );
  }

  bool _shouldShowStoryConnectionDialog(VoiceChatState state) {
    if (_isExitingStory || _isLeavingGame || _connectionErrorDialogOpen) {
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    if (_isInteractiveStory()) return false;
    if (!state.isStoryMode) return false;
    return state.phase == RealtimeVoicePhase.error ||
        state.phase == RealtimeVoicePhase.closed;
  }

  Future<void> _showStoryConnectionErrorDialog(VoiceChatState state) async {
    if (_connectionErrorDialogOpen || !mounted) return;

    setState(() => _connectionErrorDialogOpen = true);
    final shouldRetry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const StoryConnectionErrorDialog(),
    );

    if (!mounted) return;
    setState(() => _connectionErrorDialogOpen = false);
    if (shouldRetry != true) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;

    _storyConnectionRetryAttempts += 1;
    final preferredSessionId = (_lastReadyStorySessionId ?? '').trim();
    final canResumeKnownSession =
        _storyConnectionRetryAttempts == 1 && preferredSessionId.isNotEmpty;
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    await voiceController.ensureStorySessionConnected(
      widget.storyId,
      preferredSessionId: canResumeKnownSession ? preferredSessionId : null,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isExitingStory = true;
    final voiceController = _voiceController;
    if (voiceController != null) {
      Future<void>.microtask(() async {
        await voiceController.endStorySession();
        await voiceController.stopPlayback();
      });
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final voiceState = ref.read(voiceChatControllerProvider);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (voiceState.isStoryMode && voiceState.storySession != null) {
        voiceController.pauseStorySession();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (voiceState.isStoryMode &&
          voiceState.phase == RealtimeVoicePhase.paused) {
        voiceController.resumePausedSession();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceChatState>(voiceChatControllerProvider, (previous, next) {
      if (!mounted) return;
      if (next.isSessionReady) {
        _storyConnectionRetryAttempts = 0;
        _lastReadyStorySessionId = next.storySession?.sessionId;
      }
      final error = next.errorMessage;
      if (error != null &&
          error.isNotEmpty &&
          error != (previous?.errorMessage ?? '') &&
          !_shouldShowStoryConnectionDialog(next)) {
        showToast(context, next.isStoryMode ? 'Story connection error' : error);
      }
      final phaseChanged = next.phase != previous?.phase;
      final errorChanged = next.errorMessage != previous?.errorMessage;
      if ((phaseChanged || errorChanged) &&
          _shouldShowStoryConnectionDialog(next)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_shouldShowStoryConnectionDialog(next)) return;
          unawaited(_showStoryConnectionErrorDialog(next));
        });
      }
    });

    final title = (widget.storyTitle?.isNotEmpty ?? false)
        ? widget.storyTitle!
        : 'Chat';
    final storyDetail = ref.watch(storyDetailProvider(widget.storyId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
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
            leading: IconButton(
              onPressed: _isLeavingGame ? null : _handleBackPressed,
              icon: const Icon(CupertinoIcons.back),
              color: context.primaryTextColor,
              tooltip: 'Back',
            ),
            titleSpacing: 16,
            flexibleSpace: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF8000000),
                    Color(0x90000000),
                    Color(0x00000000),
                  ],
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
              fontSize: 18,
              softWrap: false,
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
          body: Builder(
            builder: (context) {
              final detail = storyDetail.asData?.value;
              final interactionMode =
                  widget.initialInteractionMode ??
                  detail?.interactionMode ??
                  (storyDetail.hasError ? 'narrative' : null);

              if (interactionMode == null) {
                return const _StorySessionLoadingShell();
              }
              if (interactionMode != 'narrative') {
                return _InteractiveStoryTab(
                  storyId: widget.storyId,
                  interactionMode: interactionMode,
                  launchMode: widget.interactiveLaunchMode,
                  joinCode: widget.joinCode,
                  onCall: _openVoicePage,
                  onLeave: _leaveGame,
                );
              }
              return _StoryTextChatTab(
                storyId: widget.storyId,
                storyTitle: title,
                onCall: _openVoicePage,
                onSessionReady: (sessionId) => _textStorySessionId = sessionId,
                historyRevision: _textHistoryRevision,
                enableStoryOptions: detail != null
                    ? _usesDynamicStoryOptions(detail)
                    : _isBeneathTheSurfaceTitle(title),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InteractiveStoryTab extends ConsumerStatefulWidget {
  const _InteractiveStoryTab({
    required this.storyId,
    required this.interactionMode,
    required this.launchMode,
    this.joinCode,
    required this.onCall,
    required this.onLeave,
  });

  final String storyId;
  final String interactionMode;
  final InteractiveStoryLaunchMode launchMode;
  final String? joinCode;
  final VoidCallback onCall;
  final Future<void> Function() onLeave;

  @override
  ConsumerState<_InteractiveStoryTab> createState() =>
      _InteractiveStoryTabState();
}

class _InteractiveStoryTabState extends ConsumerState<_InteractiveStoryTab> {
  final _textController = TextEditingController();
  bool _canSend = false;
  bool _started = false;
  String? _lastGenerationFailureKey;
  String? _stickyGenerationError;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final next = _textController.text.trim().isNotEmpty;
      if (next != _canSend) setState(() => _canSend = next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    final code = widget.joinCode?.trim() ?? '';
    if (widget.launchMode == InteractiveStoryLaunchMode.joinPublic) {
      unawaited(
        ref
            .read(interactiveStoryProvider.notifier)
            .joinPublic(storyId: widget.storyId),
      );
      return;
    }
    if (widget.launchMode == InteractiveStoryLaunchMode.joinByCode &&
        code.isNotEmpty) {
      unawaited(ref.read(interactiveStoryProvider.notifier).joinByCode(code));
      return;
    }
    unawaited(
      ref
          .read(interactiveStoryProvider.notifier)
          .start(
            storyId: widget.storyId,
            interactionMode: widget.interactionMode,
          ),
    );
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    final session = ref.read(interactiveStoryProvider).session;
    final state = session?.interactiveState ?? const <String, dynamic>{};
    final isGroupQuizChat =
        state['template'] == 'quiz' &&
        state['session_type'] == 'group' &&
        state['phase'] == 'showing_results';
    final notifier = ref.read(interactiveStoryProvider.notifier);
    unawaited(
      isGroupQuizChat
          ? notifier.submitPlayerChat(text)
          : notifier.submitText(text),
    );
  }

  void _handleGenerationFailure(InteractiveStoryState next) {
    final session = next.session;
    final interactiveState = session?.interactiveState;
    final phase = interactiveState?['phase'] as String?;
    if (session == null || interactiveState == null) return;

    if (phase != 'generation_failed') {
      if (!next.isRetryingGeneration &&
          (_stickyGenerationError != null ||
              _lastGenerationFailureKey != null)) {
        setState(() {
          _stickyGenerationError = null;
          _lastGenerationFailureKey = null;
        });
      }
      return;
    }

    final message =
        (interactiveState['generation_error'] as String?)?.trim().isNotEmpty ==
            true
        ? (interactiveState['generation_error'] as String).trim()
        : 'The next question could not be loaded.';
    final failureKey =
        '${session.sessionId}:${interactiveState['current_round']}:$message';

    if (_stickyGenerationError != message) {
      setState(() => _stickyGenerationError = message);
    }
    if (_lastGenerationFailureKey == failureKey) return;

    _lastGenerationFailureKey = failureKey;
    showToast(context, message, success: false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<InteractiveStoryState>(interactiveStoryProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      _handleGenerationFailure(next);
      final error = next.error;
      if (error != null &&
          error.isNotEmpty &&
          error != (previous?.error ?? '')) {
        showToast(context, error, success: false);
        ref.read(interactiveStoryProvider.notifier).clearError();
        if (widget.launchMode == InteractiveStoryLaunchMode.joinPublic &&
            next.session == null &&
            Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    final state = ref.watch(interactiveStoryProvider);
    final currentUserId = ref.watch(authControllerProvider).value?.id;
    final notifier = ref.read(interactiveStoryProvider.notifier);
    final session = state.session;
    final isQuizSession = _isQuizSession(session);
    final phase = (session?.interactiveState['phase'] as String?) ?? '';
    final sessionType =
        (session?.interactiveState['session_type'] as String?) ?? '';
    final isSoloQuizTextPhase =
        isQuizSession &&
        sessionType == 'solo' &&
        {
          'topic_selection',
          'mode_selection',
          'discussion',
          'timer_selection',
          'post_question_prompt',
        }.contains(phase);
    final isGroupQuizSession =
        isQuizSession && session?.interactiveState['session_type'] == 'group';
    final isGroupQuizChatPhase =
        isGroupQuizSession && phase == 'showing_results';
    final canRetryQuestionGeneration = _canRetryQuizGeneration(
      session,
      currentUserId,
    );
    final questionGenerationFailed = phase == 'generation_failed';
    final showQuestionGenerationOverlay =
        isQuizSession &&
        session != null &&
        (questionGenerationFailed ||
            state.isGenerationTakingLong ||
            state.isRetryingGeneration);
    final questionGenerationRetrying = state.isRetryingGeneration;
    final disableQuizGameControls =
        isGroupQuizSession &&
        (phase == 'generation_failed' || state.isRetryingGeneration);
    final questionGenerationError =
        (session?.interactiveState['generation_error'] as String?)?.trim();
    final effectiveQuestionGenerationError =
        questionGenerationError?.isNotEmpty == true
        ? questionGenerationError!
        : _stickyGenerationError;
    final isDark = context.isDarkMode;
    final mutedSurface = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF3F3F3);
    final mutedText = isDark ? Colors.white60 : Colors.black54;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: session == null
                  ? _StorySessionLoadingShell(
                      title:
                          widget.launchMode ==
                              InteractiveStoryLaunchMode.joinPublic
                          ? 'SEARCHING...'
                          : 'LOADING...',
                    )
                  : RefreshIndicator(
                      onRefresh: notifier.refresh,
                      child: InteractiveStoryRenderer(
                        session: session,
                        currentUserId: currentUserId,
                        pendingKeys: state.pendingInputKeys,
                        pendingTextMessages: state.pendingTextMessages,
                        localQuizSelections: state.localQuizSelections,
                        streamingAssistantText: state.streamingAssistantText,
                        recentStreamedAssistantText:
                            state.recentStreamedAssistantText,
                        isAdvancingQuestion: state.isAdvancingQuestion,
                        onRetryGeneration: () => unawaited(
                          notifier.recoverGeneration(
                            canRetry: canRetryQuestionGeneration,
                          ),
                        ),
                        onAdvanceQuestion: () =>
                            unawaited(notifier.advanceQuestion()),
                        onReplay: () => unawaited(
                          notifier.restart(
                            storyId: widget.storyId,
                            interactionMode: widget.interactionMode,
                          ),
                        ),
                        onLeave: () => unawaited(widget.onLeave()),
                        onChoice: (optionId) => unawaited(
                          notifier.submitOption(
                            optionId: optionId,
                            inputType: 'option_select',
                          ),
                        ),
                        onQuizAnswer: (optionId, questionId) => unawaited(
                          notifier.submitOption(
                            optionId: optionId,
                            inputType: 'quiz_answer',
                            questionId: questionId,
                          ),
                        ),
                      ),
                    ),
            ),
            if (session != null &&
                (!isQuizSession || isSoloQuizTextPhase || isGroupQuizChatPhase))
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: mutedSurface,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: TextField(
                            controller: _textController,
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            cursorColor: context.primaryTextColor,
                            style: TextStyle(
                              color: context.primaryTextColor,
                              fontSize: 16,
                              height: 1.35,
                            ),
                            decoration: InputDecoration(
                              hintText: switch (phase) {
                                'topic_selection' => 'Topic or category',
                                'mode_selection' =>
                                  'Discuss first or quiz now?',
                                'timer_selection' => 'Timed or untimed?',
                                'post_question_prompt' => 'Reply here',
                                'showing_results' => 'Message the room',
                                _ => 'Message',
                              },
                              hintStyle: TextStyle(
                                color: mutedText,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.fromLTRB(
                                18,
                                14,
                                18,
                                14,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CircleIconButton(
                        icon: CupertinoIcons.paperplane_fill,
                        tooltip: 'Send',
                        background: _canSend
                            ? (isDark ? Colors.white : Colors.black)
                            : mutedSurface,
                        foreground: _canSend
                            ? (isDark ? Colors.black : Colors.white)
                            : mutedText,
                        onTap: _canSend ? _sendText : () {},
                      ),
                      const SizedBox(width: 8),
                      _CircleIconButton(
                        icon: Icons.call_rounded,
                        tooltip: 'Voice',
                        background: const Color(0xFF22C55E),
                        foreground: Colors.white,
                        onTap: widget.onCall,
                      ),
                    ],
                  ),
                ),
              )
            else if (session != null)
              _QuizGameBottomBar(
                onCall: widget.onCall,
                disabled: disableQuizGameControls,
              ),
          ],
        ),
        if (isGroupQuizSession && session != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: _ActiveParticipantsStrip(
                participants: session.participants,
              ),
            ),
          ),
        if (showQuestionGenerationOverlay)
          Positioned.fill(
            child: _QuestionGenerationOverlay(
              isLoading: questionGenerationRetrying,
              isFailure: questionGenerationFailed,
              canRetry: canRetryQuestionGeneration,
              message: questionGenerationFailed
                  ? effectiveQuestionGenerationError?.isNotEmpty == true
                        ? effectiveQuestionGenerationError!
                        : canRetryQuestionGeneration
                        ? 'The next question could not be loaded.'
                        : 'The host needs to retry this question. Reconnect to stay in sync.'
                  : 'The question is taking longer than expected. Reconnect to check its latest status.',
              onRetry: questionGenerationRetrying
                  ? null
                  : () => unawaited(
                      notifier.recoverGeneration(
                        canRetry: canRetryQuestionGeneration,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _QuestionGenerationOverlay extends StatelessWidget {
  const _QuestionGenerationOverlay({
    required this.isLoading,
    required this.isFailure,
    required this.canRetry,
    required this.message,
    required this.onRetry,
  });

  final bool isLoading;
  final bool isFailure;
  final bool canRetry;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surface = isDark ? const Color(0xFF111214) : Colors.white;
    final subdued = isDark ? Colors.white70 : const Color(0xFF5F6368);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Material(
      color: Colors.black.withValues(alpha: isDark ? 0.62 : 0.38),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.46 : 0.20),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF2563EB),
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              color: Color(0xFF111827),
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoading
                                ? 'Checking connection'
                                : isFailure
                                ? canRetry
                                      ? 'Question failed to load'
                                      : 'Waiting for the host'
                                : 'Question is taking longer',
                            style: TextStyle(
                              color: context.primaryTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message.trim().isEmpty
                                ? 'Loading the next question...'
                                : message,
                            style: TextStyle(
                              color: subdued,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: isLoading
                          ? (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08))
                          : Colors.white,
                      foregroundColor: isLoading ? subdued : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isLoading
                          ? 'Checking...'
                          : isFailure && canRetry
                          ? 'Reconnect & retry'
                          : 'Reconnect & check',
                      style: const TextStyle(fontWeight: FontWeight.w900),
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

class _LeaveGameDialog extends StatelessWidget {
  const _LeaveGameDialog({
    this.title = 'Leave this game?',
    this.message =
        'You will exit the live game and return to the story details page.',
    this.icon = CupertinoIcons.arrow_left_circle_fill,
    this.iconBackground,
    this.iconColor = Colors.white,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surface = isDark ? const Color(0xFF111214) : Colors.white;
    final subdued = isDark ? Colors.white70 : const Color(0xFF5F6368);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.18),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        iconBackground ??
                        const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.primaryTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: subdued,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.primaryTextColor,
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Stay',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Leave',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StoryConnectionErrorDialog extends StatelessWidget {
  const StoryConnectionErrorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: StoryConnectionErrorCard(
        onRetry: () => Navigator.of(context).pop(true),
      ),
    );
  }
}

class StoryConnectionErrorCard extends StatelessWidget {
  const StoryConnectionErrorCard({
    super.key,
    required this.onRetry,
    this.message =
        'Aura lost the story connection. Retry to reconnect and continue.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surface = isDark ? const Color(0xFF111214) : Colors.white;
    final subdued = isDark ? Colors.white70 : const Color(0xFF5F6368);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.wifi_slash,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection error',
                      style: TextStyle(
                        color: context.primaryTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: TextStyle(
                        color: subdued,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeavingGameDialog extends StatelessWidget {
  const _LeavingGameDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 42),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111214) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Leaving game...',
                style: TextStyle(
                  color: context.primaryTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizGameBottomBar extends StatelessWidget {
  const _QuizGameBottomBar({required this.onCall, this.disabled = false});

  final VoidCallback onCall;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(28, 10, 28, 14),
      child: IgnorePointer(
        ignoring: disabled,
        child: Opacity(
          opacity: disabled ? 0.72 : 1,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xF0131415),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Row(
                    children: [
                      Text(
                        'Message',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.paperplane_fill,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onCall,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF24D11F),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: Colors.white,
                    size: 25,
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

bool _isQuizSession(InteractiveSessionState? session) {
  if (session == null) return false;
  final state = session.interactiveState;
  if (state['template'] == 'quiz') return true;
  final phase = (state['phase'] as String?) ?? '';
  final sessionType = (state['session_type'] as String?) ?? '';
  if (sessionType != 'solo') return false;
  return const {
    'topic_selection',
    'mode_selection',
    'discussion',
    'timer_selection',
    'generating_question',
    'question_generation_started',
    'generation_failed',
    'question_active',
    'finalizing_question',
    'showing_results',
    'post_question_prompt',
    'completed',
  }.contains(phase);
}

bool _canRetryQuizGeneration(
  InteractiveSessionState? session,
  String? currentUserId,
) {
  if (session == null) return false;
  if (session.interactiveState['session_type'] != 'group') return true;

  final activeParticipants = session.participants.where(
    (participant) => participant.status == 'active',
  );
  final normalizedUserId = currentUserId?.trim();
  if (normalizedUserId != null && normalizedUserId.isNotEmpty) {
    return activeParticipants.any(
      (participant) =>
          participant.userId == normalizedUserId && participant.role == 'host',
    );
  }

  final deviceParticipant = activeParticipants.where(
    (participant) => participant.deviceId == 'mobile-app',
  );
  if (deviceParticipant.length == 1) {
    return deviceParticipant.single.role == 'host';
  }
  if (session.participants.length == 1) {
    return session.participants.single.role == 'host';
  }
  return false;
}

class _StorySessionLoadingShell extends StatelessWidget {
  const _StorySessionLoadingShell({this.title = 'LOADING...'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _GameLoadingGraphic(title: title),
        ),
      ),
    );
  }
}

class _GameLoadingGraphic extends StatefulWidget {
  const _GameLoadingGraphic({required this.title});

  final String title;

  @override
  State<_GameLoadingGraphic> createState() => _GameLoadingGraphicState();
}

class _GameLoadingGraphicState extends State<_GameLoadingGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.72,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _GameLoadingPainter(
              progress: _controller.value,
              title: widget.title,
            ),
          );
        },
      ),
    );
  }
}

class _GameLoadingPainter extends CustomPainter {
  const _GameLoadingPainter({required this.progress, required this.title});

  final double progress;
  final String title;

  @override
  void paint(Canvas canvas, Size size) {
    final black = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.miter;
    final border = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3, size.width * 0.008);

    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: const Color(0xFF111111),
          fontSize: size.width * 0.105,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width * 0.78);
    textPainter.paint(canvas, Offset(size.width * 0.05, size.height * 0.34));

    final barRect = Rect.fromLTWH(
      size.width * 0.055,
      size.height * 0.49,
      size.width * 0.89,
      size.height * 0.18,
    );
    canvas.drawRect(barRect, border);

    final clipRect = barRect.deflate(size.width * 0.018);
    canvas.save();
    canvas.clipRect(clipRect);
    final stripeWidth = size.width * 0.05;
    final stripeGap = size.width * 0.022;
    final stripeStep = stripeWidth + stripeGap;
    final filledWidth = size.width * 0.58;
    final shift = progress * stripeStep;
    var x = clipRect.left - stripeStep + shift;
    while (x < clipRect.left + filledWidth) {
      final path = Path()
        ..moveTo(x + stripeWidth * 0.45, clipRect.top)
        ..lineTo(x + stripeWidth * 1.45, clipRect.top)
        ..lineTo(x + stripeWidth, clipRect.bottom)
        ..lineTo(x, clipRect.bottom)
        ..close();
      canvas.drawPath(path, black);
      x += stripeStep;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GameLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ActiveParticipantsStrip extends StatelessWidget {
  const _ActiveParticipantsStrip({required this.participants});

  final List<StoryParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final active = participants
        .where((participant) => participant.status == 'active')
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Active Participants',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ActiveParticipantAvatarStack(participants: active),
          ],
        ),
      ),
    );
  }
}

class _ActiveParticipantAvatarStack extends StatelessWidget {
  const _ActiveParticipantAvatarStack({required this.participants});

  final List<StoryParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final visible = participants.take(7).toList();
    const size = 34.0;
    const overlap = 24.0;
    final width = size + ((visible.length - 1).clamp(0, 99) * overlap);

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * overlap,
              top: 0,
              child: _ActiveParticipantAvatar(participant: visible[i]),
            ),
        ],
      ),
    );
  }
}

class _ActiveParticipantAvatar extends StatelessWidget {
  const _ActiveParticipantAvatar({required this.participant});

  final StoryParticipant participant;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl(participant);
    final name = _displayName(participant);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }

  static String? _avatarUrl(StoryParticipant participant) {
    for (final key in const [
      'avatar_url',
      'avatarUrl',
      'photo_url',
      'photoUrl',
      'image_url',
      'profile_image_url',
    ]) {
      final value = participant.metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String _displayName(StoryParticipant participant) {
    final name = participant.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return participant.role == 'host' ? 'Host' : 'Player';
  }
}

class _StoryTextChatTab extends ConsumerStatefulWidget {
  const _StoryTextChatTab({
    required this.storyId,
    required this.storyTitle,
    required this.onCall,
    required this.onSessionReady,
    required this.historyRevision,
    required this.enableStoryOptions,
  });

  final String storyId;
  final String storyTitle;
  final VoidCallback onCall;
  final ValueChanged<String> onSessionReady;
  final int historyRevision;
  final bool enableStoryOptions;

  @override
  ConsumerState<_StoryTextChatTab> createState() => _StoryTextChatTabState();
}

class _ParsedStoryOption {
  const _ParsedStoryOption({required this.title, this.teaser});

  final String title;
  final String? teaser;

  String get displayText {
    final cleanTeaser = teaser?.trim();
    if (cleanTeaser == null || cleanTeaser.isEmpty) return title;
    return '$title\n$cleanTeaser';
  }
}

class _ParsedStoryOptions {
  const _ParsedStoryOptions({required this.displayText, required this.options});

  final String displayText;
  final List<_ParsedStoryOption> options;
}

String _cleanStoryOptionTitle(String value) {
  var title = _cleanStoryBubbleText(value);
  title = title.replaceAll(RegExp(r'\s+'), ' ');
  title = title.split(RegExp(r'\s+(?:-|–|—)\s+|:\s+')).first.trim();
  title = title.replaceFirst(RegExp(r'[:\-–—]\s*$'), '').trim();
  while (title.length >= 2 &&
      ((title.startsWith('"') && title.endsWith('"')) ||
          (title.startsWith("'") && title.endsWith("'")) ||
          (title.startsWith('“') && title.endsWith('”')) ||
          (title.startsWith('‘') && title.endsWith('’')))) {
    title = title.substring(1, title.length - 1).trim();
  }
  return title;
}

String _cleanStoryOptionTeaser(String? value) {
  var teaser = _cleanStoryBubbleText(value ?? '');
  teaser = teaser.replaceAll(RegExp(r'\s+'), ' ');
  while (teaser.length >= 2 &&
      ((teaser.startsWith('"') && teaser.endsWith('"')) ||
          (teaser.startsWith("'") && teaser.endsWith("'")) ||
          (teaser.startsWith('“') && teaser.endsWith('”')) ||
          (teaser.startsWith('‘') && teaser.endsWith('’')))) {
    teaser = teaser.substring(1, teaser.length - 1).trim();
  }
  return teaser;
}

_ParsedStoryOption? _parseStoryOptionLine(String line) {
  final numberedMatch = RegExp(
    r'^\s*(?:[1-3]|[A-Ca-c])[.)]\s+(.+?)\s*$',
  ).firstMatch(line);
  if (numberedMatch == null) return null;

  var body = numberedMatch.group(1)?.trim() ?? '';
  if (body.isEmpty) return null;

  String title;
  String teaser = '';
  final boldMatch = RegExp(
    r'^(\*\*|__)(.*?)\1\s*(.*)$',
    dotAll: true,
  ).firstMatch(body);
  if (boldMatch != null) {
    title = boldMatch.group(2)?.trim() ?? '';
    teaser = boldMatch.group(3)?.trim() ?? '';
  } else {
    final separatorMatch = RegExp(
      r'\s*(?:[:\-\u2013\u2014])\s+',
    ).firstMatch(body);
    if (separatorMatch == null) {
      title = body;
    } else {
      title = body.substring(0, separatorMatch.start).trim();
      teaser = body.substring(separatorMatch.end).trim();
    }
  }

  teaser = teaser.replaceFirst(RegExp(r'^\s*(?:[:\-\u2013\u2014])\s*'), '');
  title = _cleanStoryOptionTitle(title);
  teaser = _cleanStoryOptionTeaser(teaser);
  if (title.isEmpty) return null;
  return _ParsedStoryOption(
    title: title,
    teaser: teaser.isEmpty ? null : teaser,
  );
}

String _cleanStoryBubbleText(String value) {
  var text = value.trim();
  text = text.replaceAllMapped(
    RegExp(r'\*\*(.*?)\*\*', dotAll: true),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'__(.*?)__', dotAll: true),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAll('**', '');
  text = text.replaceAll('__', '');
  return text;
}

class _StoryOptionButtons extends StatefulWidget {
  const _StoryOptionButtons({
    required this.options,
    required this.onSelected,
    required this.onRegenerate,
    this.selectedTitle,
    this.disabled = false,
  });

  final List<_ParsedStoryOption> options;
  final ValueChanged<_ParsedStoryOption> onSelected;
  final VoidCallback onRegenerate;
  final String? selectedTitle;
  final bool disabled;

  @override
  State<_StoryOptionButtons> createState() => _StoryOptionButtonsState();
}

class _StoryOptionButtonsState extends State<_StoryOptionButtons> {
  _ParsedStoryOption? _draftOption;
  bool _confirmRegenerate = false;

  @override
  void didUpdateWidget(covariant _StoryOptionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    final optionsChanged =
        oldWidget.options.map((option) => option.displayText).join('|') !=
        widget.options.map((option) => option.displayText).join('|');
    if (optionsChanged || widget.selectedTitle != null) {
      _draftOption = null;
      _confirmRegenerate = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTitle = widget.selectedTitle ?? _draftOption?.title;
    final optionsDisabled = widget.disabled;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.options.length; i++) ...[
              _StoryOptionButton(
                option: widget.options[i],
                onSelected: _selectDraftOption,
                selected: widget.options[i].title == selectedTitle,
                disabled: optionsDisabled,
              ),
              if (i != widget.options.length - 1) const SizedBox(height: 8),
            ],
            if (_draftOption != null) ...[
              const SizedBox(height: 10),
              _StoryOptionConfirmBar(
                title: _draftOption!.title,
                disabled: widget.disabled,
                onCancel: _clearDraftAction,
                onConfirm: () => widget.onSelected(_draftOption!),
              ),
            ],
            const SizedBox(height: 8),
            _StoryActionButton(
              label: 'Try different stories',
              disabled: widget.disabled,
              selected: _confirmRegenerate,
              onPressed: _selectRegenerate,
            ),
            if (_confirmRegenerate) ...[
              const SizedBox(height: 10),
              _StoryOptionConfirmBar(
                title: 'Try different stories',
                disabled: widget.disabled,
                onCancel: _clearDraftAction,
                onConfirm: widget.onRegenerate,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectDraftOption(_ParsedStoryOption option) {
    if (option.title == widget.selectedTitle) return;
    HapticFeedback.selectionClick();
    setState(() {
      _draftOption = option;
      _confirmRegenerate = false;
    });
  }

  void _selectRegenerate() {
    HapticFeedback.selectionClick();
    setState(() {
      _draftOption = null;
      _confirmRegenerate = true;
    });
  }

  void _clearDraftAction() {
    setState(() {
      _draftOption = null;
      _confirmRegenerate = false;
    });
  }
}

class _StoryOptionButton extends StatelessWidget {
  const _StoryOptionButton({
    required this.option,
    required this.onSelected,
    required this.selected,
    required this.disabled,
  });

  final _ParsedStoryOption option;
  final ValueChanged<_ParsedStoryOption> onSelected;
  final bool selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    const defaultBorderColor = Color(0xFFFFC928);
    const selectedBorderColor = Color(0xFF2FEF73);
    const optionBackground = Color(0xF0131415);
    final borderColor = selected ? selectedBorderColor : defaultBorderColor;
    final borderAlpha = disabled ? 0.52 : 1.0;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: disabled ? null : () => onSelected(option),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white54,
          side: BorderSide(
            color: borderColor.withValues(alpha: borderAlpha),
            width: selected ? 1.7 : 1.25,
          ),
          backgroundColor: optionBackground,
          disabledBackgroundColor: optionBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
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

class _StoryActionButton extends StatelessWidget {
  const _StoryActionButton({
    required this.label,
    required this.disabled,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool disabled;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF59E0B);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: disabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white54,
              side: BorderSide(
                color: accent.withValues(
                  alpha: disabled ? 0.42 : (selected ? 0.96 : 0.72),
                ),
                width: selected ? 1.35 : 1,
              ),
              backgroundColor: selected
                  ? accent.withValues(alpha: 0.18)
                  : const Color(0xF0131415),
              disabledBackgroundColor: selected
                  ? accent.withValues(alpha: 0.18)
                  : const Color(0xF0131415),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryOptionConfirmBar extends StatelessWidget {
  const _StoryOptionConfirmBar({
    required this.title,
    required this.disabled,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final bool disabled;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF0131415),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Confirm $title',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 30,
              child: TextButton(
                onPressed: disabled ? null : onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: Colors.white70,
                  disabledForegroundColor: Colors.white30,
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 30,
              child: FilledButton(
                onPressed: disabled ? null : onConfirm,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white24,
                  foregroundColor: const Color(0xFF111111),
                  disabledForegroundColor: Colors.white54,
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: disabled
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryTextChatTabState extends ConsumerState<_StoryTextChatTab> {
  final _textController = TextEditingController();
  final _listScrollController = ScrollController();
  final List<ChatMessageModel> _messages = <ChatMessageModel>[];
  bool _canSend = false;
  int _lastMessageCount = 0;
  String? _confirmedStoryOptionTitle;
  StorySession? _textSession;
  bool _isStartingTextSession = true;
  bool _isSendingText = false;
  bool _isSubmittingStoryOption = false;
  String? _textSessionError;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_startTextStorySession());
      }
    });
  }

  @override
  void didUpdateWidget(covariant _StoryTextChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.historyRevision != oldWidget.historyRevision) {
      unawaited(_refreshConversationAfterVoice());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final canSend = _textController.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  Future<void> _startTextStorySession() async {
    setState(() {
      _isStartingTextSession = true;
      _textSessionError = null;
    });
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.startSession(
        storyId: widget.storyId,
        deviceType: 'mobile',
        deviceId: 'text-chat',
      );
      final history = await repo.fetchStoryConversation(
        storyId: widget.storyId,
      );
      if (!mounted) return;
      setState(() {
        _textSession = session;
        _messages
          ..clear()
          ..addAll(_messagesFromHistory(history));
        if (_messages.isEmpty) {
          _appendAssistantFromSession(session);
        }
        _isStartingTextSession = false;
      });
      if (session.id.isNotEmpty) {
        widget.onSessionReady(session.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isStartingTextSession = false;
        _textSessionError = e.toString();
      });
      showToast(context, 'Story connection error');
    }
  }

  Future<void> _refreshConversationAfterVoice() async {
    try {
      final history = await ref
          .read(storiesRepositoryProvider)
          .fetchStoryConversation(storyId: widget.storyId);
      if (!mounted || history.isEmpty) return;

      final refreshedMessages = _messagesFromHistory(history);
      if (refreshedMessages.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(refreshedMessages);
        _textSessionError = null;
      });
      _scrollToBottom();
    } catch (_) {
      // Keep the existing chat visible. A later text send or page reopen will
      // fetch the canonical history again.
    }
  }

  List<ChatMessageModel> _messagesFromHistory(
    List<Map<String, dynamic>> history,
  ) {
    final messages = <ChatMessageModel>[];
    for (var i = 0; i < history.length; i++) {
      final entry = history[i];
      final speaker = (entry['speaker'] as String?)?.trim() ?? '';
      final rawText = (entry['message'] as String?)?.trim() ?? '';
      final text = speaker == 'user' ? _cleanStoryBubbleText(rawText) : rawText;
      if (text.isEmpty) continue;
      messages.add(
        ChatMessageModel(
          id: 'story_text_history_$i',
          role: speaker == 'user' ? ChatRole.user : ChatRole.assistant,
          message: text,
          ts: DateTime.now(),
        ),
      );
    }
    return messages;
  }

  void _appendAssistantFromSession(StorySession session) {
    final text = session.currentNode?.content.text.trim() ?? '';
    if (text.isEmpty) return;
    if (_messages.any(
      (m) => m.role == ChatRole.assistant && m.message == text,
    )) {
      return;
    }
    _messages.add(
      ChatMessageModel(
        id: 'story_text_ai_${session.version}_${_messages.length}',
        role: ChatRole.assistant,
        message: text,
        ts: DateTime.now(),
      ),
    );
  }

  Future<void> _onSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_isSendingText || _isSubmittingStoryOption) {
      showToast(context, 'Aura is replying...', variant: ToastVariant.info);
      return;
    }
    if (_isStartingTextSession) {
      showToast(context, 'Connecting...', variant: ToastVariant.info);
      return;
    }

    if (_textSession == null) {
      await _startTextStorySession();
      if (_textSession == null) return;
    }

    _textController.clear();
    unawaited(_sendTextStoryTurn(text));
  }

  Future<void> _sendTextStoryTurn(String text) async {
    final userMessage = ChatMessageModel(
      id: 'story_text_user_${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      message: text,
      ts: DateTime.now(),
    );
    final assistantMessageId =
        'story_text_ai_stream_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _isSendingText = true;
      _textSessionError = null;
      _messages.add(userMessage);
      _messages.add(
        ChatMessageModel(
          id: assistantMessageId,
          role: ChatRole.assistant,
          message: '',
          ts: DateTime.now(),
          streaming: true,
        ),
      );
    });

    try {
      await for (final event
          in ref
              .read(storiesRepositoryProvider)
              .streamStoryText(
                storyId: widget.storyId,
                message: text,
                expectedVersion: _textSession?.version,
              )) {
        if (!mounted) return;
        if (event.isToken) {
          final token = event.content ?? '';
          if (token.isEmpty) continue;
          setState(() {
            final index = _messages.indexWhere(
              (m) => m.id == assistantMessageId,
            );
            if (index != -1) {
              final current = _messages[index];
              _messages[index] = current.copyWith(
                message: current.message + token,
                streaming: true,
              );
            }
          });
        } else if (event.isDone) {
          setState(() {
            if (event.session != null) {
              _textSession = event.session;
            }
            final index = _messages.indexWhere(
              (m) => m.id == assistantMessageId,
            );
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(streaming: false);
            }
            _isSendingText = false;
          });
          final sessionId = event.session?.id ?? _textSession?.id ?? '';
          if (sessionId.isNotEmpty) {
            widget.onSessionReady(sessionId);
          }
        } else if (event.isError) {
          throw Exception(event.error ?? 'Story stream failed');
        }
      }
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == assistantMessageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(streaming: false);
        }
        _isSendingText = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingText = false;
        _textSessionError = e.toString();
        final lastIndex = _messages.lastIndexWhere(
          (m) => m.id == userMessage.id,
        );
        if (lastIndex != -1) {
          _messages[lastIndex] = _messages[lastIndex].copyWith(
            delivery: ChatDeliveryState.failed,
          );
        }
        final assistantIndex = _messages.indexWhere(
          (m) => m.id == assistantMessageId,
        );
        if (assistantIndex != -1 && _messages[assistantIndex].message.isEmpty) {
          _messages.removeAt(assistantIndex);
        } else if (assistantIndex != -1) {
          _messages[assistantIndex] = _messages[assistantIndex].copyWith(
            streaming: false,
          );
        }
      });
      showToast(context, 'Story connection error');
    }
  }

  Future<void> _confirmStoryOption(_ParsedStoryOption option) async {
    if (_isSubmittingStoryOption) return;
    if (_confirmedStoryOptionTitle == option.title) return;

    HapticFeedback.mediumImpact();
    if (_isStartingTextSession) {
      showToast(context, 'Connecting...', variant: ToastVariant.info);
      return;
    }

    setState(() {
      _confirmedStoryOptionTitle = option.title;
      _isSubmittingStoryOption = true;
    });
    try {
      await _sendTextStoryTurn('I choose ${option.title}.');
    } finally {
      if (mounted) {
        setState(() => _isSubmittingStoryOption = false);
      }
    }
  }

  Future<void> _regenerateStoryOptions() async {
    if (_isSubmittingStoryOption) return;

    if (_isStartingTextSession) {
      showToast(context, 'Connecting...', variant: ToastVariant.info);
      return;
    }

    setState(() {
      _confirmedStoryOptionTitle = null;
      _isSubmittingStoryOption = true;
    });
    try {
      await _sendTextStoryTurn(
        'Give me three different story options for ${widget.storyTitle}. Use numbered options with a title and one short teaser in the same line. Do not use quotation marks or subtitles.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingStoryOption = false);
      }
    }
  }

  void _scrollToBottom() {
    if (!_listScrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listScrollController.hasClients) return;
      _listScrollController.animateTo(
        _listScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  List<ChatMessageModel> _buildMessages() {
    return List<ChatMessageModel>.of(_messages);
  }

  _ParsedStoryOptions? _parseStoryOptions(ChatMessageModel message) {
    if (message.role != ChatRole.assistant) return null;

    final isConfiguredStoryMenu =
        widget.enableStoryOptions ||
        _isBeneathTheSurfaceTitle(widget.storyTitle);
    final lowerMessage = message.message.toLowerCase();
    final looksLikeStoryOptionMenu =
        lowerMessage.contains('story options') ||
        lowerMessage.contains('stories to explore') ||
        lowerMessage.contains('stories to choose') ||
        lowerMessage.contains('choose a story') ||
        lowerMessage.contains('select a story') ||
        lowerMessage.contains('which story') ||
        lowerMessage.contains('resonates with you') ||
        (isConfiguredStoryMenu && lowerMessage.contains('choose'));
    if (!looksLikeStoryOptionMenu) return null;

    final lines = message.message.split('\n');
    final options = <_ParsedStoryOption>[];
    final displayLines = <String>[];

    for (final line in lines) {
      final option = _parseStoryOptionLine(line);
      if (option == null) {
        final lowerLine = line.toLowerCase();
        final isMenuFiller =
            lowerLine.contains('here are your choices') ||
            lowerLine.contains('here are the choices') ||
            lowerLine.contains('here are three') ||
            lowerLine.contains('take a moment') ||
            lowerLine.contains('which story') ||
            lowerLine.contains('resonates with you') ||
            lowerLine.contains('we can begin');
        if (!isMenuFiller) {
          displayLines.add(line);
        }
        continue;
      }
      options.add(option);
    }

    if (options.length < 2) return null;
    if (message.isStreaming && options.length < 3) return null;
    final displayText = displayLines.join('\n').trim();
    return _ParsedStoryOptions(
      displayText: displayText.isEmpty
          ? 'Choose a story to explore.'
          : displayText,
      options: options,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _buildMessages();
    final visibleMessages = messages.isEmpty && _isStartingTextSession
        ? <ChatMessageModel>[
            ChatMessageModel(
              id: 'story_text_connecting',
              role: ChatRole.assistant,
              message: '',
              ts: DateTime.now(),
              streaming: true,
            ),
          ]
        : messages;
    final isDark = context.isDarkMode;
    final mutedSurface = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF3F3F3);
    final mutedText = isDark ? Colors.white60 : Colors.black54;
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = (screenWidth * 0.82).clamp(0.0, 420.0);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final canSubmitText =
        _canSend && !_isSendingText && !_isStartingTextSession;

    if (visibleMessages.length != _lastMessageCount) {
      _lastMessageCount = visibleMessages.length;
      _scrollToBottom();
    }
    if (visibleMessages.isNotEmpty && visibleMessages.last.isStreaming) {
      _scrollToBottom();
    }

    if (_textSessionError != null && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: StoryConnectionErrorCard(
            onRetry: () => unawaited(_startTextStorySession()),
            message:
                'Aura could not connect to this story. Retry to reconnect and continue.',
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _listScrollController,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            itemCount: visibleMessages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final message = visibleMessages[index];
              final parsedOptions = _parseStoryOptions(message);
              final displayMessage = parsedOptions == null
                  ? message
                  : message.copyWith(message: parsedOptions.displayText);
              return _AnimatedBubble(
                key: ValueKey(message.id),
                child: Column(
                  crossAxisAlignment: message.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    ChatBubble(
                      message: displayMessage,
                      onRetry: () {},
                      maxWidth: bubbleMaxWidth,
                      renderMarkdownBold: !displayMessage.isUser,
                    ),
                    if (parsedOptions != null) ...[
                      const SizedBox(height: 10),
                      _StoryOptionButtons(
                        options: parsedOptions.options,
                        selectedTitle: _confirmedStoryOptionTitle,
                        disabled:
                            _isSubmittingStoryOption ||
                            _isSendingText ||
                            _isStartingTextSession,
                        onRegenerate: () =>
                            unawaited(_regenerateStoryOptions()),
                        onSelected: (option) =>
                            unawaited(_confirmStoryOption(option)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: mutedSurface,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLines: 5,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            cursorColor: context.primaryTextColor,
                            style: TextStyle(
                              color: context.primaryTextColor,
                              fontSize: 16,
                              height: 1.35,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(
                                color: mutedText,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.fromLTRB(
                                18,
                                14,
                                8,
                                14,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => unawaited(_onSend()),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: canSubmitText
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: canSubmitText
                                  ? () => unawaited(_onSend())
                                  : null,
                              splashRadius: 20,
                              icon: Icon(
                                CupertinoIcons.paperplane_fill,
                                color: canSubmitText
                                    ? (isDark ? Colors.black : Colors.white)
                                    : mutedText,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _CircleIconButton(
                    icon: Icons.call_rounded,
                    tooltip: 'Voice',
                    background: const Color(0xFF22C55E),
                    foreground: Colors.white,
                    onTap: widget.onCall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, color: foreground, size: 20),
        ),
      ),
    );
  }
}

class _AnimatedBubble extends StatefulWidget {
  const _AnimatedBubble({super.key, required this.child});
  final Widget child;

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: widget.child),
    );
  }
}
