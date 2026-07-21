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
import 'package:antroph_mobile/features/story/presentation/solo_interactive_history_view.dart';
import 'package:antroph_mobile/features/story/presentation/story_voice_page.dart';
import 'package:antroph_mobile/features/story/providers/interactive_story_provider.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/features/story/widgets/group_quiz_results_view.dart';
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
    this.soloStartFreshOnLaunch = false,
    this.soloOpenHistoryOnLaunch = false,
    this.interactiveSessionPreloaded = false,
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
  final bool soloStartFreshOnLaunch;
  final bool soloOpenHistoryOnLaunch;
  final bool interactiveSessionPreloaded;

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
  final _interactiveStoryTabKey = GlobalKey<_InteractiveStoryTabState>();

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
      final handledLocally =
          await _interactiveStoryTabKey.currentState?.handleBack() ?? false;
      if (handledLocally) return;
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
    voiceController.clearNarrationCache();
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
    final resolvedInteractionMode =
        widget.initialInteractionMode ??
        storyDetail.asData?.value.interactionMode;
    final showSoloHistory =
        resolvedInteractionMode != null &&
        resolvedInteractionMode != 'narrative' &&
        resolvedInteractionMode != 'group';

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
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            toolbarHeight: 48,
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
              if (showSoloHistory)
                IconButton(
                  onPressed: () {
                    unawaited(
                      _interactiveStoryTabKey.currentState?.showHistory() ??
                          Future<void>.value(),
                    );
                  },
                  icon: const Icon(CupertinoIcons.clock),
                  color: context.primaryTextColor,
                  tooltip: 'Solo session history',
                ),
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
                  key: _interactiveStoryTabKey,
                  storyId: widget.storyId,
                  storySessionId: widget.storySessionId,
                  interactionMode: interactionMode,
                  launchMode: widget.interactiveLaunchMode,
                  joinCode: widget.joinCode,
                  soloStartFreshOnLaunch: widget.soloStartFreshOnLaunch,
                  soloOpenHistoryOnLaunch: widget.soloOpenHistoryOnLaunch,
                  sessionPreloaded: widget.interactiveSessionPreloaded,
                  isLeavingGame: _isLeavingGame,
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
    super.key,
    required this.storyId,
    this.storySessionId,
    required this.interactionMode,
    required this.launchMode,
    this.joinCode,
    this.soloStartFreshOnLaunch = false,
    this.soloOpenHistoryOnLaunch = false,
    this.sessionPreloaded = false,
    this.isLeavingGame = false,
    required this.onCall,
    required this.onLeave,
  });

  final String storyId;
  final String? storySessionId;
  final String interactionMode;
  final InteractiveStoryLaunchMode launchMode;
  final String? joinCode;
  final bool soloStartFreshOnLaunch;
  final bool soloOpenHistoryOnLaunch;
  final bool sessionPreloaded;
  final bool isLeavingGame;
  final VoidCallback onCall;
  final Future<void> Function() onLeave;

  @override
  ConsumerState<_InteractiveStoryTab> createState() =>
      _InteractiveStoryTabState();
}

enum _SoloEntryView { checking, launcher, history, session }

