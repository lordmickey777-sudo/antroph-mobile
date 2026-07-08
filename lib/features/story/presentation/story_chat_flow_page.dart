import 'dart:async';
import 'dart:math' as math;

import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/chat_bubble.dart';
import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
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

enum InteractiveStoryLaunchMode { create, joinByCode, joinPublic }

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

    if ((widget.storySessionId ?? '').trim().isNotEmpty) {
      unawaited(voiceController.resumeStorySession(widget.storySessionId!));
    } else {
      unawaited(voiceController.startStorySession(widget.storyId));
    }

    // Chat-first: keep this page silent and prevent auto-listen.
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

  void _openVoicePage() {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final voiceState = ref.read(voiceChatControllerProvider);

    unawaited(
      voiceController.ensureStorySessionConnected(
        widget.storyId,
        preferredSessionId: widget.storySessionId,
      ),
    );

    // Ensure we aren't recording while transitioning.
    if (!voiceState.isMuted) {
      voiceController.toggleMute();
    }

    Navigator.of(context).push(
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

    final navigator = Navigator.of(context);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      voiceController.pauseStorySession();
    } else if (state == AppLifecycleState.resumed) {
      voiceController.resumePausedSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceChatState>(voiceChatControllerProvider, (previous, next) {
      if (!mounted) return;
      final error = next.errorMessage;
      if (error != null &&
          error.isNotEmpty &&
          error != (previous?.errorMessage ?? '')) {
        showToast(context, error);
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
          body: storyDetail.maybeWhen(
            data: (detail) {
              if (detail.interactionMode != 'narrative') {
                return _InteractiveStoryTab(
                  storyId: widget.storyId,
                  interactionMode: detail.interactionMode,
                  launchMode: widget.interactiveLaunchMode,
                  joinCode: widget.joinCode,
                  onCall: _openVoicePage,
                  onLeave: _leaveGame,
                );
              }
              return _StoryTextChatTab(onCall: _openVoicePage);
            },
            loading: () => const _StorySessionLoadingShell(),
            orElse: () => _StoryTextChatTab(onCall: _openVoicePage),
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
    final showQuestionGenerationOverlay =
        isGroupQuizSession &&
        session != null &&
        (phase == 'generation_failed' || state.isRetryingGeneration);
    final questionGenerationRetrying =
        state.isRetryingGeneration ||
        (state.isLoading && phase == 'generation_failed');
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
                        onRetryGeneration: () =>
                            unawaited(notifier.retryGeneration()),
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
              message: effectiveQuestionGenerationError?.isNotEmpty == true
                  ? effectiveQuestionGenerationError!
                  : 'The next question could not be loaded.',
              onRetry: questionGenerationRetrying
                  ? null
                  : () => unawaited(notifier.retryGeneration()),
            ),
          ),
      ],
    );
  }
}

class _QuestionGenerationOverlay extends StatelessWidget {
  const _QuestionGenerationOverlay({
    required this.isLoading,
    required this.message,
    required this.onRetry,
  });

  final bool isLoading;
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
                                ? 'Retrying question'
                                : 'Question failed to load',
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
                      isLoading ? 'Retrying...' : 'Retry',
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
  const _LeaveGameDialog();

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
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_left_circle_fill,
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
                        'Leave this game?',
                        style: TextStyle(
                          color: context.primaryTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You will exit the live game and return to the story details page.',
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
    'question_active',
    'finalizing_question',
    'showing_results',
    'post_question_prompt',
    'completed',
  }.contains(phase);
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
  const _StoryTextChatTab({required this.onCall});

  final VoidCallback onCall;

  @override
  ConsumerState<_StoryTextChatTab> createState() => _StoryTextChatTabState();
}

class _StoryTextChatTabState extends ConsumerState<_StoryTextChatTab> {
  final _textController = TextEditingController();
  final _listScrollController = ScrollController();
  bool _canSend = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
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

  void _onSend(VoiceChatController controller, VoiceChatState voiceState) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Keep chat tab silent and mic-off.
    if (!voiceState.isMuted) {
      controller.toggleMute();
    }
    unawaited(controller.stopPlayback());

    if (!voiceState.isSessionReady) {
      showToast(context, 'Connecting…', variant: ToastVariant.info);
      return;
    }

    _textController.clear();
    unawaited(controller.sendTextPrompt(text, textOnly: true));
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

  List<ChatMessageModel> _buildMessages(VoiceChatState voiceState) {
    final messages = <ChatMessageModel>[];
    debugPrint(
      '[ChatDebug] _buildMessages history.len=${voiceState.conversationHistory.length} '
      'roles=${voiceState.conversationHistory.map((e) => e.role).toList()}',
    );
    for (var i = 0; i < voiceState.conversationHistory.length; i++) {
      final item = voiceState.conversationHistory[i];
      if (item.content.isEmpty) continue;
      messages.add(
        ChatMessageModel(
          id: 'story_$i',
          role: item.isUser ? ChatRole.user : ChatRole.assistant,
          message: item.content,
          ts: DateTime.now(),
        ),
      );
    }
    final liveAiText = voiceState.aiResponse?.trim() ?? '';
    final liveAiAlreadyInHistory =
        liveAiText.isNotEmpty &&
        voiceState.conversationHistory.any(
          (item) => item.isAssistant && item.content.trim() == liveAiText,
        );
    final hasAiText = liveAiText.isNotEmpty && !liveAiAlreadyInHistory;
    final awaitingAi = voiceState.isProcessing || voiceState.isConnecting;
    final showPendingAssistant =
        voiceState.showPendingAssistantBubble && !liveAiAlreadyInHistory;
    if (hasAiText ||
        showPendingAssistant ||
        (awaitingAi && !liveAiAlreadyInHistory)) {
      messages.add(
        ChatMessageModel(
          id: 'story_live_ai',
          role: ChatRole.assistant,
          message: hasAiText ? liveAiText : '',
          ts: DateTime.now(),
          streaming:
              showPendingAssistant ||
              awaitingAi ||
              voiceState.isPlaying ||
              !hasAiText,
        ),
      );
    }
    return messages;
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceChatControllerProvider);
    final controller = ref.read(voiceChatControllerProvider.notifier);
    final messages = _buildMessages(voiceState);
    final isDark = context.isDarkMode;
    final mutedSurface = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF3F3F3);
    final mutedText = isDark ? Colors.white60 : Colors.black54;
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = (screenWidth * 0.82).clamp(0.0, 420.0);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }
    if (messages.isNotEmpty && messages.last.isStreaming) {
      _scrollToBottom();
    }

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _EmptyState(
                  isDark: isDark,
                  mutedSurface: mutedSurface,
                  primaryTextColor: context.primaryTextColor,
                  secondaryTextColor: mutedText,
                )
              : ListView.separated(
                  controller: _listScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _AnimatedBubble(
                      key: ValueKey(message.id),
                      child: ChatBubble(
                        message: message,
                        onRetry: () {},
                        maxWidth: bubbleMaxWidth,
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
                            onSubmitted: (_) => _onSend(controller, voiceState),
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
                              color: _canSend
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _canSend
                                  ? () => _onSend(controller, voiceState)
                                  : null,
                              splashRadius: 20,
                              icon: Icon(
                                CupertinoIcons.paperplane_fill,
                                color: _canSend
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isDark,
    required this.mutedSurface,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  final bool isDark;
  final Color mutedSurface;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/images/message.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Start the conversation',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chat here or call Aura',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
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