class _InteractiveStoryTabState extends ConsumerState<_InteractiveStoryTab> {
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  final _groupMessageFieldKey = GlobalKey();
  final _groupOptionPanelKey = GlobalKey();
  final _customTopicCallLink = LayerLink();
  bool _canSend = false;
  bool _customTopicEntryEnabled = false;
  String? _customTopicSessionId;
  bool _customAspectEntryEnabled = false;
  String? _customAspectRevision;
  List<String> _customAspectPath = const <String>[];
  String? _soloViewSessionId;
  String? _soloViewModeOverride;
  bool _showQuizTopicDecision = false;
  bool _resumeQuizAfterNewTopic = false;
  bool _isRestartingForNewTopic = false;
  bool _groupHostAdvancePanelCollapsed = false;
  bool _groupCompletedPanelCollapsed = true;
  bool _groupSetupPanelCollapsed = false;
  bool _started = false;
  String? _lastGenerationFailureKey;
  String? _stickyGenerationError;
  _SoloEntryView _soloEntryView = _SoloEntryView.launcher;
  List<SoloInteractiveSessionSummary> _soloSessionHistory =
      const <SoloInteractiveSessionSummary>[];
  bool _soloEntryBusy = false;
  String? _soloEntryError;
  bool _preferredSoloSessionHandled = false;
  String? _historyReturnSessionId;
  int _soloEntryRequestSerial = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final next = _textController.text.trim().isNotEmpty;
      if (next != _canSend) setState(() => _canSend = next);
    });
    _textFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _handleTranscriptRevealInProgressChanged(bool inProgress) {
    // The bottom option sheet should resonate with its prompt immediately,
    // matching the solo flow. Transcript reveal still reports progress for
    // scroll/padding purposes, but it must not gate option visibility.
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    if (widget.sessionPreloaded &&
        ref.read(interactiveStoryProvider).session != null) {
      setState(() => _soloEntryView = _SoloEntryView.session);
      return;
    }
    final code = widget.joinCode?.trim() ?? '';
    if (widget.launchMode == InteractiveStoryLaunchMode.joinPublic) {
      setState(() => _soloEntryView = _SoloEntryView.session);
      unawaited(
        ref
            .read(interactiveStoryProvider.notifier)
            .joinPublic(storyId: widget.storyId),
      );
      return;
    }
    if (widget.launchMode == InteractiveStoryLaunchMode.joinByCode &&
        code.isNotEmpty) {
      setState(() => _soloEntryView = _SoloEntryView.session);
      unawaited(ref.read(interactiveStoryProvider.notifier).joinByCode(code));
      return;
    }
    if (widget.interactionMode == 'group') {
      unawaited(_startGroupSession());
      return;
    }
    if (widget.soloStartFreshOnLaunch) {
      unawaited(_startSoloSession(startFresh: true));
      return;
    }
    final cachedHistory = ref
        .read(interactiveStoryProvider.notifier)
        .cachedSoloHistory(storyId: widget.storyId);
    setState(() {
      if (cachedHistory != null) _soloSessionHistory = cachedHistory;
      _soloEntryView = widget.soloOpenHistoryOnLaunch
          ? _SoloEntryView.history
          : _SoloEntryView.session;
    });
    unawaited(
      _loadSoloEntry(
        openHistory: widget.soloOpenHistoryOnLaunch,
        honorPreferredSession: !widget.soloOpenHistoryOnLaunch,
      ),
    );
  }

  Future<void> _startGroupSession() async {
    if (_soloEntryBusy) return;
    final requestSerial = ++_soloEntryRequestSerial;
    setState(() {
      _soloEntryView = _SoloEntryView.session;
      _soloEntryBusy = true;
      _soloEntryError = null;
    });
    await ref
        .read(interactiveStoryProvider.notifier)
        .start(
          storyId: widget.storyId,
          interactionMode: widget.interactionMode,
          startFresh: true,
        );
    if (!mounted || requestSerial != _soloEntryRequestSerial) return;
    setState(() => _soloEntryBusy = false);
  }

  SoloInteractiveSessionSummary? get _latestResumableSoloSession {
    for (final session in _soloSessionHistory) {
      if (session.isResumable) return session;
    }
    return null;
  }

  Future<void> _loadSoloEntry({
    bool openHistory = false,
    bool honorPreferredSession = true,
    bool forceRefresh = false,
  }) async {
    if (!mounted || _soloEntryBusy) return;
    final notifier = ref.read(interactiveStoryProvider.notifier);
    final cachedHistory = forceRefresh
        ? null
        : notifier.cachedSoloHistory(storyId: widget.storyId);
    if (cachedHistory != null) {
      await _applySoloEntryHistory(
        cachedHistory,
        openHistory: openHistory,
        honorPreferredSession: honorPreferredSession,
      );
      return;
    }
    final requestSerial = ++_soloEntryRequestSerial;
    setState(() {
      _soloEntryView = openHistory
          ? _SoloEntryView.history
          : _SoloEntryView.session;
      _soloEntryBusy = true;
      _soloEntryError = null;
    });
    try {
      final history = await notifier.fetchSoloHistory(
        storyId: widget.storyId,
        limit: 50,
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestSerial != _soloEntryRequestSerial) return;
      await _applySoloEntryHistory(
        history,
        openHistory: openHistory,
        honorPreferredSession: honorPreferredSession,
      );
    } catch (error) {
      if (!mounted || requestSerial != _soloEntryRequestSerial) return;
      setState(() {
        _soloEntryView = openHistory
            ? _SoloEntryView.history
            : _SoloEntryView.launcher;
        _soloEntryBusy = false;
        _soloEntryError = _soloEntryErrorText(error);
      });
    }
  }

  Future<void> _applySoloEntryHistory(
    List<SoloInteractiveSessionSummary> history, {
    required bool openHistory,
    required bool honorPreferredSession,
  }) async {
    if (!mounted) return;
    _soloSessionHistory = history;

    final preferredId = widget.storySessionId?.trim();
    if (honorPreferredSession &&
        !_preferredSoloSessionHandled &&
        preferredId != null &&
        preferredId.isNotEmpty) {
      _preferredSoloSessionHandled = true;
      SoloInteractiveSessionSummary? preferred;
      for (final session in history) {
        if (session.sessionId == preferredId) {
          preferred = session;
          break;
        }
      }
      setState(() => _soloEntryBusy = false);
      if (preferred != null) {
        await _openSoloHistorySession(preferred);
        return;
      }
      await _openExactSoloSession(preferredId);
      return;
    }

    if (history.isEmpty && !openHistory) {
      setState(() => _soloEntryBusy = false);
      await _startSoloSession(startFresh: false);
      return;
    }
    if (!openHistory) {
      final latest = _latestResumableSoloSession;
      if (latest != null) {
        setState(() => _soloEntryBusy = false);
        await _openSoloHistorySession(latest);
        return;
      }
    }
    setState(() {
      _soloEntryView = openHistory
          ? _SoloEntryView.history
          : _SoloEntryView.history;
      _soloEntryBusy = false;
      _soloEntryError = null;
    });
  }

  Future<void> _startSoloSession({required bool startFresh}) async {
    if (_soloEntryBusy) return;
    final requestSerial = ++_soloEntryRequestSerial;
    setState(() {
      _soloEntryView = _SoloEntryView.session;
      _soloEntryBusy = true;
      _soloEntryError = null;
    });
    final notifier = ref.read(interactiveStoryProvider.notifier);
    final opened = await notifier.start(
      storyId: widget.storyId,
      interactionMode: widget.interactionMode,
      startFresh: startFresh,
    );
    if (!mounted || requestSerial != _soloEntryRequestSerial) return;
    final session = ref.read(interactiveStoryProvider).session;
    if (opened &&
        session != null &&
        session.storyId == widget.storyId &&
        !ref.read(interactiveStoryProvider).isLoading) {
      setState(() {
        _soloEntryView = _SoloEntryView.session;
        _soloEntryBusy = false;
      });
      return;
    }
    setState(() {
      _soloEntryView = _SoloEntryView.session;
      _soloEntryBusy = false;
      _soloEntryError =
          ref.read(interactiveStoryProvider).error ??
          'This solo session could not be opened.';
    });
  }

  Future<void> _openSoloHistorySession(
    SoloInteractiveSessionSummary summary,
  ) async {
    if (_soloEntryBusy) return;
    final currentState = ref.read(interactiveStoryProvider);
    final currentSession = currentState.session;
    if (currentSession?.sessionId == summary.sessionId &&
        !currentState.isReadOnly) {
      setState(() {
        _soloEntryView = _SoloEntryView.session;
        _soloEntryError = null;
      });
      return;
    }
    if (currentSession != null && !currentState.isReadOnly) {
      final shouldSwitch = await _confirmSoloSessionSwitch();
      if (!mounted || !shouldSwitch) return;
      setState(() {
        _soloEntryView = _SoloEntryView.session;
        _soloEntryBusy = true;
      });
      await ref.read(interactiveStoryProvider.notifier).leaveSession();
      if (!mounted) return;
      setState(() => _soloEntryBusy = false);
    }
    final requestSerial = ++_soloEntryRequestSerial;
    setState(() {
      _soloEntryView = _SoloEntryView.session;
      _soloEntryBusy = true;
      _soloEntryError = null;
    });
    final notifier = ref.read(interactiveStoryProvider.notifier);
    final opened = summary.isResumable
        ? await notifier.openExact(summary.sessionId)
        : await notifier.loadReadOnly(summary.sessionId);
    if (!mounted || requestSerial != _soloEntryRequestSerial) return;
    final state = ref.read(interactiveStoryProvider);
    if (opened &&
        state.session?.sessionId == summary.sessionId &&
        !state.isLoading) {
      setState(() {
        _soloEntryView = _SoloEntryView.session;
        _soloEntryBusy = false;
      });
      return;
    }
    setState(() {
      _soloEntryBusy = false;
      _soloEntryError = state.error ?? 'This session could not be opened.';
    });
  }

  Future<void> _openExactSoloSession(String sessionId) async {
    if (_soloEntryBusy) return;
    final requestSerial = ++_soloEntryRequestSerial;
    setState(() {
      _soloEntryView = _SoloEntryView.session;
      _soloEntryBusy = true;
      _soloEntryError = null;
    });
    final opened = await ref
        .read(interactiveStoryProvider.notifier)
        .openExact(sessionId);
    if (!mounted || requestSerial != _soloEntryRequestSerial) return;
    final state = ref.read(interactiveStoryProvider);
    if (opened && state.session?.sessionId == sessionId && !state.isLoading) {
      setState(() {
        _soloEntryView = _SoloEntryView.session;
        _soloEntryBusy = false;
      });
      return;
    }
    setState(() {
      _soloEntryView = _SoloEntryView.session;
      _soloEntryBusy = false;
      _soloEntryError = state.error ?? 'This session could not be opened.';
    });
  }

  Future<void> _requestStartFresh() async {
    if (_soloEntryBusy) return;
    final state = ref.read(interactiveStoryProvider);
    if (state.session != null && !state.isReadOnly) {
      final shouldStart = await _confirmSoloSessionSwitch(startFresh: true);
      if (!mounted || !shouldStart) return;
    }
    await _startSoloSession(startFresh: true);
  }

  Future<bool> _confirmSoloSessionSwitch({bool startFresh = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _LeaveGameDialog(
        title: startFresh ? 'Start a new session?' : 'Switch sessions?',
        message: startFresh
            ? 'Your current solo session will stay in History, and a new one will begin.'
            : 'Your current solo session will be paused so you can open this one.',
        icon: CupertinoIcons.clock,
        iconBackground: const Color(0xFF22C55E).withValues(alpha: 0.12),
        iconColor: const Color(0xFF22C55E),
        confirmLabel: startFresh ? 'Start new' : 'Switch',
      ),
    );
    return result == true;
  }

  Future<void> showHistory() async {
    if (widget.interactionMode == 'group' ||
        widget.launchMode != InteractiveStoryLaunchMode.create ||
        _soloEntryBusy) {
      return;
    }
    if (_hasActiveTimedSoloQuestion()) {
      showToast(
        context,
        'Finish this timed question before opening session history.',
      );
      return;
    }
    _textFocusNode.unfocus();
    _resetCustomTopicEntry(clearText: true);
    _historyReturnSessionId = ref
        .read(interactiveStoryProvider)
        .session
        ?.sessionId;
    await _loadSoloEntry(openHistory: true, honorPreferredSession: false);
  }

  bool _hasActiveTimedSoloQuestion() {
    final session = ref.read(interactiveStoryProvider).session;
    final state = session?.interactiveState;
    if (state == null ||
        state['session_type'] != 'solo' ||
        state['phase'] != 'question_active') {
      return false;
    }
    final expiresAt =
        state['expires_at'] ?? ((state['question'] as Map?)?['expires_at']);
    return expiresAt?.toString().trim().isNotEmpty == true;
  }

  void _closeHistory() {
    if (_soloEntryBusy) return;
    final activeSessionId = ref
        .read(interactiveStoryProvider)
        .session
        ?.sessionId;
    setState(() {
      _soloEntryView =
          _historyReturnSessionId != null &&
              activeSessionId == _historyReturnSessionId
          ? _SoloEntryView.session
          : _SoloEntryView.launcher;
      _soloEntryError = null;
    });
  }

  Future<bool> handleBack() async {
    if (_soloEntryView == _SoloEntryView.history) {
      _closeHistory();
      return true;
    }
    final providerState = ref.read(interactiveStoryProvider);
    if (_soloEntryView == _SoloEntryView.session &&
        providerState.isReadOnly &&
        _soloSessionHistory.isNotEmpty) {
      await ref.read(interactiveStoryProvider.notifier).leaveSession();
      if (!mounted) return true;
      await _loadSoloEntry(openHistory: true, honorPreferredSession: false);
      return true;
    }
    return false;
  }

  String _soloEntryErrorText(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) return 'Solo history could not be loaded.';
    return text.replaceFirst(RegExp(r'^(ApiError|Exception):\s*'), '');
  }

  void _sendText() {
    final session = ref.read(interactiveStoryProvider).session;
    if (!_shouldShowTextComposer(session)) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final state = session?.interactiveState ?? const <String, dynamic>{};
    final isCustomTopicSubmission =
        state['session_type'] == 'solo' && state['phase'] == 'topic_selection';
    final isCustomAspectSubmission =
        isCustomTopicSubmission && state['topic_selection_stage'] == 'aspect';
    final customAspectMetadata = isCustomAspectSubmission
        ? _customAspectExpectationMetadata(state)
        : const <String, dynamic>{};
    _textController.clear();
    if (isCustomTopicSubmission) _resetCustomTopicEntry();
    final isGroupQuizChat =
        state['template'] == 'quiz' &&
        state['session_type'] == 'group' &&
        (state['phase'] == 'showing_results' || state['phase'] == 'completed');
    final isPostSetupSoloChat =
        session != null &&
        state['session_type'] == 'solo' &&
        _hasCompletedSoloQuizSetup(session) &&
        _shouldShowSoloModeSwitch(session) &&
        _effectiveSoloViewMode(session) == 'chat';
    final notifier = ref.read(interactiveStoryProvider.notifier);
    unawaited(
      isGroupQuizChat
          ? notifier.submitPlayerChat(text)
          : notifier.submitText(
              text,
              inputType: isPostSetupSoloChat ? 'solo_chat' : 'text',
              metadata: customAspectMetadata,
            ),
    );
  }

  bool _shouldShowTextComposer(InteractiveSessionState? session) {
    if (session == null) return false;
    if (!_isQuizSession(session)) return true;
    final state = session.interactiveState;
    final phase = (state['phase'] as String?) ?? '';
    final sessionType = (state['session_type'] as String?) ?? '';
    if (sessionType == 'group' &&
        (phase == 'showing_results' || phase == 'completed')) {
      return true;
    }
    if (sessionType == 'group' &&
        phase == 'group_setup' &&
        state['group_setup_stage'] == 'topic_subject') {
      return true;
    }
    if (sessionType != 'solo') return false;
    if (phase == 'topic_selection') return true;
    if (_hasCompletedSoloQuizSetup(session) &&
        _shouldShowSoloModeSwitch(session) &&
        _effectiveSoloViewMode(session) == 'chat' &&
        !_isShowingQuizTopicDecision(session)) {
      return true;
    }
    if (phase == 'discussion') return true;
    return false;
  }

  bool _isAspectSelectionStage(InteractiveSessionState? session) {
    final state = session?.interactiveState;
    return state?['session_type'] == 'solo' &&
        state?['phase'] == 'topic_selection' &&
        state?['topic_selection_stage'] == 'aspect';
  }

  String _effectiveSoloViewMode(InteractiveSessionState? session) {
    if (session == null) return 'quiz';
    if (_soloViewSessionId == session.sessionId &&
        _soloViewModeOverride != null) {
      return _soloViewModeOverride!;
    }
    return session.interactiveState['phase'] == 'discussion' ? 'chat' : 'quiz';
  }

  bool _hasCompletedSoloQuizSetup(InteractiveSessionState? session) {
    if (session == null || session.interactiveState['session_type'] != 'solo') {
      return false;
    }
    if (session.interactiveState['quiz_setup_complete'] == true) return true;
    final selectedTopic = session.interactiveState['selected_topic']
        ?.toString()
        .trim();
    final phase = session.interactiveState['phase']?.toString() ?? '';
    return selectedTopic?.isNotEmpty == true &&
        const {
          'generating_question',
          'question_generation_started',
          'generation_failed',
          'question_active',
          'finalizing_question',
          'showing_results',
          'post_question_prompt',
        }.contains(phase);
  }

  bool _shouldShowSoloModeSwitch(InteractiveSessionState? session) {
    if (session == null || session.interactiveState['session_type'] != 'solo') {
      return false;
    }
    final selectedTopic = session.interactiveState['selected_topic']
        ?.toString()
        .trim();
    if (selectedTopic == null || selectedTopic.isEmpty) return false;
    final phase = session.interactiveState['phase']?.toString() ?? '';
    if (phase == 'discussion') return true;
    return _hasCompletedSoloQuizSetup(session) &&
        !const {
          'topic_selection',
          'mode_selection',
          'timer_selection',
          'completed',
          'complete',
        }.contains(phase);
  }

  bool _isShowingQuizTopicDecision(InteractiveSessionState? session) {
    return session != null &&
        _soloViewSessionId == session.sessionId &&
        _showQuizTopicDecision;
  }

  void _handleSoloChoice(String optionId) {
    final notifier = ref.read(interactiveStoryProvider.notifier);
    final session = ref.read(interactiveStoryProvider).session;
    if (session == null || session.interactiveState['session_type'] != 'solo') {
      unawaited(
        notifier.submitOption(optionId: optionId, inputType: 'option_select'),
      );
      return;
    }
    final normalized = optionId.trim().toLowerCase();
    final phase = session.interactiveState['phase']?.toString() ?? '';
    final displayText = _soloOptionDisplayText(session, optionId);

    if (phase == 'topic_selection' &&
        _customTopicEntryEnabled &&
        _customAspectEntryEnabled &&
        normalized != 'custom_aspect') {
      return;
    }

    if (phase == 'topic_selection' &&
        (normalized == 'custom_topic' || normalized == 'custom_aspect')) {
      _enableCustomTopicEntry();
      return;
    }

    if (_isShowingQuizTopicDecision(session)) {
      if (normalized == 'continue_topic') {
        setState(() {
          _soloViewSessionId = session.sessionId;
          _soloViewModeOverride = 'quiz';
          _showQuizTopicDecision = false;
        });
        if (phase == 'post_question_prompt') {
          unawaited(
            notifier.submitOption(
              optionId: 'continue_topic',
              inputType: 'option_select',
              displayText: displayText,
            ),
          );
        } else if (phase == 'discussion' ||
            !_hasCompletedSoloQuizSetup(session)) {
          unawaited(
            notifier.submitOption(
              optionId: 'quiz',
              inputType: 'option_select',
              displayText: _soloOptionDisplayText(session, 'quiz'),
            ),
          );
        }
        return;
      }
      if (normalized == 'new_topic') {
        unawaited(_restartForNewQuizTopic());
        return;
      }
    }

    if (_shouldShowSoloModeSwitch(session)) {
      if (normalized == 'chat') {
        setState(() {
          _soloViewSessionId = session.sessionId;
          _soloViewModeOverride = 'chat';
          _showQuizTopicDecision = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _textFocusNode.requestFocus();
        });
        return;
      }
      if (normalized == 'quiz') {
        if (_effectiveSoloViewMode(session) == 'chat') {
          if (_hasCompletedSoloQuizSetup(session)) {
            _textFocusNode.unfocus();
            setState(() {
              _soloViewSessionId = session.sessionId;
              _showQuizTopicDecision = true;
            });
          } else {
            setState(() {
              _soloViewSessionId = session.sessionId;
              _soloViewModeOverride = 'quiz';
            });
            unawaited(
              notifier.submitOption(
                optionId: 'quiz',
                inputType: 'option_select',
                displayText: _soloOptionDisplayText(session, 'quiz'),
              ),
            );
          }
        } else if (phase == 'post_question_prompt') {
          unawaited(
            notifier.submitOption(
              optionId: 'continue_topic',
              inputType: 'option_select',
              displayText: displayText,
            ),
          );
        }
        return;
      }
    }

    unawaited(
      notifier.submitOption(
        optionId: optionId,
        inputType: 'option_select',
        displayText: displayText,
      ),
    );
  }

  String? _soloOptionDisplayText(
    InteractiveSessionState session,
    String optionId,
  ) {
    final choice = _activeSoloOptionChoice(
      session: session,
      hasPendingBottomChoice: false,
      hasPendingBottomText: false,
      showQuizTopicDecision: _isShowingQuizTopicDecision(session),
      showSoloModeSwitch: _shouldShowSoloModeSwitch(session),
      soloViewMode: _effectiveSoloViewMode(session),
    );
    final normalized = optionId.trim().toLowerCase();
    for (final option in choice?.options ?? const <InteractiveOption>[]) {
      if (option.id.trim().toLowerCase() == normalized) {
        return option.label.trim().isNotEmpty ? option.label.trim() : option.id;
      }
    }
    return null;
  }

  Future<void> _restartForNewQuizTopic() async {
    if (_isRestartingForNewTopic) return;
    _textFocusNode.unfocus();
    _resetCustomTopicEntry(clearText: true);
    setState(() {
      _isRestartingForNewTopic = true;
      _resumeQuizAfterNewTopic = true;
      _showQuizTopicDecision = false;
      _soloViewSessionId = null;
      _soloViewModeOverride = null;
    });
    await ref
        .read(interactiveStoryProvider.notifier)
        .restart(
          storyId: widget.storyId,
          interactionMode: widget.interactionMode,
          sessionType: 'solo',
        );
    if (mounted) setState(() => _isRestartingForNewTopic = false);
  }

  void _advanceGroupHostQuiz(
    InteractiveSessionState session,
    String? currentUserId,
  ) {
    if (_groupHostAdvancePanelActionLabel(session) == 'Show final results') {
      unawaited(
        showGroupQuizResultsBottomSheet(
          context,
          session: session,
          currentUserId: currentUserId,
        ),
      );
      unawaited(
        ref
            .read(interactiveStoryProvider.notifier)
            .advanceQuestion(showLoading: false),
      );
      return;
    }
    unawaited(ref.read(interactiveStoryProvider.notifier).advanceQuestion());
  }

  void _syncSoloViewState(InteractiveStoryState next) {
    final session = next.session;
    if (session == null) return;
    final phase = session.interactiveState['phase']?.toString() ?? '';
    if (_soloViewSessionId != null && _soloViewSessionId != session.sessionId) {
      setState(() {
        _soloViewSessionId = null;
        _soloViewModeOverride = null;
        _showQuizTopicDecision = false;
      });
    }
    if (_resumeQuizAfterNewTopic && phase == 'mode_selection') {
      _resumeQuizAfterNewTopic = false;
      unawaited(
        ref
            .read(interactiveStoryProvider.notifier)
            .submitOption(optionId: 'quiz', inputType: 'option_select'),
      );
    } else if (_resumeQuizAfterNewTopic &&
        phase == 'topic_selection' &&
        session.interactiveState['topic_selection_stage'] == 'aspect') {
      _resumeQuizAfterNewTopic = false;
    }
  }

  void _enableCustomTopicEntry() {
    final session = ref.read(interactiveStoryProvider).session;
    if (session == null) return;
    final state = session.interactiveState;
    if (state['session_type'] != 'solo' ||
        state['phase'] != 'topic_selection') {
      return;
    }
    final isAspectEntry = state['topic_selection_stage'] == 'aspect';
    setState(() {
      _customTopicEntryEnabled = true;
      _customTopicSessionId = session.sessionId;
      _customAspectEntryEnabled = isAspectEntry;
      _customAspectRevision = isAspectEntry
          ? state['topic_aspect_revision']?.toString().trim()
          : null;
      _customAspectPath = isAspectEntry
          ? _topicPathSnapshot(state)
          : const <String>[];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _shouldShowTextComposer(ref.read(interactiveStoryProvider).session)) {
        _textFocusNode.requestFocus();
      }
    });
  }

  void _resetCustomTopicEntry({bool clearText = false}) {
    if (clearText) _textController.clear();
    _textFocusNode.unfocus();
    if (!_customTopicEntryEnabled &&
        _customTopicSessionId == null &&
        !_customAspectEntryEnabled &&
        _customAspectRevision == null &&
        _customAspectPath.isEmpty) {
      return;
    }
    setState(() {
      _customTopicEntryEnabled = false;
      _customTopicSessionId = null;
      _customAspectEntryEnabled = false;
      _customAspectRevision = null;
      _customAspectPath = const <String>[];
    });
  }

  void _submitSuggestedTopic(String topic) {
    _resetCustomTopicEntry(clearText: true);
    unawaited(ref.read(interactiveStoryProvider.notifier).submitText(topic));
  }

  void _syncCustomTopicEntry(InteractiveStoryState next) {
    if (!_customTopicEntryEnabled) return;
    final session = next.session;
    var remainsInTopicSelection =
        session?.sessionId == _customTopicSessionId &&
        session?.interactiveState['session_type'] == 'solo' &&
        session?.interactiveState['phase'] == 'topic_selection';
    if (remainsInTopicSelection && _customAspectEntryEnabled) {
      final interactiveState = session!.interactiveState;
      remainsInTopicSelection =
          interactiveState['topic_selection_stage'] == 'aspect' &&
          interactiveState['topic_aspect_revision']?.toString().trim() ==
              _customAspectRevision &&
          _sameTopicPath(
            _topicPathSnapshot(interactiveState),
            _customAspectPath,
          );
    }
    if (!remainsInTopicSelection) {
      _resetCustomTopicEntry(clearText: true);
    }
  }

  Map<String, dynamic> _customAspectExpectationMetadata(
    Map<String, dynamic> interactiveState,
  ) {
    final revision = interactiveState['topic_aspect_revision']
        ?.toString()
        .trim();
    final path = _topicPathSnapshot(interactiveState);
    if (revision == null || revision.isEmpty || path.isEmpty) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{
      'expected_revision': revision,
      'expected_topic_path': path,
    };
  }

  List<String> _topicPathSnapshot(Map<String, dynamic> interactiveState) {
    return ((interactiveState['topic_path'] as List?) ?? const [])
        .map((part) => part.toString().trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  bool _sameTopicPath(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
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
      _syncCustomTopicEntry(next);
      _syncSoloViewState(next);
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
    final showLoadingShell =
        _soloEntryBusy || state.isLoading || session == null;
    if (widget.isLeavingGame) {
      return const SizedBox.expand();
    }
    if (_soloEntryView == _SoloEntryView.checking) {
      return const _StorySessionLoadingShell(title: 'CHECKING SESSIONS...');
    }
    if (_soloEntryView == _SoloEntryView.launcher) {
      final latest = _latestResumableSoloSession;
      return SoloInteractiveSessionLauncher(
        latestSession: latest,
        hasHistory: _soloSessionHistory.isNotEmpty,
        isBusy: _soloEntryBusy,
        error: _soloEntryError,
        onContinue: () {
          if (latest != null) unawaited(_openSoloHistorySession(latest));
        },
        onStartFresh: () => unawaited(_requestStartFresh()),
        onViewHistory: () {
          setState(() {
            _soloEntryView = _SoloEntryView.history;
            _soloEntryError = null;
          });
        },
        onRetry: () => unawaited(
          _loadSoloEntry(honorPreferredSession: false, forceRefresh: true),
        ),
      );
    }
    if (_soloEntryView == _SoloEntryView.history) {
      return SoloInteractiveSessionHistoryView(
        sessions: _soloSessionHistory,
        isBusy: _soloEntryBusy,
        error: _soloEntryError,
        onBack: _closeHistory,
        onSelect: (summary) => unawaited(_openSoloHistorySession(summary)),
        onStartFresh: () => unawaited(_requestStartFresh()),
        onRetry: () => unawaited(
          _loadSoloEntry(
            openHistory: true,
            honorPreferredSession: false,
            forceRefresh: true,
          ),
        ),
      );
    }
    final isReadOnlyHistory = state.isReadOnly;
    final isQuizSession = _isQuizSession(session);
    final phase = (session?.interactiveState['phase'] as String?) ?? '';
    final isSoloQuizSession =
        isQuizSession && session?.interactiveState['session_type'] == 'solo';
    final isGroupQuizSession =
        isQuizSession && session?.interactiveState['session_type'] == 'group';
    final soloViewMode = _effectiveSoloViewMode(session);
    final showQuizTopicDecision = _isShowingQuizTopicDecision(session);
    final showSoloModeSwitch =
        _shouldShowSoloModeSwitch(session) && !showQuizTopicDecision;
    final showTextComposer =
        !isReadOnlyHistory && _shouldShowTextComposer(session);
    final isAspectSelectionStage = _isAspectSelectionStage(session);
    final topicSuggestions = session?.interactiveState['topic_suggestions'];
    final pendingTopicOptions =
        session?.interactiveState['pending_topic_options'];
    final pendingTopicAspects =
        session?.interactiveState['pending_topic_aspects'];
    final hasPendingBottomText = state.pendingInputKeys.any(
      (key) => key.contains('-text-'),
    );
    final hasCustomTopicAnchor =
        !hasPendingBottomText &&
        (pendingTopicOptions is! List || pendingTopicOptions.isEmpty) &&
        ((topicSuggestions as List?) ?? const <dynamic>[]).whereType<Map>().any(
          (option) =>
              option['id']?.toString().trim().toLowerCase() == 'custom_topic',
        );
    final hasPendingBottomChoice = state.pendingInputKeys.any(
      (key) => key.contains('-option_select-'),
    );
    final activeChoiceTurn = _activeInteractiveTurn(session);
    final topicAspectStatus = session?.interactiveState['topic_aspect_status']
        ?.toString()
        .trim()
        .toLowerCase();
    final topicAspectIsLoading =
        topicAspectStatus == 'generating' || topicAspectStatus == 'loading';
    final topicPathActionsExpanded =
        session?.interactiveState['topic_path_actions_expanded'] == true;
    final hasAspectPathActions =
        isAspectSelectionStage &&
        !topicAspectIsLoading &&
        !hasPendingBottomText &&
        !hasPendingBottomChoice &&
        session != null &&
        _turnHasMatchingGuidedChoiceKind(
          activeChoiceTurn,
          'solo_topic_path_actions',
          session.interactiveState,
        );
    final hasAspectActionCallAnchor = hasAspectPathActions;
    final allowCustomAspect = session?.interactiveState['allow_custom_aspect'];
    final customAspectAllowed = topicAspectStatus == 'max_depth'
        ? allowCustomAspect == true
        : allowCustomAspect != false;
    final hasCustomAspectCallAnchor =
        isAspectSelectionStage &&
        !topicAspectIsLoading &&
        !hasPendingBottomText &&
        !hasAspectActionCallAnchor &&
        !hasPendingBottomChoice &&
        !topicPathActionsExpanded &&
        customAspectAllowed &&
        (topicAspectStatus == 'failed' ||
            topicAspectStatus == 'max_depth' ||
            (session != null &&
                _turnHasMatchingGuidedChoiceKind(
                  activeChoiceTurn,
                  'solo_topic_aspect',
                  session.interactiveState,
                )) ||
            (topicAspectStatus == 'ready' &&
                pendingTopicAspects is List &&
                pendingTopicAspects.isNotEmpty));
    final hasModeChoiceAnchor =
        phase == 'mode_selection' &&
        !hasPendingBottomChoice &&
        _hasSoloChoiceKind(session, 'solo_quiz_mode');
    final hasTimerChoiceAnchor =
        phase == 'timer_selection' &&
        !hasPendingBottomChoice &&
        isSoloQuizSession;
    final hasPersistentModeAnchor =
        showSoloModeSwitch && !hasPendingBottomChoice;
    final hasQuizTopicDecisionAnchor =
        showQuizTopicDecision && !hasPendingBottomChoice;
    final floatSoloChoiceCall =
        !isReadOnlyHistory &&
        isSoloQuizSession &&
        !showTextComposer &&
        ((phase == 'topic_selection' &&
                (isAspectSelectionStage
                    ? (hasAspectActionCallAnchor || hasCustomAspectCallAnchor)
                    : hasCustomTopicAnchor)) ||
            hasModeChoiceAnchor ||
            hasTimerChoiceAnchor ||
            hasPersistentModeAnchor ||
            hasQuizTopicDecisionAnchor);
    final canSubmitText = showTextComposer && _canSend;
    final canRetryQuestionGeneration = _canRetryQuizGeneration(
      session,
      currentUserId,
    );
    final questionGenerationFailed = phase == 'generation_failed';
    final showQuestionGenerationOverlay =
        isQuizSession &&
        session != null &&
        soloViewMode != 'chat' &&
        !showQuizTopicDecision &&
        (questionGenerationFailed ||
            state.isGenerationTakingLong ||
            state.isRetryingGeneration);
    final questionGenerationRetrying = state.isRetryingGeneration;
    final disableQuizGameControls =
        isGroupQuizSession &&
        (phase == 'generation_failed' || state.isRetryingGeneration);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final sessionReadyForOptions = !showLoadingShell;
    final canHostAdvanceGroupQuiz =
        sessionReadyForOptions &&
        isGroupQuizSession &&
        _canCurrentUserHostGroupQuiz(session, currentUserId) &&
        _isGroupQuizManualAdvancePhase(session);
    final groupSetupChoice = session != null && isGroupQuizSession
        ? _activeGroupSetupChoice(session)
        : null;
    final soloOptionChoice = sessionReadyForOptions && isSoloQuizSession
        ? _activeSoloOptionChoice(
            session: session,
            hasPendingBottomChoice: hasPendingBottomChoice,
            hasPendingBottomText: hasPendingBottomText,
            showQuizTopicDecision: showQuizTopicDecision,
            showSoloModeSwitch: showSoloModeSwitch,
            soloViewMode: soloViewMode,
          )
        : null;
    final canHostSetupGroupQuiz =
        sessionReadyForOptions &&
        isGroupQuizSession &&
        groupSetupChoice != null &&
        _canCurrentUserHostGroupQuiz(session, currentUserId);
    final showGroupSetupOptions = canHostSetupGroupQuiz;
    final showGroupHostAdvanceOptions =
        canHostAdvanceGroupQuiz &&
        !state.isAdvancingQuestion &&
        (!_textFocusNode.hasFocus || keyboardHeight == 0);
    final showGroupFocusedComposer =
        canHostAdvanceGroupQuiz &&
        !state.isAdvancingQuestion &&
        _textFocusNode.hasFocus &&
        keyboardHeight > 0;
    final showGroupCompletedOptions =
        sessionReadyForOptions &&
        isGroupQuizSession &&
        _isGroupQuizCompleted(session);
    final rawShowSoloOptionPanel =
        soloOptionChoice != null && !hasPendingBottomChoice;
    final rawShowGroupOptionPanel =
        showGroupCompletedOptions ||
        showGroupHostAdvanceOptions ||
        showGroupSetupOptions;
    final rawShowAnyOptionPanel =
        rawShowGroupOptionPanel || rawShowSoloOptionPanel;
    final showSoloOptionPanel = rawShowSoloOptionPanel;
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            if (isReadOnlyHistory) const SoloHistoryReadOnlyBanner(),
            Expanded(
              child: showLoadingShell
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
                        readOnly: isReadOnlyHistory,
                        currentUserId: currentUserId,
                        pendingKeys: state.pendingInputKeys,
                        pendingTextMessages: state.pendingTextMessages,
                        localQuizSelections: state.localQuizSelections,
                        streamingAssistantText: state.streamingAssistantText,
                        recentStreamedAssistantText:
                            state.recentStreamedAssistantText,
                        soloViewMode: soloViewMode,
                        showSoloModeSwitch: showSoloModeSwitch,
                        showQuizTopicDecision: showQuizTopicDecision,
                        hideSoloOptionSuggestions: isSoloQuizSession,
                        suppressInternalOptionFooter: rawShowAnyOptionPanel,
                        onTranscriptRevealInProgressChanged:
                            _handleTranscriptRevealInProgressChanged,
                        alignSoloOptionsRight: !showTextComposer,
                        showAdvanceQuestionStatusAction:
                            !showGroupHostAdvanceOptions,
                        showAdvanceQuestionStatus: !showGroupHostAdvanceOptions,
                        showFinalStandingsActions: !showGroupCompletedOptions,
                        bottomOverlayPadding: rawShowAnyOptionPanel ? 1 : 0,
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
                        onChoice: _handleSoloChoice,
                        onTopicSuggestion: _submitSuggestedTopic,
                        onCustomTopicRequested: _enableCustomTopicEntry,
                        hideCustomTopicSuggestion:
                            _customTopicEntryEnabled &&
                            _customTopicSessionId == session.sessionId,
                        customTopicCallLink: floatSoloChoiceCall
                            ? _customTopicCallLink
                            : null,
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
            if (showTextComposer &&
                !showGroupHostAdvanceOptions &&
                !showGroupFocusedComposer &&
                !showGroupSetupOptions &&
                !showGroupCompletedOptions &&
                !showSoloOptionPanel)
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.transparent),
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
                              key: const ValueKey('solo-topic-text-field'),
                              controller: _textController,
                              focusNode: _textFocusNode,
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
                                hintText: phase == 'topic_selection'
                                    ? isAspectSelectionStage
                                          ? 'Type your own aspect'
                                          : 'Type your own topic'
                                    : phase == 'group_setup'
                                    ? 'Type a topic or subject'
                                    : phase == 'showing_results'
                                    ? 'Message the room'
                                    : 'Message',
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
                          background: canSubmitText
                              ? (isDark ? Colors.white : Colors.black)
                              : mutedSurface,
                          foreground: canSubmitText
                              ? (isDark ? Colors.black : Colors.white)
                              : mutedText,
                          onTap: canSubmitText ? _sendText : () {},
                        ),
                        if (!floatSoloChoiceCall) ...[
                          const SizedBox(width: 8),
                          _CircleIconButton(
                            icon: Icons.call_rounded,
                            tooltip: 'Voice',
                            background: const Color(0xFF22C55E),
                            foreground: Colors.white,
                            onTap: widget.onCall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else if (session != null &&
                !isReadOnlyHistory &&
                !floatSoloChoiceCall &&
                (!canHostAdvanceGroupQuiz || state.isAdvancingQuestion) &&
                !showGroupHostAdvanceOptions &&
                !showGroupFocusedComposer &&
                !showGroupSetupOptions &&
                !showGroupCompletedOptions &&
                !showSoloOptionPanel)
              _QuizGameBottomBar(
                onCall: widget.onCall,
                disabled: disableQuizGameControls,
                showMessagePlaceholder:
                    !isSoloQuizSession || hasPendingBottomChoice,
              ),
            if (!showLoadingShell &&
                showGroupHostAdvanceOptions &&
                !isReadOnlyHistory)
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: SizedBox(
                  key: _groupOptionPanelKey,
                  width: double.infinity,
                  child: _GroupHostAdvanceOptionPanel(
                    title: _groupHostAdvancePanelTitle(session),
                    body: _groupHostAdvancePanelBody(session),
                    actionLabel: _groupHostAdvancePanelActionLabel(session),
                    collapsed: _groupHostAdvancePanelCollapsed,
                    disabled:
                        disableQuizGameControls || state.isAdvancingQuestion,
                    onToggleCollapsed: () {
                      setState(
                        () => _groupHostAdvancePanelCollapsed =
                            !_groupHostAdvancePanelCollapsed,
                      );
                    },
                    onAdvance: () =>
                        _advanceGroupHostQuiz(session, currentUserId),
                    onCall: widget.onCall,
                    textController: _textController,
                    textFocusNode: _textFocusNode,
                    textFieldKey: _groupMessageFieldKey,
                    canSubmitText: canSubmitText,
                    onSendText: _sendText,
                  ),
                ),
              ),
            if (!showLoadingShell &&
                showGroupSetupOptions &&
                !isReadOnlyHistory)
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: SizedBox(
                  key: _groupOptionPanelKey,
                  width: double.infinity,
                  child: _GroupSetupOptionPanel(
                    title: '',
                    options: groupSetupChoice.options,
                    collapsed: _groupSetupPanelCollapsed,
                    disabled: disableQuizGameControls || hasPendingBottomChoice,
                    onToggleCollapsed: () {
                      setState(
                        () => _groupSetupPanelCollapsed =
                            !_groupSetupPanelCollapsed,
                      );
                    },
                    onSelected: _handleSoloChoice,
                    onCall: widget.onCall,
                    textController: _textController,
                    textFocusNode: _textFocusNode,
                    textFieldKey: _groupMessageFieldKey,
                    canSubmitText:
                        !hasPendingBottomChoice &&
                        groupSetupChoice.allowTextInput &&
                        canSubmitText,
                    hintText: groupSetupChoice.inputHint,
                    onSendText: _sendText,
                  ),
                ),
              ),
            if (!showLoadingShell && showSoloOptionPanel && !isReadOnlyHistory)
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: SizedBox(
                  key: _groupOptionPanelKey,
                  width: double.infinity,
                  child: _GroupSetupOptionPanel(
                    title: soloOptionChoice.prompt,
                    options: hasPendingBottomChoice
                        ? const <InteractiveOption>[]
                        : soloOptionChoice.options,
                    collapsed: _groupSetupPanelCollapsed,
                    disabled: disableQuizGameControls,
                    onToggleCollapsed: () {
                      setState(
                        () => _groupSetupPanelCollapsed =
                            !_groupSetupPanelCollapsed,
                      );
                    },
                    onSelected: _handleSoloChoice,
                    onCall: widget.onCall,
                    textController: _textController,
                    textFocusNode: _textFocusNode,
                    textFieldKey: _groupMessageFieldKey,
                    canSubmitText:
                        !hasPendingBottomChoice &&
                        soloOptionChoice.allowTextInput &&
                        _canSend,
                    hintText: soloOptionChoice.inputHint,
                    optionKeyPrefix: hasPendingBottomChoice
                        ? null
                        : soloOptionChoice.optionKeyPrefix,
                    inputKey: soloOptionChoice.inputKey,
                    onSendText: _sendText,
                    onInputRequested:
                        !hasPendingBottomChoice &&
                            phase == 'topic_selection' &&
                            soloOptionChoice.allowTextInput
                        ? _enableCustomTopicEntry
                        : null,
                  ),
                ),
              ),
            if (!showLoadingShell &&
                showGroupFocusedComposer &&
                !isReadOnlyHistory)
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                  child: _GroupFloatingTextComposer(
                    textController: _textController,
                    textFocusNode: _textFocusNode,
                    textFieldKey: _groupMessageFieldKey,
                    canSubmitText: canSubmitText,
                    onSendText: _sendText,
                    onCall: widget.onCall,
                  ),
                ),
              ),
            if (!showLoadingShell && showGroupCompletedOptions)
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: SizedBox(
                  key: _groupOptionPanelKey,
                  width: double.infinity,
                  child: _GroupCompletedOptionPanel(
                    collapsed: _groupCompletedPanelCollapsed,
                    onToggleCollapsed: () {
                      setState(
                        () => _groupCompletedPanelCollapsed =
                            !_groupCompletedPanelCollapsed,
                      );
                    },
                    onLeaderboard: () => unawaited(
                      showGroupQuizResultsBottomSheet(
                        context,
                        session: session,
                        currentUserId: currentUserId,
                      ),
                    ),
                    onReplay: () => unawaited(
                      notifier.restart(
                        storyId: widget.storyId,
                        interactionMode: widget.interactionMode,
                      ),
                    ),
                    onClose: () => unawaited(widget.onLeave()),
                    onCall: widget.onCall,
                    textController: _textController,
                    textFocusNode: _textFocusNode,
                    textFieldKey: _groupMessageFieldKey,
                    canSubmitText: canSubmitText,
                    onSendText: _sendText,
                  ),
                ),
              ),
          ],
        ),
        if (!showLoadingShell && floatSoloChoiceCall && !showSoloOptionPanel)
          CompositedTransformFollower(
            link: _customTopicCallLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.centerLeft,
            followerAnchor: Alignment.centerLeft,
            child: _QuizCallButton(
              key: const ValueKey('solo-topic-floating-call'),
              onTap: widget.onCall,
            ),
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
        if (showQuestionGenerationOverlay && !isReadOnlyHistory)
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
    this.confirmLabel = 'Leave',
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? iconBackground;
  final Color iconColor;
  final String confirmLabel;

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
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
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
  const _QuizGameBottomBar({
    required this.onCall,
    this.disabled = false,
    this.showMessagePlaceholder = true,
  });

  final VoidCallback onCall;
  final bool disabled;
  final bool showMessagePlaceholder;

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
            mainAxisAlignment: showMessagePlaceholder
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              if (showMessagePlaceholder) ...[
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
              ],
              _QuizCallButton(onTap: onCall),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupSetupOptionPanel extends StatelessWidget {
  const _GroupSetupOptionPanel({
    required this.title,
    required this.options,
    required this.collapsed,
    required this.disabled,
    required this.onToggleCollapsed,
    required this.onSelected,
    required this.onCall,
    required this.textController,
    required this.textFocusNode,
    required this.textFieldKey,
    required this.canSubmitText,
    this.hintText = 'Message',
    required this.onSendText,
    this.onInputRequested,
    this.optionKeyPrefix,
    this.inputKey,
  });

  final String title;
  final List<InteractiveOption> options;
  final bool collapsed;
  final bool disabled;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<String> onSelected;
  final VoidCallback onCall;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final GlobalKey textFieldKey;
  final bool canSubmitText;
  final String hintText;
  final VoidCallback onSendText;
  final VoidCallback? onInputRequested;
  final String? optionKeyPrefix;
  final Key? inputKey;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final hasTitle = title.trim().isNotEmpty;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: DecoratedBox(
        key: const ValueKey('group-setup-option-panel'),
        decoration: BoxDecoration(
          color: const Color(0xFF20211F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: collapsed ? 8 : 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (collapsed)
                            if (hasTitle)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Spacer()
                          else
                            const Spacer(),
                          SizedBox.square(
                            dimension: 28,
                            child: IconButton(
                              tooltip: collapsed
                                  ? 'Show options'
                                  : 'Hide options',
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onPressed: disabled ? null : onToggleCollapsed,
                              icon: Icon(
                                collapsed
                                    ? CupertinoIcons.chevron_up
                                    : CupertinoIcons.chevron_down,
                                size: 20,
                                color: disabled
                                    ? Colors.white30
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!collapsed) ...[
                      if (hasTitle) ...[
                        Text(
                          title,
                          maxLines: title.contains('\n') ? 8 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.22,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.13),
                        ),
                      ],
                      for (var index = 0; index < options.length; index++) ...[
                        _StoryActionOptionRow(
                          key: optionKeyPrefix == null
                              ? null
                              : ValueKey(
                                  '$optionKeyPrefix-${options[index].id}',
                                ),
                          label: options[index].label.isEmpty
                              ? options[index].id
                              : options[index].label,
                          disabled: disabled,
                          icon: CupertinoIcons.chevron_right,
                          onPressed: () => onSelected(options[index].id),
                        ),
                        if (index < options.length - 1)
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.13),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 4),
            _GroupAttachedTextComposer(
              textController: textController,
              textFocusNode: textFocusNode,
              textFieldKey: textFieldKey,
              canSubmitText: canSubmitText,
              hintText: hintText,
              onSendText: onSendText,
              onCall: disabled ? () {} : onCall,
              onInputRequested: onInputRequested,
              inputKey: inputKey,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHostAdvanceOptionPanel extends StatelessWidget {
  const _GroupHostAdvanceOptionPanel({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.collapsed,
    required this.disabled,
    required this.onToggleCollapsed,
    required this.onAdvance,
    required this.onCall,
    required this.textController,
    required this.textFocusNode,
    required this.textFieldKey,
    required this.canSubmitText,
    required this.onSendText,
  });

  final String title;
  final String body;
  final String actionLabel;
  final bool collapsed;
  final bool disabled;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onAdvance;
  final VoidCallback onCall;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final GlobalKey textFieldKey;
  final bool canSubmitText;
  final VoidCallback onSendText;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('group-host-advance-option-panel'),
            decoration: BoxDecoration(
              color: const Color(0xFF20211F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GroupHostAdvanceOptionContent(
                  title: title,
                  body: body,
                  actionLabel: actionLabel,
                  collapsed: collapsed,
                  disabled: disabled,
                  onToggleCollapsed: onToggleCollapsed,
                  onAdvance: onAdvance,
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 4),
                _GroupAttachedTextComposer(
                  textController: textController,
                  textFocusNode: textFocusNode,
                  textFieldKey: textFieldKey,
                  canSubmitText: canSubmitText,
                  onSendText: onSendText,
                  onCall: disabled ? () {} : onCall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupAttachedTextComposer extends StatelessWidget {
  const _GroupAttachedTextComposer({
    required this.textController,
    required this.textFocusNode,
    required this.textFieldKey,
    required this.canSubmitText,
    this.hintText = 'Message',
    required this.onSendText,
    required this.onCall,
    this.onInputRequested,
    this.inputKey,
  });

  final TextEditingController textController;
  final FocusNode textFocusNode;
  final GlobalKey textFieldKey;
  final bool canSubmitText;
  final String hintText;
  final VoidCallback onSendText;
  final VoidCallback onCall;
  final VoidCallback? onInputRequested;
  final Key? inputKey;

  void _requestInputFocus() {
    onInputRequested?.call();
    textFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final mutedText = isDark ? Colors.white60 : Colors.black54;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _requestInputFocus,
          child: Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Transform.translate(
              offset: const Offset(0, -4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 32,
                  child: Center(
                    child: Icon(
                      CupertinoIcons.pencil,
                      color: mutedText,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            key: inputKey,
            behavior: HitTestBehavior.translucent,
            onTap: _requestInputFocus,
            child: Transform.translate(
              offset: const Offset(0, -4),
              child: TextField(
                key: textFieldKey,
                controller: textController,
                focusNode: textFocusNode,
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
                  hintText: hintText,
                  hintStyle: TextStyle(color: mutedText, fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                  isDense: true,
                ),
                onTap: _requestInputFocus,
                onSubmitted: (_) => onSendText(),
              ),
            ),
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
              tooltip: 'Send',
              onPressed: canSubmitText ? onSendText : null,
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
        Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: _CircleIconButton(
            icon: Icons.call_rounded,
            tooltip: 'Voice',
            background: const Color(0xFF22C55E),
            foreground: Colors.white,
            onTap: onCall,
          ),
        ),
      ],
    );
  }
}

class _GroupFloatingTextComposer extends StatelessWidget {
  const _GroupFloatingTextComposer({
    required this.textController,
    required this.textFocusNode,
    required this.textFieldKey,
    required this.canSubmitText,
    required this.onSendText,
    required this.onCall,
  });

  final TextEditingController textController;
  final FocusNode textFocusNode;
  final GlobalKey textFieldKey;
  final bool canSubmitText;
  final VoidCallback onSendText;
  final VoidCallback onCall;

  void _requestInputFocus() => textFocusNode.requestFocus();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final mutedText = isDark ? Colors.white60 : Colors.black54;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: DecoratedBox(
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _requestInputFocus,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 32,
                        child: Center(
                          child: Icon(
                            CupertinoIcons.pencil,
                            color: mutedText,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _requestInputFocus,
                    child: TextField(
                      key: textFieldKey,
                      controller: textController,
                      focusNode: textFocusNode,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: Colors.white,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          14,
                          8,
                          14,
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => onSendText(),
                    ),
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
                      onPressed: canSubmitText ? onSendText : null,
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
        const SizedBox(width: 10),
        _CircleIconButton(
          icon: Icons.call_rounded,
          tooltip: 'Voice',
          background: const Color(0xFF22C55E),
          foreground: Colors.white,
          onTap: onCall,
        ),
      ],
    );
  }
}

class _GroupCompletedOptionPanel extends StatelessWidget {
  const _GroupCompletedOptionPanel({
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onLeaderboard,
    required this.onReplay,
    required this.onClose,
    required this.onCall,
    required this.textController,
    required this.textFocusNode,
    required this.textFieldKey,
    required this.canSubmitText,
    required this.onSendText,
  });

  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onLeaderboard;
  final VoidCallback onReplay;
  final VoidCallback onClose;
  final VoidCallback onCall;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final GlobalKey textFieldKey;
  final bool canSubmitText;
  final VoidCallback onSendText;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: DecoratedBox(
        key: const ValueKey('group-completed-option-panel'),
        decoration: BoxDecoration(
          color: const Color(0xFF20211F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, collapsed ? 14 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'Game finished',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox.square(
                          dimension: 28,
                          child: IconButton(
                            tooltip: collapsed
                                ? 'Show options'
                                : 'Hide options',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: onToggleCollapsed,
                            icon: Icon(
                              collapsed
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 20,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'View the leaderboard, replay this game, or close the room.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                      ),
                    ),
                    if (!collapsed) ...[
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.13),
                      ),
                      _StoryActionOptionRow(
                        label: 'Leaderboard',
                        disabled: false,
                        icon: CupertinoIcons.list_number,
                        onPressed: onLeaderboard,
                      ),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.13),
                      ),
                      _StoryActionOptionRow(
                        label: 'Replay',
                        disabled: false,
                        icon: CupertinoIcons.arrow_clockwise,
                        onPressed: onReplay,
                      ),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.13),
                      ),
                      _StoryActionOptionRow(
                        label: 'Close game',
                        disabled: false,
                        icon: CupertinoIcons.xmark,
                        onPressed: onClose,
                      ),
                    ],
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 4),
              _GroupAttachedTextComposer(
                textController: textController,
                textFocusNode: textFocusNode,
                textFieldKey: textFieldKey,
                canSubmitText: canSubmitText,
                onSendText: onSendText,
                onCall: onCall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHostAdvanceOptionContent extends StatelessWidget {
  const _GroupHostAdvanceOptionContent({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.collapsed,
    required this.disabled,
    required this.onToggleCollapsed,
    required this.onAdvance,
  });

  final String title;
  final String body;
  final String actionLabel;
  final bool collapsed;
  final bool disabled;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: collapsed ? 8 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (collapsed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  Transform.translate(
                    offset: collapsed ? Offset.zero : const Offset(0, 4),
                    child: SizedBox.square(
                      dimension: 28,
                      child: IconButton(
                        tooltip: collapsed ? 'Show options' : 'Hide options',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: disabled ? null : onToggleCollapsed,
                        icon: Icon(
                          collapsed
                              ? CupertinoIcons.chevron_up
                              : CupertinoIcons.chevron_down,
                          size: 20,
                          color: disabled ? Colors.white30 : Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!collapsed) ...[
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (body.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.28,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.13)),
              _StoryActionOptionRow(
                label: actionLabel,
                disabled: disabled,
                icon: CupertinoIcons.chevron_right,
                onPressed: onAdvance,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizCallButton extends StatelessWidget {
  const _QuizCallButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: const Icon(Icons.call_rounded, color: Colors.white, size: 25),
      ),
    );
  }
}

bool _hasSoloChoiceKind(InteractiveSessionState? session, String choiceKind) {
  if (_turnHasSoloChoiceKind(session?.currentTurn, choiceKind)) return true;
  if (session == null) return false;
  for (final event in session.events.reversed) {
    if (event.eventType != 'interactive_turn') continue;
    if (_turnHasSoloChoiceKind(
      InteractiveTurn.fromJson(event.payload),
      choiceKind,
    )) {
      return true;
    }
  }
  return false;
}

InteractiveTurn? _activeInteractiveTurn(InteractiveSessionState? session) {
  if (session == null) return null;
  final currentTurn = session.currentTurn;
  if (currentTurn != null) return currentTurn;
  StorySessionEvent? newestEvent;
  for (final event in session.events) {
    if (event.eventType != 'interactive_turn') continue;
    if (newestEvent == null || event.seq > newestEvent.seq) {
      newestEvent = event;
    }
  }
  return newestEvent == null
      ? null
      : InteractiveTurn.fromJson(newestEvent.payload);
}

_GroupSetupChoice? _activeGroupSetupChoice(InteractiveSessionState session) {
  final state = session.interactiveState;
  if (state['session_type'] != 'group' ||
      state['template'] != 'quiz' ||
      (state['phase'] != 'group_setup' &&
          state['phase'] != 'group_setup_review')) {
    return null;
  }
  final turn = _activeInteractiveTurn(session);
  if (turn == null) return null;
  for (final block in turn.blocks.whereType<InteractiveChoiceGroupBlock>()) {
    final choiceKind = block.metadata['choice_kind']?.toString().trim();
    if (choiceKind != 'group_quiz_setup' || block.options.isEmpty) continue;
    final textBlocks = turn.blocks
        .whereType<InteractiveTextBlock>()
        .map((block) => block.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final prompt = block.prompt.trim().isNotEmpty
        ? block.prompt.trim()
        : _groupSetupOptionPrompt(
            state['group_setup_stage']?.toString().trim(),
            textBlocks,
          );
    return _GroupSetupChoice(
      prompt: prompt.isEmpty ? 'Set up this game' : prompt,
      options: block.options
          .where((option) => option.id.trim().toLowerCase() != 'custom_topic')
          .toList(growable: false),
      allowTextInput: state['group_setup_stage'] == 'topic_subject',
      inputHint: state['group_setup_stage'] == 'topic_subject'
          ? 'Type a topic or subject'
          : 'Message',
    );
  }
  return null;
}

String _groupSetupOptionPrompt(String? stage, List<String> textBlocks) {
  if (textBlocks.isEmpty) return '';
  if (stage == 'review') return '';
  final text = textBlocks.join('\n\n').trim();
  if (stage == 'question_source') {
    final parts = text
        .split(RegExp(r'\n\s*\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? text : parts.last;
  }
  return text;
}

_GroupSetupChoice? _activeSoloOptionChoice({
  required InteractiveSessionState session,
  required bool hasPendingBottomChoice,
  required bool hasPendingBottomText,
  required bool showQuizTopicDecision,
  required bool showSoloModeSwitch,
  required String soloViewMode,
}) {
  final state = session.interactiveState;
  if (state['session_type'] != 'solo' || state['template'] != 'quiz') {
    return null;
  }
  if (hasPendingBottomText) {
    return null;
  }

  if (showQuizTopicDecision) {
    return const _GroupSetupChoice(
      prompt: '',
      options: [
        InteractiveOption(id: 'continue_topic', label: 'Continue last topic'),
        InteractiveOption(id: 'new_topic', label: 'Choose a new topic'),
      ],
      allowTextInput: false,
      inputHint: 'Message',
      optionKeyPrefix: 'topic-decision',
    );
  }

  if (showSoloModeSwitch) {
    final phase = state['phase']?.toString().trim().toLowerCase() ?? '';
    final normalizedMode = soloViewMode.trim().toLowerCase();
    final options = [
      if (normalizedMode != 'quiz' || phase == 'post_question_prompt')
        InteractiveOption(
          id: 'quiz',
          label: normalizedMode == 'quiz' ? 'Next question' : 'Take me to quiz',
        ),
      if (normalizedMode != 'chat')
        const InteractiveOption(id: 'chat', label: 'Chat with Aura'),
    ];
    if (options.isNotEmpty) {
      return _GroupSetupChoice(
        prompt: '',
        options: options,
        allowTextInput: normalizedMode == 'chat',
        inputHint: 'Message',
        optionKeyPrefix: 'persistent-mode',
      );
    }
  }

  if (state['phase'] == 'topic_selection' &&
      state['topic_selection_stage'] != 'aspect') {
    if (!_soloRootTopicPromptReady(state)) return null;
    final options = _soloTopicPanelOptions(
      state['pending_topic_options'],
      state['topic_suggestions'],
    );
    if (options.isNotEmpty) {
      return _GroupSetupChoice(
        prompt: '',
        options: options,
        allowTextInput: true,
        inputHint: 'Type your own topic',
      );
    }
  }

  final turn = _activeInteractiveTurn(session);
  if (state['phase'] == 'topic_selection' &&
      state['topic_selection_stage'] == 'aspect') {
    if (turn != null) {
      for (final block
          in turn.blocks.whereType<InteractiveChoiceGroupBlock>()) {
        final choiceKind = block.metadata['choice_kind']
            ?.toString()
            .trim()
            .toLowerCase();
        if (choiceKind == 'solo_topic_aspect') {
          final options = _soloAspectPanelOptions(block.options, state);
          final allowTextInput = _soloAspectAllowsCustomInput(state);
          if (options.isNotEmpty || allowTextInput) {
            return _GroupSetupChoice(
              prompt: '',
              options: options,
              allowTextInput: allowTextInput,
              inputHint: 'Type your own aspect',
              optionKeyPrefix: 'topic-aspect',
              inputKey: const ValueKey('topic-aspect-custom_aspect'),
            );
          }
        }
        if (choiceKind == 'solo_topic_path_actions') {
          final options = _orderedSoloTopicPathActions(block.options);
          if (options.isNotEmpty) {
            final allowTextInput =
                state['topic_aspect_status']?.toString().trim().toLowerCase() ==
                    'failed' &&
                _soloAspectAllowsCustomInput(state);
            return _GroupSetupChoice(
              prompt: '',
              options: options,
              allowTextInput: allowTextInput,
              inputHint: allowTextInput ? 'Type your own aspect' : 'Message',
              optionKeyPrefix: 'topic-path-action',
              inputKey: allowTextInput
                  ? const ValueKey('topic-aspect-custom_aspect')
                  : null,
            );
          }
        }
      }
    }

    final status = state['topic_aspect_status']
        ?.toString()
        .trim()
        .toLowerCase();
    if (status == 'failed') {
      return _GroupSetupChoice(
        prompt: '',
        options: _orderedSoloTopicPathActions(const [
          InteractiveOption(
            id: 'retry_aspects',
            label: 'Try suggestions again',
          ),
        ]),
        allowTextInput: _soloAspectAllowsCustomInput(state),
        inputHint: 'Type your own aspect',
        optionKeyPrefix: 'topic-path-action',
        inputKey: const ValueKey('topic-aspect-custom_aspect'),
      );
    }
    final options = _soloAspectPanelOptions(
      _interactiveOptionsFromRaw(state['pending_topic_aspects']),
      state,
    );
    final allowTextInput = _soloAspectAllowsCustomInput(state);
    if (options.isNotEmpty || allowTextInput) {
      return _GroupSetupChoice(
        prompt: '',
        options: options,
        allowTextInput: allowTextInput,
        inputHint: 'Type your own aspect',
        optionKeyPrefix: 'topic-aspect',
        inputKey: const ValueKey('topic-aspect-custom_aspect'),
      );
    }
  }

  if (turn != null) {
    final phase = state['phase']?.toString().trim().toLowerCase() ?? '';
    for (final block in turn.blocks.whereType<InteractiveChoiceGroupBlock>()) {
      final choiceKind = block.metadata['choice_kind']
          ?.toString()
          .trim()
          .toLowerCase();
      if (choiceKind == null || block.options.isEmpty) continue;
      if (choiceKind == 'solo_quiz_mode' && phase != 'mode_selection') {
        continue;
      }
      if (choiceKind == 'solo_quiz_timer' && phase != 'timer_selection') {
        continue;
      }
      if (!_isSoloFloatingChoiceKind(choiceKind)) continue;

      return _GroupSetupChoice(
        prompt: '',
        options: _soloPanelOptions(block.options, choiceKind),
        allowTextInput: false,
        inputHint: 'Message',
        optionKeyPrefix: _soloPanelOptionKeyPrefix(choiceKind),
      );
    }
  }

  if (state['phase'] == 'timer_selection') {
    return const _GroupSetupChoice(
      prompt: '',
      options: [
        InteractiveOption(id: 'timed', label: 'Timed'),
        InteractiveOption(id: 'untimed', label: 'Untimed'),
      ],
      allowTextInput: false,
      inputHint: 'Message',
      optionKeyPrefix: 'timer-suggestion',
    );
  }

  return null;
}

bool _isSoloFloatingChoiceKind(String choiceKind) {
  return const {'solo_quiz_mode', 'solo_quiz_timer'}.contains(choiceKind);
}

String? _soloPanelOptionKeyPrefix(String choiceKind) {
  return switch (choiceKind) {
    'solo_quiz_mode' => 'mode-suggestion',
    'solo_quiz_timer' => 'timer-suggestion',
    _ => null,
  };
}

bool _soloRootTopicPromptReady(Map<String, dynamic> state) {
  final status = state['topic_prompt_status']?.toString().trim().toLowerCase();
  final prompt = state['topic_prompt']?.toString().trim();
  if (status != null && status != 'ready') return false;
  if (prompt == null || prompt.isEmpty) return false;
  final normalizedPrompt = prompt.toLowerCase();
  if (normalizedPrompt == 'connecting...' ||
      normalizedPrompt == 'preparing room...') {
    return false;
  }
  return true;
}

List<InteractiveOption> _soloTopicPanelOptions(
  dynamic pendingOptions,
  dynamic topicSuggestions,
) {
  final pending = _interactiveOptionsFromRaw(pendingOptions);
  final options = pending.isNotEmpty
      ? pending
      : _interactiveOptionsFromRaw(topicSuggestions);
  final filtered = options
      .where((option) => option.id.trim().toLowerCase() != 'custom_topic')
      .toList(growable: false);
  if (pending.isNotEmpty ||
      filtered.any(
        (option) => option.id.trim().toLowerCase() == 'pick_for_me',
      )) {
    return filtered;
  }
  return [
    const InteractiveOption(id: 'pick_for_me', label: 'Pick for me'),
    ...filtered,
  ];
}

List<InteractiveOption> _interactiveOptionsFromRaw(dynamic raw) {
  return ((raw as List?) ?? const <dynamic>[])
      .whereType<Map>()
      .map((item) => InteractiveOption.fromJson(item.cast<String, dynamic>()))
      .where((option) => option.id.isNotEmpty || option.label.isNotEmpty)
      .toList(growable: false);
}

List<InteractiveOption> _soloAspectPanelOptions(
  List<InteractiveOption> options,
  Map<String, dynamic> state,
) {
  final filtered = options
      .where((option) => option.id.trim().toLowerCase() != 'custom_aspect')
      .toList(growable: false);
  final status = state['topic_aspect_status']?.toString().trim().toLowerCase();
  final shouldAddContinue =
      filtered.isNotEmpty &&
      status == 'ready' &&
      !filtered.any(
        (option) => option.id.trim().toLowerCase() == 'continue_with_topic',
      );
  return _orderedSoloTopicAspects([
    ...filtered,
    if (shouldAddContinue)
      const InteractiveOption(id: 'continue_with_topic', label: 'Continue'),
  ]);
}

bool _soloAspectAllowsCustomInput(Map<String, dynamic> state) {
  final allowCustomAspect = state['allow_custom_aspect'];
  final status = state['topic_aspect_status']?.toString().trim().toLowerCase();
  if (status == 'max_depth') return allowCustomAspect == true;
  return allowCustomAspect != false;
}

List<InteractiveOption> _orderedSoloTopicAspects(
  List<InteractiveOption> options,
) {
  final continueOptions = <InteractiveOption>[];
  final regularOptions = <InteractiveOption>[];
  for (final option in options) {
    if (option.id.trim().toLowerCase() == 'continue_with_topic') {
      continueOptions.add(option);
    } else {
      regularOptions.add(option);
    }
  }
  return [...regularOptions, ...continueOptions];
}

List<InteractiveOption> _orderedSoloTopicPathActions(
  List<InteractiveOption> options,
) {
  return _orderedOptions(options, const [
    'quiz',
    'chat',
    'change_aspect',
    'retry_aspects',
  ]);
}

List<InteractiveOption> _soloPanelOptions(
  List<InteractiveOption> options,
  String choiceKind,
) {
  if (choiceKind == 'solo_quiz_mode') {
    return _orderedOptions(options, const ['quiz', 'chat']);
  }
  if (choiceKind == 'solo_quiz_timer') {
    return _orderedOptions(options, const ['timed', 'untimed']);
  }
  return options;
}

List<InteractiveOption> _orderedOptions(
  List<InteractiveOption> options,
  List<String> order,
) {
  final byId = {for (final option in options) option.id: option};
  return [
    for (final id in order)
      if (byId[id] != null) byId[id]!,
    for (final option in options)
      if (!order.contains(option.id)) option,
  ];
}

bool _turnHasSoloChoiceKind(InteractiveTurn? turn, String choiceKind) {
  if (turn == null) return false;
  return turn.blocks.whereType<InteractiveChoiceGroupBlock>().any(
    (block) => block.metadata['choice_kind'] == choiceKind,
  );
}

bool _turnHasMatchingGuidedChoiceKind(
  InteractiveTurn? turn,
  String choiceKind,
  Map<String, dynamic> interactiveState,
) {
  if (turn == null) return false;
  return turn.blocks.whereType<InteractiveChoiceGroupBlock>().any((block) {
    if (block.metadata['choice_kind'] != choiceKind) return false;
    final stateRevision = interactiveState['topic_aspect_revision']
        ?.toString()
        .trim();
    final blockRevision = block.metadata['revision']?.toString().trim();
    if (stateRevision != blockRevision) return false;

    final stateDepth = (interactiveState['topic_drilldown_depth'] as num?)
        ?.toInt();
    final blockDepth = (block.metadata['depth'] as num?)?.toInt();
    if (stateDepth != blockDepth) return false;

    final statePath = _normalizedGuidedTopicPath(
      interactiveState['topic_path'],
    );
    final blockPath = _normalizedGuidedTopicPath(block.metadata['topic_path']);
    if (!_sameGuidedTopicPath(statePath, blockPath)) return false;

    final stateActionsExpanded =
        interactiveState['topic_path_actions_expanded'] == true;
    final blockActionsExpanded =
        block.metadata['topic_path_actions_expanded'] == true;
    if (stateActionsExpanded != blockActionsExpanded) {
      return false;
    }
    return true;
  });
}

List<String> _normalizedGuidedTopicPath(dynamic raw) {
  return ((raw as List?) ?? const <dynamic>[])
      .map((part) => part.toString().trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

bool _sameGuidedTopicPath(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
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
  return _canCurrentUserHostGroupQuiz(session, currentUserId);
}

bool _canCurrentUserHostGroupQuiz(
  InteractiveSessionState session,
  String? currentUserId,
) {
  if (session.interactiveState['session_type'] != 'group') return false;

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

bool _isGroupQuizManualAdvancePhase(InteractiveSessionState session) {
  final state = session.interactiveState;
  if (state['session_type'] != 'group') return false;
  if (state['template'] != 'quiz') return false;
  final phase = state['phase'] as String? ?? '';
  if (session.isCompleted) return false;
  if (phase == 'question_active') {
    return state['quiz_timer_enabled'] != true;
  }
  if (phase != 'showing_results') return false;
  final currentRound = (state['current_round'] as num?)?.toInt();
  final totalRounds = (state['total_rounds'] as num?)?.toInt() ?? 1;
  if (currentRound == null) return false;
  return currentRound < totalRounds;
}

bool _isGroupQuizCompleted(InteractiveSessionState session) {
  if (session.interactiveState['session_type'] != 'group') return false;
  if (session.interactiveState['template'] != 'quiz') return false;
  final phase = session.interactiveState['phase'] as String? ?? '';
  if (phase == 'completed' || session.isCompleted) return true;
  if (phase != 'showing_results') return false;
  final currentRound = (session.interactiveState['current_round'] as num?)
      ?.toInt();
  final totalRounds =
      (session.interactiveState['total_rounds'] as num?)?.toInt() ?? 1;
  return currentRound != null && currentRound >= totalRounds;
}

class _GroupSetupChoice {
  const _GroupSetupChoice({
    required this.prompt,
    required this.options,
    required this.allowTextInput,
    required this.inputHint,
    this.optionKeyPrefix,
    this.inputKey,
  });

  final String prompt;
  final List<InteractiveOption> options;
  final bool allowTextInput;
  final String inputHint;
  final String? optionKeyPrefix;
  final Key? inputKey;
}

String _groupHostAdvancePanelTitle(InteractiveSessionState session) {
  final state = session.interactiveState;
  if (state['phase'] == 'question_active' &&
      state['quiz_timer_enabled'] != true) {
    return 'Reveal the answer';
  }
  final currentRound = (state['current_round'] as num?)?.toInt();
  final totalRounds = (state['total_rounds'] as num?)?.toInt() ?? 1;
  if (currentRound != null && currentRound >= totalRounds) {
    return 'Ready for final results';
  }
  return 'Ready for next question';
}

String _groupHostAdvancePanelBody(InteractiveSessionState session) {
  final state = session.interactiveState;
  if (state['phase'] == 'question_active' &&
      state['quiz_timer_enabled'] != true) {
    return 'This round is untimed. Tap when everyone is done answering.';
  }
  final currentRound = (state['current_round'] as num?)?.toInt();
  final totalRounds = (state['total_rounds'] as num?)?.toInt() ?? 1;
  if (currentRound != null && currentRound >= totalRounds) {
    return 'Players can keep chatting, or you can show the final results when everyone is ready.';
  }
  return 'Players can keep chatting, or you can continue when everyone is ready.';
}

String _groupHostAdvancePanelActionLabel(InteractiveSessionState session) {
  final state = session.interactiveState;
  if (state['phase'] == 'question_active' &&
      state['quiz_timer_enabled'] != true) {
    return 'Time up';
  }
  final currentRound = (state['current_round'] as num?)?.toInt();
  final totalRounds = (state['total_rounds'] as num?)?.toInt() ?? 1;
  if (currentRound != null && currentRound >= totalRounds) {
    return 'Show final results';
  }
  return 'Next question';
}

class _StorySessionLoadingShell extends StatelessWidget {
  const _StorySessionLoadingShell({this.title = 'Preparing room...'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(child: _SessionStatusLoadingCard(title: title));
  }
}

class _SessionLoadingBubble extends StatefulWidget {
  const _SessionLoadingBubble({required this.title});

  final String title;

  @override
  State<_SessionLoadingBubble> createState() => _SessionLoadingBubbleState();
}

class _SessionLoadingBubbleState extends State<_SessionLoadingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _labels {
    final normalized = widget.title.toLowerCase();
    if (normalized.contains('checking')) {
      return const ['Checking sessions...', 'Connecting...'];
    }
    if (normalized.contains('searching')) {
      return const ['Searching rooms...', 'Connecting...'];
    }
    return const ['Connecting...', 'Fetching intro...', 'Waiting for Aura...'];
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.78, 420),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xED101112),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return _SessionStatusLabel(
                      labels: _labels,
                      progress: _controller.value,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionStatusLoadingCard extends StatefulWidget {
  const _SessionStatusLoadingCard({required this.title});

  final String title;

  @override
  State<_SessionStatusLoadingCard> createState() =>
      _SessionStatusLoadingCardState();
}

class _SessionStatusLoadingCardState extends State<_SessionStatusLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _labels {
    final normalized = widget.title.toLowerCase();
    if (normalized.contains('checking')) {
      return const ['Checking sessions...', 'Preparing room...'];
    }
    if (normalized.contains('loading')) {
      return const ['Preparing room...', 'Connecting...'];
    }
    return [widget.title];
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final cardSize = shortestSide.clamp(168.0, 230.0);
    return SizedBox.square(
      dimension: cardSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xED101112),
          borderRadius: BorderRadius.circular(cardSize * 0.18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return _SessionStatusProgress(
              labels: _labels,
              progress: _controller.value,
            );
          },
        ),
      ),
    );
  }
}

class _SessionStatusProgress extends StatelessWidget {
  const _SessionStatusProgress({required this.labels, required this.progress});

  final List<String> labels;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final displayProgress = _displayProgress(progress);
    final percentage = (displayProgress * 100).round().clamp(0, 99);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final ringSize = size * 0.74;
        final stroke = (ringSize * 0.07).clamp(8.0, 14.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: ringSize,
              child: CustomPaint(
                key: const ValueKey('room-preparation-progress-ring'),
                painter: _RoomPreparationRingPainter(
                  progress: displayProgress,
                  strokeWidth: stroke,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  key: const ValueKey('room-preparation-progress-percent'),
                  textScaler: MediaQuery.textScalerOf(context),
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: percentage.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (size * 0.15).clamp(28.0, 42.0),
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: '%',
                        style: TextStyle(
                          color: const Color(0xFF22C55E),
                          fontSize: (size * 0.13).clamp(24.0, 38.0),
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SessionStatusLabel(labels: labels, progress: progress),
              ],
            ),
          ],
        );
      },
    );
  }

  double _displayProgress(double raw) {
    final eased = Curves.easeInOutCubic.transform(raw);
    return (0.08 + (eased * 0.84)).clamp(0.0, 0.96);
  }
}

class _RoomPreparationRingPainter extends CustomPainter {
  const _RoomPreparationRingPainter({
    required this.progress,
    required this.strokeWidth,
  });

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = strokeWidth / 2;
    final arcRect = rect.deflate(inset);
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawArc(arcRect, -math.pi * 0.92, math.pi * 1.84, false, trackPaint);
    canvas.drawArc(
      arcRect,
      -math.pi * 0.92,
      math.pi * 1.84 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPreparationRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _SessionStatusLabel extends StatelessWidget {
  const _SessionStatusLabel({required this.labels, required this.progress});

  final List<String> labels;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final labelCount = labels.length;
    final rawPosition = progress * labelCount;
    final labelIndex = rawPosition.floor().clamp(0, labelCount - 1);
    final localProgress = rawPosition - labelIndex;
    final opacity = progress >= 0.995
        ? 1.0
        : math
              .min(
                Curves.easeOutCubic.transform(
                  (localProgress / 0.18).clamp(0.0, 1.0),
                ),
                Curves.easeInCubic.transform(
                  ((1.0 - localProgress) / 0.2).clamp(0.0, 1.0),
                ),
              )
              .clamp(0.0, 1.0);
    const style = TextStyle(
      color: Colors.white70,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    return SizedBox(
      height: 18,
      child: Opacity(
        opacity: opacity,
        child: Text(
          labels[labelIndex],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: style,
        ),
      ),
    );
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
  const _ParsedStoryOptions({
    required this.displayText,
    required this.options,
    this.panelTitle,
  });

  final String displayText;
  final List<_ParsedStoryOption> options;
  final String? panelTitle;
}

const _storyPerspectiveOptions = <_ParsedStoryOption>[
  _ParsedStoryOption(title: 'First person'),
  _ParsedStoryOption(title: 'Third-person close'),
  _ParsedStoryOption(title: 'Omniscient narrator'),
];

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

bool _isRegenerateStoryOptionsPrompt(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.startsWith('give me three different story options for ') &&
      normalized.contains('do not reuse generic options') &&
      normalized.contains('use numbered options');
}

bool _isNarrationPrompt(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.startsWith('read the following story chapter aloud') &&
      normalized.contains('do not add commentary') &&
      normalized.contains('extra words');
}

String _friendlyStoryUserBubbleText(String value) {
  if (_isRegenerateStoryOptionsPrompt(value)) {
    return 'Try different stories';
  }
  return _cleanStoryBubbleText(value);
}

class _StoryOptionsInputPanel extends StatelessWidget {
  const _StoryOptionsInputPanel({
    required this.options,
    required this.onSelected,
    required this.onRegenerate,
    required this.onToggleCollapsed,
    this.title = 'What kind of story sounds good?',
    this.onNext,
    this.onPickForMe,
    this.selectedTitle,
    this.disabled = false,
    this.collapsed = false,
  });

  final List<_ParsedStoryOption> options;
  final ValueChanged<_ParsedStoryOption> onSelected;
  final VoidCallback onRegenerate;
  final VoidCallback onToggleCollapsed;
  final String title;
  final VoidCallback? onNext;
  final VoidCallback? onPickForMe;
  final String? selectedTitle;
  final bool disabled;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: collapsed ? 8 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (collapsed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  Transform.translate(
                    offset: collapsed ? Offset.zero : const Offset(0, 4),
                    child: SizedBox.square(
                      dimension: 28,
                      child: IconButton(
                        tooltip: collapsed ? 'Show options' : 'Hide options',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: disabled ? null : onToggleCollapsed,
                        icon: Icon(
                          collapsed
                              ? CupertinoIcons.chevron_up
                              : CupertinoIcons.chevron_down,
                          size: 20,
                          color: disabled ? Colors.white30 : Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!collapsed) ...[
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              if (options.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return _StoryOptionSheetRow(
                        index: index,
                        option: option,
                        selected: option.title == selectedTitle,
                        disabled: disabled,
                        onSelected: onSelected,
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.13)),
              if (onPickForMe != null) ...[
                _StoryActionOptionRow(
                  label: 'Pick for me',
                  disabled: disabled,
                  icon: CupertinoIcons.shuffle,
                  onPressed: onPickForMe!,
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.13)),
              ],
              _StoryActionOptionRow(
                label: 'Try different stories',
                disabled: disabled,
                icon: CupertinoIcons.arrow_clockwise,
                onPressed: onRegenerate,
              ),
              if (onNext != null) ...[
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.13)),
                _StoryActionOptionRow(
                  label: 'Next',
                  disabled: disabled,
                  icon: CupertinoIcons.chevron_right,
                  onPressed: onNext!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StoryOptionSheetRow extends StatelessWidget {
  const _StoryOptionSheetRow({
    required this.index,
    required this.option,
    required this.selected,
    required this.disabled,
    required this.onSelected,
  });

  final int index;
  final _ParsedStoryOption option;
  final ValueChanged<_ParsedStoryOption> onSelected;
  final bool selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.selectionClick();
                onSelected(option);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.34)
                      : Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: disabled ? Colors.white38 : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  option.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled ? Colors.white38 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
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

class _StoryActionOptionRow extends StatelessWidget {
  const _StoryActionOptionRow({
    super.key,
    required this.label,
    required this.disabled,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final bool disabled;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 32,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 16,
                      color: disabled ? Colors.white38 : Colors.white70,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled ? Colors.white38 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
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

class _StoryTextChatTabState extends ConsumerState<_StoryTextChatTab> {
  final _textController = TextEditingController();
  final _listScrollController = ScrollController();
  final _composerKey = GlobalKey();
  final List<ChatMessageModel> _messages = <ChatMessageModel>[];
  bool _canSend = false;
  int _lastMessageCount = 0;
  double _composerHeight = 0;
  Timer? _panelScrollTimer;
  String? _confirmedStoryOptionTitle;
  StorySession? _textSession;
  bool _isStartingTextSession = true;
  bool _isSendingText = false;
  bool _isSubmittingStoryOption = false;
  bool _isNarrationStarting = false;
  bool _isNarrationPaused = false;
  bool _narrationControlInFlight = false;
  String? _narratingMessageId;
  ChatMessageModel? _narrationMessage;
  OverlayEntry? _narrationOverlayEntry;
  VoiceChatController? _voiceController;
  bool _narrationOverlayNeedsReinsert = true;
  String? _textSessionError;
  List<_ParsedStoryOption>? _reopenedStoryOptions;
  _ParsedStoryOption? _pendingPerspectiveStoryOption;
  bool _lastHadComposerOptions = false;
  bool _isComposerPanelCollapsed = false;
  String? _dismissedStoryOptionsKey;
  bool _dismissedContinuationActions = false;
  final Map<String, String> _retryTextByMessageId = <String, String>{};
  final Map<String, String> _retryVisibleTextByMessageId = <String, String>{};
  final Map<String, String> _loadingLabelByMessageId = <String, String>{};

  @override
  void initState() {
    super.initState();
    _voiceController = ref.read(voiceChatControllerProvider.notifier);
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
  void reassemble() {
    super.reassemble();
    _narrationOverlayNeedsReinsert = true;
    _narrationOverlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _panelScrollTimer?.cancel();
    _removeNarrationOverlay();
    _voiceController?.clearNarrationCache();
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

  bool _isNarrationVoiceActive(VoiceChatState voiceState) {
    return voiceState.isPlaying ||
        voiceState.isProcessing ||
        voiceState.isConnecting ||
        voiceState.phase == RealtimeVoicePhase.playing ||
        voiceState.phase == RealtimeVoicePhase.paused ||
        voiceState.phase == RealtimeVoicePhase.processing ||
        voiceState.phase == RealtimeVoicePhase.connecting ||
        voiceState.phase == RealtimeVoicePhase.waitingForReady;
  }

  void _clearNarrationUiState() {
    if (_narratingMessageId == null &&
        _narrationMessage == null &&
        !_isNarrationStarting &&
        !_isNarrationPaused) {
      return;
    }
    setState(() {
      _narratingMessageId = null;
      _narrationMessage = null;
      _isNarrationStarting = false;
      _isNarrationPaused = false;
      _narrationControlInFlight = false;
    });
    _removeNarrationOverlay();
  }

  Future<bool> _startTextStorySession() async {
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
      if (!mounted) return false;
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
      _preloadLatestGeneratedChapterNarration();
      _scrollToBottom(jump: true, retries: 4);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _isStartingTextSession = false;
        _textSessionError = e.toString();
      });
      showToast(context, 'Story connection error');
      return false;
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
      _preloadLatestGeneratedChapterNarration();
      _scrollToBottom(jump: true, retries: 4);
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
      if (speaker == 'user' && _isNarrationPrompt(rawText)) continue;
      final text = speaker == 'user'
          ? _friendlyStoryUserBubbleText(rawText)
          : rawText;
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
      final connected = await _startTextStorySession();
      if (!connected || _textSession == null) return;
    }

    _textController.clear();
    unawaited(_sendTextStoryTurn(text));
  }

  Future<void> _sendTextStoryTurn(String text, {String? visibleText}) async {
    final userMessage = ChatMessageModel(
      id: 'story_text_user_${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      message: visibleText ?? _friendlyStoryUserBubbleText(text),
      ts: DateTime.now(),
    );
    final assistantMessageId =
        'story_text_ai_stream_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _isSendingText = true;
      _textSessionError = null;
      _reopenedStoryOptions = null;
      _pendingPerspectiveStoryOption = null;
      _isComposerPanelCollapsed = false;
      _dismissedStoryOptionsKey = null;
      _dismissedContinuationActions = false;
      _retryTextByMessageId[userMessage.id] = text;
      _retryVisibleTextByMessageId[userMessage.id] = userMessage.message;
      _loadingLabelByMessageId[assistantMessageId] = 'Thinking…';
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
        if (event.isStatus) {
          final label = _storyStreamStatusLabel(event.status);
          if (label == null) continue;
          setState(() {
            _loadingLabelByMessageId[assistantMessageId] = label;
          });
        } else if (event.isReady) {
          setState(() {
            _loadingLabelByMessageId[assistantMessageId] = 'Processing…';
          });
        } else if (event.isToken) {
          final token = event.content ?? '';
          if (token.isEmpty) continue;
          setState(() {
            _loadingLabelByMessageId[assistantMessageId] = 'Generating…';
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
            _loadingLabelByMessageId.remove(assistantMessageId);
            _isSendingText = false;
          });
          final sessionId = event.session?.id ?? _textSession?.id ?? '';
          if (sessionId.isNotEmpty) {
            widget.onSessionReady(sessionId);
          }
          final completedIndex = _messages.indexWhere(
            (message) => message.id == assistantMessageId,
          );
          if (completedIndex != -1) {
            unawaited(
              _preloadGeneratedChapterNarration(_messages[completedIndex]),
            );
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
        _loadingLabelByMessageId.remove(assistantMessageId);
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
        _loadingLabelByMessageId.remove(assistantMessageId);
      });
      showToast(context, 'Story connection error');
    }
  }

  String? _storyStreamStatusLabel(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'thinking':
      case 'accepted':
        return 'Thinking…';
      case 'processing':
        return 'Processing…';
      case 'generating':
        return 'Generating…';
      default:
        return null;
    }
  }

  Future<void> _retryFailedStoryTurn(ChatMessageModel message) async {
    if (!message.isUser || !message.isFailed) return;
    if (_isSendingText || _isSubmittingStoryOption || _isStartingTextSession) {
      showToast(context, 'Aura is reconnecting...', variant: ToastVariant.info);
      return;
    }

    final retryText = _retryTextByMessageId[message.id] ?? message.message;
    final retryVisibleText =
        _retryVisibleTextByMessageId[message.id] ?? message.message;
    final reconnected = await _startTextStorySession();
    if (!mounted || !reconnected || _textSession == null) return;

    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
      _retryTextByMessageId.remove(message.id);
      _retryVisibleTextByMessageId.remove(message.id);
    });
    await _sendTextStoryTurn(retryText, visibleText: retryVisibleText);
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
      _pendingPerspectiveStoryOption = option;
      _reopenedStoryOptions = null;
      _isComposerPanelCollapsed = false;
      _dismissedStoryOptionsKey = null;
      _dismissedContinuationActions = false;
    });
    _scrollToBottomAfterPanelAnimation();
  }

  Future<void> _pickStoryOptionForUser(List<_ParsedStoryOption> options) async {
    if (options.isEmpty || _isSubmittingStoryOption) return;
    final unselected = options
        .where((option) => option.title != _confirmedStoryOptionTitle)
        .toList(growable: false);
    final candidates = unselected.isEmpty ? options : unselected;
    final choice = candidates[math.Random().nextInt(candidates.length)];
    await _confirmStoryOption(choice);
  }

  Future<void> _confirmStoryPerspective(_ParsedStoryOption perspective) async {
    if (_isSubmittingStoryOption) return;
    final storyOption = _pendingPerspectiveStoryOption;
    if (storyOption == null) return;

    if (_isStartingTextSession) {
      showToast(context, 'Connecting...', variant: ToastVariant.info);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmittingStoryOption = true;
      _pendingPerspectiveStoryOption = null;
      _isComposerPanelCollapsed = false;
      _dismissedStoryOptionsKey = null;
      _dismissedContinuationActions = false;
    });
    try {
      await _sendTextStoryTurn(
        'I choose ${storyOption.title}. ${_storyPerspectiveInstruction(perspective.title)}',
        visibleText:
            'Narrate "${storyOption.title}" in ${_storyPerspectiveDisplayName(perspective.title)} perspective',
      );
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
      _pendingPerspectiveStoryOption = null;
      _isSubmittingStoryOption = true;
      _reopenedStoryOptions = null;
      _isComposerPanelCollapsed = false;
      _dismissedStoryOptionsKey = null;
      _dismissedContinuationActions = false;
    });
    try {
      await _sendTextStoryTurn(
        'Give me three different story options for ${widget.storyTitle}. Make every option specific to this story room, using its title, premise, characters, themes, tone, or setting. Do not reuse generic options from another story. Use numbered options with a title and one short teaser in the same line. Do not use quotation marks or subtitles.',
        visibleText: 'Try different stories',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingStoryOption = false);
      }
    }
  }

  Future<void> _requestNextStoryParagraph() async {
    if (_isSubmittingStoryOption || _isSendingText) return;

    if (_isStartingTextSession) {
      showToast(context, 'Connecting...', variant: ToastVariant.info);
      return;
    }

    await _sendTextStoryTurn('Continue.', visibleText: 'Next');
  }

  Future<void> _sendSuggestedStoryAnswer(_ParsedStoryOption option) async {
    if (_isSubmittingStoryOption || _isSendingText) return;

    if (_isStartingTextSession) {
      showToast(context, 'Connecting...', variant: ToastVariant.info);
      return;
    }

    await _sendTextStoryTurn(option.title);
  }

  void _restorePreviousStoryOptions() {
    if (_pendingPerspectiveStoryOption != null) {
      setState(() {
        _pendingPerspectiveStoryOption = null;
        _confirmedStoryOptionTitle = null;
      });
      return;
    }

    for (final message in _messages.reversed) {
      final parsedOptions = _parseStoryOptions(message);
      if (parsedOptions != null && parsedOptions.options.isNotEmpty) {
        setState(() {
          _confirmedStoryOptionTitle = null;
          _reopenedStoryOptions = parsedOptions.options;
          _isComposerPanelCollapsed = false;
          _dismissedStoryOptionsKey = null;
          _dismissedContinuationActions = false;
        });
        _scrollToBottom();
        return;
      }
    }

    unawaited(_regenerateStoryOptions());
  }

  void _toggleComposerPanelCollapsed() {
    setState(() {
      _isComposerPanelCollapsed = !_isComposerPanelCollapsed;
    });
    _scrollToBottomAfterPanelAnimation();
  }

  String _storyPerspectiveInstruction(String perspectiveTitle) {
    switch (perspectiveTitle) {
      case 'First person':
        return 'Tell it in first person from the main character\'s position, using I and me.';
      case 'Third-person close':
        return 'Tell it in third-person close, staying near the main character\'s thoughts and position.';
      case 'Omniscient narrator':
        return 'Tell it with an omniscient narrator who can understand every important character\'s position.';
      default:
        return 'Tell it from the $perspectiveTitle perspective.';
    }
  }

  String _storyPerspectiveDisplayName(String perspectiveTitle) {
    switch (perspectiveTitle) {
      case 'First person':
        return 'first person';
      case 'Third-person close':
        return 'third-person close';
      case 'Omniscient narrator':
        return 'omniscient narrator';
      default:
        return perspectiveTitle.toLowerCase();
    }
  }

  bool _shouldShowStoryContinuationActions({
    required ChatMessageModel message,
    required int index,
    required int visibleMessageCount,
    required _ParsedStoryOptions? parsedOptions,
  }) {
    if (message.isUser || message.isStreaming) return false;
    if (parsedOptions != null) return false;
    if (message.message.trim().isEmpty) return false;
    return index == visibleMessageCount - 1;
  }

  String? _trailingAssistantQuestion(ChatMessageModel message) {
    if (message.role != ChatRole.assistant || message.isStreaming) return null;
    final text = _cleanStoryBubbleText(message.message);
    final match = RegExp(
      r'(?:^|[.!?]\s+)([^.!?]*\?)\s*$',
      dotAll: true,
    ).firstMatch(text);
    final question = match?.group(1)?.trim();
    if (question == null || question.length < 8) return null;
    return question;
  }

  String? _composerContinuationQuestion(
    List<ChatMessageModel> visibleMessages,
  ) {
    if (visibleMessages.isEmpty) return null;
    return _trailingAssistantQuestion(visibleMessages.last);
  }

  List<_ParsedStoryOption> _suggestedAnswersForQuestion(String? question) {
    final lower = (question ?? '').toLowerCase();
    if (lower.isEmpty) return const <_ParsedStoryOption>[];

    if (lower.contains('insight') || lower.contains('draw from')) {
      return const [
        _ParsedStoryOption(
          title: 'She might realize calm is something she can return to.',
        ),
        _ParsedStoryOption(
          title: 'She could see that worry is only one part of her.',
        ),
      ];
    }

    if (lower.startsWith('how might') || lower.startsWith('how could')) {
      return const [
        _ParsedStoryOption(title: 'It could help them see the choice clearly.'),
        _ParsedStoryOption(title: 'It might reveal what matters most to them.'),
      ];
    }

    if (lower.contains('feel')) {
      return const [
        _ParsedStoryOption(title: 'She might feel a little more grounded.'),
        _ParsedStoryOption(title: 'She could feel nervous, but less alone.'),
      ];
    }

    return const [
      _ParsedStoryOption(title: 'She can pause and listen to what feels true.'),
      _ParsedStoryOption(title: 'She might take one small honest step.'),
    ];
  }

  ChatMessageModel _messageWithoutTrailingQuestion(ChatMessageModel message) {
    final question = _trailingAssistantQuestion(message);
    if (question == null) return message;
    final index = message.message.lastIndexOf(question);
    if (index <= 0) return message;
    final text = message.message.substring(0, index).trimRight();
    if (text.isEmpty) return message;
    return message.copyWith(message: text);
  }

  void _scrollToBottom({bool jump = false, int retries = 2}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_listScrollController.hasClients) {
        if (retries > 0) {
          _scrollToBottom(jump: jump, retries: retries - 1);
        }
        return;
      }
      final bottom = _listScrollController.position.maxScrollExtent;
      if (jump) {
        _listScrollController.jumpTo(bottom);
      } else {
        _listScrollController.animateTo(
          bottom,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomAfterPanelAnimation() {
    _scrollToBottom();
    _panelScrollTimer?.cancel();
    _panelScrollTimer = Timer(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  void _scrollChatFromComposerDrag(DragUpdateDetails details) {
    if (!_listScrollController.hasClients) return;
    final delta = details.primaryDelta ?? details.delta.dy;
    if (delta == 0) return;

    final position = _listScrollController.position;
    final target = (position.pixels - delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    _listScrollController.jumpTo(target);
  }

  void _syncComposerHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = _composerKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final height = renderObject.size.height;
      if (height <= 0 || (height - _composerHeight).abs() < 0.5) return;
      setState(() => _composerHeight = height);
      _scrollToBottom();
    });
  }

  List<ChatMessageModel> _buildMessages() {
    return _messages
        .where((message) => !_isNarrationPrompt(message.message))
        .toList(growable: false);
  }

  _ParsedStoryOptions? _parseStoryOptions(ChatMessageModel message) {
    if (message.role != ChatRole.assistant) return null;

    final isConfiguredStoryMenu =
        widget.enableStoryOptions ||
        _isBeneathTheSurfaceTitle(widget.storyTitle);
    final lowerMessage = message.message.toLowerCase();
    final lines = message.message.split('\n');
    final parsedLineOptions = <_ParsedStoryOption>[];
    for (final line in lines) {
      final option = _parseStoryOptionLine(line);
      if (option != null) parsedLineOptions.add(option);
    }
    final looksLikeStoryOptionMenu =
        lowerMessage.contains('story options') ||
        lowerMessage.contains('stories to explore') ||
        lowerMessage.contains('stories to choose') ||
        lowerMessage.contains('three meaningful stories') ||
        lowerMessage.contains('three unique stories') ||
        lowerMessage.contains('one of three') ||
        lowerMessage.contains('have three') ||
        lowerMessage.contains('choose a story') ||
        lowerMessage.contains('select a story') ||
        lowerMessage.contains('which story') ||
        lowerMessage.contains('resonates with you') ||
        (isConfiguredStoryMenu && lowerMessage.contains('choose'));
    final hasNumberedStoryOptions =
        isConfiguredStoryMenu && parsedLineOptions.length >= 2;
    if (!looksLikeStoryOptionMenu && !hasNumberedStoryOptions) return null;

    final displayLines = <String>[];
    final options = <_ParsedStoryOption>[];
    final seenOptionTitles = <String>{};

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
      final normalizedTitle = option.title.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (seenOptionTitles.add(normalizedTitle)) {
        options.add(option);
      }
    }

    if (options.length < 2) return null;
    if (message.isStreaming && options.length < 3) return null;
    final panelTitle = displayLines.reversed
        .map((line) => _cleanStoryBubbleText(line))
        .firstWhere((line) => line.endsWith('?'), orElse: () => '')
        .trim();
    final displayText = displayLines
        .where((line) => _cleanStoryBubbleText(line) != panelTitle)
        .join('\n')
        .trim();
    return _ParsedStoryOptions(
      displayText: displayText,
      options: options,
      panelTitle: panelTitle.isEmpty ? null : panelTitle,
    );
  }

  _ParsedStoryOptions? _composerStoryOptionMenu(
    List<ChatMessageModel> visibleMessages,
  ) {
    if (visibleMessages.isEmpty) return null;
    final latestMessage = visibleMessages.last;
    if (latestMessage.isUser) return null;
    final parsedOptions = _parseStoryOptions(latestMessage);
    final options = parsedOptions?.options ?? _reopenedStoryOptions;
    if (options == null || options.isEmpty) return null;
    if (_storyOptionsKey(options) == _dismissedStoryOptionsKey) return null;
    return _ParsedStoryOptions(
      displayText: parsedOptions?.displayText ?? '',
      options: options,
      panelTitle: parsedOptions?.panelTitle,
    );
  }

  bool _showComposerContinuationActions(
    List<ChatMessageModel> visibleMessages,
  ) {
    if (_dismissedContinuationActions) return false;
    if (visibleMessages.isEmpty) return false;
    final latestMessage = visibleMessages.last;
    final parsedOptions = _parseStoryOptions(latestMessage);
    return _shouldShowStoryContinuationActions(
      message: latestMessage,
      index: visibleMessages.length - 1,
      visibleMessageCount: visibleMessages.length,
      parsedOptions: parsedOptions,
    );
  }

  bool _shouldShowGeneratedChapterPlayIcon(ChatMessageModel message) {
    if (message.isUser || message.isStreaming || message.isPending) {
      return false;
    }
    if (message.isFailed || message.id == 'story_text_connecting') {
      return false;
    }
    return message.message.trim().isNotEmpty;
  }

  Future<void> _playGeneratedChapterNarration(
    ChatMessageModel message,
    ChatBubblePlayState playState,
  ) async {
    final isSwitchingNarration =
        _narratingMessageId != null && _narratingMessageId != message.id;
    if (_narrationControlInFlight && !isSwitchingNarration) return;
    if (playState == ChatBubblePlayState.pause) {
      await _pauseGeneratedChapterNarration();
      return;
    }
    if (playState == ChatBubblePlayState.loading) return;

    final text = message.message;
    final chapterText = _cleanStoryBubbleText(text);
    if (chapterText.isEmpty) return;

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    try {
      _narrationControlInFlight = true;
      setState(() {
        _narratingMessageId = message.id;
        _narrationMessage = message;
        _isNarrationStarting = true;
        _isNarrationPaused = false;
      });
      await voiceController.playTextNarration(
        _narrationPrompt(chapterText),
        storySessionId: _textSession?.id,
      );
      if (!mounted) return;
      setState(() => _isNarrationStarting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _narratingMessageId = null;
        _narrationMessage = null;
        _isNarrationStarting = false;
        _isNarrationPaused = false;
      });
      showToast(
        context,
        'Unable to play narration right now.',
        variant: ToastVariant.error,
      );
    } finally {
      _narrationControlInFlight = false;
    }
  }

  Future<void> _preloadGeneratedChapterNarration(
    ChatMessageModel message,
  ) async {
    if (!_shouldShowGeneratedChapterPlayIcon(message)) return;
    final chapterText = _cleanStoryBubbleText(message.message);
    if (chapterText.isEmpty) return;

    await ref
        .read(voiceChatControllerProvider.notifier)
        .preloadTextNarration(
          _narrationPrompt(chapterText),
          storySessionId: _textSession?.id,
        );
  }

  void _preloadLatestGeneratedChapterNarration() {
    for (final message in _messages.reversed) {
      if (_shouldShowGeneratedChapterPlayIcon(message)) {
        unawaited(_preloadGeneratedChapterNarration(message));
        return;
      }
    }
  }

  Future<void> _pauseGeneratedChapterNarration() async {
    if (_narrationControlInFlight) return;
    _narrationControlInFlight = true;
    if (mounted) {
      setState(() {
        _isNarrationStarting = false;
        _isNarrationPaused = true;
      });
    }
    final controller = ref.read(voiceChatControllerProvider.notifier);
    try {
      await controller.pausePlayback();
      if (!mounted) return;
      final voiceState = ref.read(voiceChatControllerProvider);
      setState(() {
        _isNarrationStarting = false;
        _isNarrationPaused = voiceState.phase == RealtimeVoicePhase.paused;
        if (!_isNarrationPaused && !voiceState.isPlaying) {
          _narratingMessageId = null;
          _narrationMessage = null;
        }
      });
    } finally {
      _narrationControlInFlight = false;
    }
  }

  Future<void> _stopGeneratedChapterNarration({bool keepPaused = false}) async {
    await ref.read(voiceChatControllerProvider.notifier).stopPlayback();
    if (!mounted) return;
    setState(() {
      if (!keepPaused) {
        _narratingMessageId = null;
        _narrationMessage = null;
      }
      _isNarrationStarting = false;
      _isNarrationPaused = keepPaused;
    });
  }

  Future<void> _toggleGeneratedChapterNarration() async {
    if (_isNarrationStarting || _narrationControlInFlight) return;
    final message = _narrationMessage;
    if (message == null) return;

    final voiceState = ref.read(voiceChatControllerProvider);
    final isPlaying =
        voiceState.isPlaying || voiceState.phase == RealtimeVoicePhase.playing;
    if (isPlaying) {
      await _pauseGeneratedChapterNarration();
      return;
    }
    if (_isNarrationPaused || voiceState.phase == RealtimeVoicePhase.paused) {
      final controller = ref.read(voiceChatControllerProvider.notifier);
      try {
        _narrationControlInFlight = true;
        setState(() {
          _isNarrationStarting = false;
          _isNarrationPaused = false;
        });
        await controller.resumePlayback();
        if (!mounted) return;
        final resumedState = ref.read(voiceChatControllerProvider);
        setState(() {
          _isNarrationStarting = false;
          _isNarrationPaused = resumedState.phase == RealtimeVoicePhase.paused;
        });
      } finally {
        _narrationControlInFlight = false;
      }
      return;
    }

    await _playGeneratedChapterNarration(message, ChatBubblePlayState.play);
  }

  Future<void> _handleGeneratedChapterPlayTap(ChatMessageModel message) async {
    if (_narrationControlInFlight) return;

    final isCurrentChapter = _narratingMessageId == message.id;
    final voiceState = ref.read(voiceChatControllerProvider);
    final isPlaying =
        voiceState.isPlaying || voiceState.phase == RealtimeVoicePhase.playing;
    final isPaused =
        _isNarrationPaused || voiceState.phase == RealtimeVoicePhase.paused;
    final isLoading =
        _isNarrationStarting ||
        voiceState.isConnecting ||
        voiceState.isProcessing ||
        voiceState.phase == RealtimeVoicePhase.connecting ||
        voiceState.phase == RealtimeVoicePhase.waitingForReady ||
        voiceState.phase == RealtimeVoicePhase.processing;

    if (isCurrentChapter && isPlaying) {
      await _pauseGeneratedChapterNarration();
      return;
    }
    if (isCurrentChapter && isPaused) {
      await _toggleGeneratedChapterNarration();
      return;
    }
    if (isCurrentChapter && isLoading) return;

    await _playGeneratedChapterNarration(message, ChatBubblePlayState.play);
  }

  void _syncNarrationOverlay(bool active) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!active) {
        _removeNarrationOverlay();
        return;
      }

      if (_narrationOverlayEntry != null && _narrationOverlayNeedsReinsert) {
        _removeNarrationOverlay();
      }

      if (_narrationOverlayEntry == null) {
        final overlay = Overlay.maybeOf(context, rootOverlay: true);
        if (overlay == null) return;
        _narrationOverlayNeedsReinsert = false;
        _narrationOverlayEntry = OverlayEntry(builder: _buildNarrationOverlay);
        overlay.insert(_narrationOverlayEntry!);
      } else {
        _narrationOverlayEntry?.markNeedsBuild();
      }
    });
  }

  Widget _buildNarrationOverlay(BuildContext overlayContext) {
    return Consumer(
      builder: (context, ref, _) {
        if (!mounted || _narratingMessageId == null) {
          return const SizedBox.shrink();
        }
        final voiceState = ref.watch(voiceChatControllerProvider);
        final aiAudioLevelStream = ref
            .read(voiceChatControllerProvider.notifier)
            .aiAudioLevelStream;
        final top = MediaQuery.of(context).padding.top + 22;
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: _StoryNarrationVoiceBar(
                  levelStream: aiAudioLevelStream,
                  isLoading:
                      _isNarrationStarting ||
                      voiceState.isConnecting ||
                      voiceState.isProcessing,
                  isPaused: _isNarrationPaused,
                  isPlaying:
                      voiceState.isPlaying ||
                      voiceState.phase == RealtimeVoicePhase.playing,
                  onTogglePlayback: () =>
                      unawaited(_toggleGeneratedChapterNarration()),
                  onStop: () => unawaited(_stopGeneratedChapterNarration()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeNarrationOverlay() {
    _narrationOverlayEntry?.remove();
    _narrationOverlayEntry = null;
  }

  String _narrationPrompt(String chapterText) {
    return '''
Read the following story chapter aloud exactly as written. Do not add commentary, introductions, labels, sound effects, or extra words.

$chapterText
''';
  }

  ChatBubblePlayState _chapterPlayState(
    ChatMessageModel message,
    VoiceChatState voiceState,
  ) {
    if (_narratingMessageId != message.id) return ChatBubblePlayState.play;
    if (voiceState.isPlaying ||
        voiceState.phase == RealtimeVoicePhase.playing) {
      return ChatBubblePlayState.pause;
    }
    if (_isNarrationPaused || voiceState.phase == RealtimeVoicePhase.paused) {
      return ChatBubblePlayState.play;
    }
    if (_isNarrationStarting ||
        voiceState.isConnecting ||
        voiceState.isProcessing ||
        voiceState.phase == RealtimeVoicePhase.connecting ||
        voiceState.phase == RealtimeVoicePhase.waitingForReady ||
        voiceState.phase == RealtimeVoicePhase.processing) {
      return ChatBubblePlayState.loading;
    }
    return ChatBubblePlayState.play;
  }

  String _storyOptionsKey(List<_ParsedStoryOption> options) {
    return options.map((option) => option.displayText).join('|');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceChatState>(voiceChatControllerProvider, (previous, next) {
      if (!mounted || _narratingMessageId == null) return;
      final wasActive = previous == null
          ? false
          : _isNarrationVoiceActive(previous);
      final isActive = _isNarrationVoiceActive(next);
      if (wasActive && !isActive) {
        _clearNarrationUiState();
      }
    });

    final messages = _buildMessages();
    final voiceState = ref.watch(voiceChatControllerProvider);
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
    final assistantBubbleMaxWidth = (screenWidth * 0.94).clamp(0.0, 560.0);
    final userBubbleMaxWidth = (screenWidth * 0.76).clamp(0.0, 360.0);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final canSubmitText =
        _canSend && !_isSendingText && !_isStartingTextSession;
    final composerStoryOptionMenu = _composerStoryOptionMenu(visibleMessages);
    final pendingPerspectiveStoryOption = _pendingPerspectiveStoryOption;
    final showingPerspectiveOptions = pendingPerspectiveStoryOption != null;
    final composerOptions = showingPerspectiveOptions
        ? _storyPerspectiveOptions
        : composerStoryOptionMenu?.options;
    final hasComposerOptions =
        composerOptions != null && composerOptions.isNotEmpty;
    final hasComposerContinuationActions = _showComposerContinuationActions(
      visibleMessages,
    );
    final composerContinuationQuestion = hasComposerContinuationActions
        ? _composerContinuationQuestion(visibleMessages)
        : null;
    final composerContinuationSuggestions = _suggestedAnswersForQuestion(
      composerContinuationQuestion,
    );
    final hasComposerExtension =
        hasComposerOptions || hasComposerContinuationActions;
    final composerOptionsDisabled =
        _isSubmittingStoryOption || _isSendingText || _isStartingTextSession;
    final composerSurface = hasComposerExtension
        ? const Color(0xFF20211F)
        : mutedSurface;
    final composerRadius = BorderRadius.circular(
      hasComposerExtension ? 24 : 28,
    );
    final hasContinuationSuggestions =
        hasComposerContinuationActions &&
        composerContinuationSuggestions.isNotEmpty;
    final fallbackBottomPadding = _isComposerPanelCollapsed
        ? 132.0
        : hasComposerOptions
        ? 390.0
        : hasComposerContinuationActions
        ? (hasContinuationSuggestions ? 420.0 : 260.0)
        : 104.0;
    final maxBottomPadding = _isComposerPanelCollapsed
        ? 156.0
        : hasContinuationSuggestions
        ? 460.0
        : hasComposerOptions
        ? 430.0
        : double.infinity;
    final measuredBottomPadding = _composerHeight + keyboardHeight + 16;
    final listBottomPadding = measuredBottomPadding > 16
        ? math.min(
            math.max(measuredBottomPadding, fallbackBottomPadding),
            maxBottomPadding,
          )
        : fallbackBottomPadding;
    final narrationActive = _narratingMessageId != null;

    _syncComposerHeight();
    _syncNarrationOverlay(narrationActive);

    if (visibleMessages.length != _lastMessageCount) {
      _lastMessageCount = visibleMessages.length;
      _scrollToBottom(jump: _isStartingTextSession);
    }
    if (hasComposerExtension != _lastHadComposerOptions) {
      _lastHadComposerOptions = hasComposerExtension;
      _scrollToBottomAfterPanelAnimation();
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

    return Stack(
      children: [
        Positioned.fill(
          child: ListView.separated(
            controller: _listScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, 18, 12, listBottomPadding),
            itemCount: visibleMessages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final message = visibleMessages[index];
              final parsedOptions = _parseStoryOptions(message);
              if (parsedOptions != null) {
                final introText = parsedOptions.displayText.trim();
                if (introText.isEmpty) {
                  return const SizedBox.shrink();
                }
                final displayMessage = message.copyWith(message: introText);
                final playState = _chapterPlayState(displayMessage, voiceState);
                return _AnimatedBubble(
                  key: ValueKey('${message.id}_intro'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChatBubble(
                        message: displayMessage,
                        onRetry: () {},
                        maxWidth: assistantBubbleMaxWidth,
                        renderMarkdownBold: true,
                        showPlayIcon: _shouldShowGeneratedChapterPlayIcon(
                          displayMessage,
                        ),
                        onPlayIcon: () => unawaited(
                          _handleGeneratedChapterPlayTap(displayMessage),
                        ),
                        playState: playState,
                      ),
                    ],
                  ),
                );
              }
              final displayMessage =
                  _shouldShowStoryContinuationActions(
                    message: message,
                    index: index,
                    visibleMessageCount: visibleMessages.length,
                    parsedOptions: parsedOptions,
                  )
                  ? _messageWithoutTrailingQuestion(message)
                  : message;
              final playState = _chapterPlayState(displayMessage, voiceState);
              return _AnimatedBubble(
                key: ValueKey(message.id),
                child: Column(
                  crossAxisAlignment: message.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    ChatBubble(
                      message: displayMessage,
                      onRetry: () =>
                          unawaited(_retryFailedStoryTurn(displayMessage)),
                      maxWidth: displayMessage.isUser
                          ? userBubbleMaxWidth
                          : assistantBubbleMaxWidth,
                      loadingLabel: displayMessage.id == 'story_text_connecting'
                          ? 'Story setup…'
                          : _loadingLabelByMessageId[displayMessage.id] ??
                                'Thinking…',
                      renderMarkdownBold: !displayMessage.isUser,
                      showPlayIcon: _shouldShowGeneratedChapterPlayIcon(
                        displayMessage,
                      ),
                      onPlayIcon: () => unawaited(
                        _handleGeneratedChapterPlayTap(displayMessage),
                      ),
                      playState: playState,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: SizedBox(
              key: _composerKey,
              width: double.infinity,
              child: SafeArea(
                top: false,
                minimum: hasComposerExtension
                    ? const EdgeInsets.fromLTRB(10, 8, 10, 16)
                    : const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onVerticalDragUpdate: hasComposerExtension
                            ? _scrollChatFromComposerDrag
                            : null,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: composerSurface,
                            borderRadius: composerRadius,
                            border: hasComposerExtension
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    width: 1,
                                  )
                                : null,
                            boxShadow: hasComposerExtension
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.32,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, -6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasComposerOptions) ...[
                                _StoryOptionsInputPanel(
                                  title: showingPerspectiveOptions
                                      ? 'How should "${pendingPerspectiveStoryOption.title}" be told?'
                                      : composerStoryOptionMenu?.panelTitle ??
                                            'What kind of story sounds good?',
                                  options: composerOptions,
                                  selectedTitle: showingPerspectiveOptions
                                      ? null
                                      : _confirmedStoryOptionTitle,
                                  disabled: composerOptionsDisabled,
                                  collapsed: _isComposerPanelCollapsed,
                                  onNext:
                                      showingPerspectiveOptions ||
                                          _reopenedStoryOptions == null
                                      ? null
                                      : () => unawaited(
                                          _requestNextStoryParagraph(),
                                        ),
                                  onRegenerate: showingPerspectiveOptions
                                      ? _restorePreviousStoryOptions
                                      : () => unawaited(
                                          _regenerateStoryOptions(),
                                        ),
                                  onPickForMe: showingPerspectiveOptions
                                      ? null
                                      : () => unawaited(
                                          _pickStoryOptionForUser(
                                            composerOptions,
                                          ),
                                        ),
                                  onToggleCollapsed:
                                      _toggleComposerPanelCollapsed,
                                  onSelected: (option) => unawaited(
                                    showingPerspectiveOptions
                                        ? _confirmStoryPerspective(option)
                                        : _confirmStoryOption(option),
                                  ),
                                ),
                              ] else if (hasComposerContinuationActions) ...[
                                _StoryOptionsInputPanel(
                                  title:
                                      composerContinuationQuestion ??
                                      'What would you like to do next?',
                                  options: composerContinuationSuggestions,
                                  disabled: composerOptionsDisabled,
                                  collapsed: _isComposerPanelCollapsed,
                                  onNext: () =>
                                      unawaited(_requestNextStoryParagraph()),
                                  onRegenerate: _restorePreviousStoryOptions,
                                  onToggleCollapsed:
                                      _toggleComposerPanelCollapsed,
                                  onSelected: (option) => unawaited(
                                    _sendSuggestedStoryAnswer(option),
                                  ),
                                ),
                              ],
                              if (hasComposerExtension) ...[
                                Divider(
                                  height: 1,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.09)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (hasComposerExtension)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 18),
                                      child: Transform.translate(
                                        offset: const Offset(0, -4),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.42,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox.square(
                                            dimension: 32,
                                            child: Center(
                                              child: Icon(
                                                CupertinoIcons.pencil,
                                                color: mutedText,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Transform.translate(
                                      offset: hasComposerExtension
                                          ? const Offset(0, -4)
                                          : Offset.zero,
                                      child: TextField(
                                        controller: _textController,
                                        maxLines: 5,
                                        minLines: 1,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        cursorColor: context.primaryTextColor,
                                        style: TextStyle(
                                          color: context.primaryTextColor,
                                          fontSize: 16,
                                          height: 1.35,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: hasComposerOptions
                                              ? 'Type your own answer...'
                                              : 'Message',
                                          hintStyle: TextStyle(
                                            color: mutedText,
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.fromLTRB(
                                            hasComposerExtension ? 12 : 18,
                                            14,
                                            8,
                                            14,
                                          ),
                                          isDense: true,
                                        ),
                                        onSubmitted: (_) =>
                                            unawaited(_onSend()),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: 6,
                                      bottom: 6,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: canSubmitText
                                            ? (isDark
                                                  ? Colors.white
                                                  : Colors.black)
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
                                              ? (isDark
                                                    ? Colors.black
                                                    : Colors.white)
                                              : mutedText,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasComposerExtension)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 6,
                                        bottom: 6,
                                      ),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!hasComposerExtension) ...[
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryNarrationVoiceBar extends StatefulWidget {
  const _StoryNarrationVoiceBar({
    required this.levelStream,
    required this.isLoading,
    required this.isPaused,
    required this.isPlaying,
    required this.onTogglePlayback,
    required this.onStop,
  });

  final Stream<double> levelStream;
  final bool isLoading;
  final bool isPaused;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback onStop;

  @override
  State<_StoryNarrationVoiceBar> createState() =>
      _StoryNarrationVoiceBarState();
}

class _StoryNarrationVoiceBarState extends State<_StoryNarrationVoiceBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final foreground = isDark ? Colors.white : Colors.black;
    final surface = isDark
        ? const Color(0xEB181818)
        : Colors.white.withValues(alpha: 0.94);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.08);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.waveform, color: foreground, size: 19),
              const SizedBox(width: 12),
              SizedBox(
                width: 166,
                height: 30,
                child: widget.isLoading
                    ? AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final opacity =
                              0.58 + (_pulseController.value * 0.34);
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Processing voice',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foreground.withValues(alpha: opacity),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                          );
                        },
                      )
                    : widget.isPaused
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Paused',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.72),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      )
                    : StreamBuilder<double>(
                        stream: widget.levelStream,
                        initialData: 0,
                        builder: (context, snapshot) {
                          final level = (snapshot.data ?? 0).clamp(0.0, 1.0);
                          return _StoryNarrationWaveform(
                            level: level,
                            loadingPulse: 0,
                            color: foreground,
                          );
                        },
                      ),
              ),
              const SizedBox(width: 4),
              _StoryNarrationIconButton(
                tooltip: widget.isPlaying ? 'Pause' : 'Play',
                onTap: widget.isLoading ? null : widget.onTogglePlayback,
                icon: widget.isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                color: foreground,
              ),
              _StoryNarrationIconButton(
                tooltip: 'Close',
                onTap: widget.onStop,
                icon: CupertinoIcons.xmark,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryNarrationIconButton extends StatelessWidget {
  const _StoryNarrationIconButton({
    required this.tooltip,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 20,
          child: SizedBox.square(
            dimension: 34,
            child: Center(
              child: Icon(
                icon,
                color: color.withValues(alpha: enabled ? 0.9 : 0.35),
                size: icon == CupertinoIcons.xmark ? 20 : 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryNarrationWaveform extends StatelessWidget {
  const _StoryNarrationWaveform({
    required this.level,
    required this.loadingPulse,
    required this.color,
  });

  final double level;
  final double loadingPulse;
  final Color color;

  static const _weights = <double>[
    0.18,
    0.42,
    0.72,
    0.36,
    0.58,
    0.95,
    0.46,
    0.78,
    0.52,
    0.88,
    0.34,
    0.66,
    0.24,
  ];

  @override
  Widget build(BuildContext context) {
    final normalizedLevel = (level * 5.5).clamp(0.0, 1.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < _weights.length; i++)
          _StoryNarrationWaveBar(
            heightFactor: _heightFactorFor(i, normalizedLevel),
            color: color,
          ),
      ],
    );
  }

  double _heightFactorFor(int index, double normalizedLevel) {
    if (normalizedLevel <= 0.02) {
      final phase = (loadingPulse + index / _weights.length) % 1.0;
      final crest = math.sin(phase * math.pi);
      return 0.16 + (crest * 0.22);
    }

    final weight = _weights[index];
    final stagger = 0.72 + (math.sin(index * 1.7) * 0.18);
    return (0.16 + normalizedLevel * weight * stagger).clamp(0.16, 1.0);
  }
}

class _StoryNarrationWaveBar extends StatelessWidget {
  const _StoryNarrationWaveBar({
    required this.heightFactor,
    required this.color,
  });

  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 95),
      curve: Curves.easeOut,
      width: 6,
      height: 30 * heightFactor,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
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
