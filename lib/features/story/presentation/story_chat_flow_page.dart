import 'dart:async';

import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/chat_bubble.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/features/story/presentation/story_voice_page.dart';
import 'package:antroph_mobile/features/story/providers/interactive_story_provider.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/features/story/widgets/interactive_story_renderer.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final String storyId;
  final String? storyTitle;
  final String? storySessionId;
  final MascotConfig? mascotConfig;
  final String? storySubtitle;
  final String? storyImage;
  final bool isAddedToPlaylist;
  final WidgetBuilder? voicePageBuilder;

  @override
  ConsumerState<StoryChatFlowPage> createState() => _StoryChatFlowPageState();
}

class _StoryChatFlowPageState extends ConsumerState<StoryChatFlowPage>
    with WidgetsBindingObserver {
  bool _sessionStarted = false;
  VoiceChatController? _voiceController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      interactionMode = detail.interactionMode;
    } catch (_) {
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_voiceController != null) {
      _voiceController!.endStorySession();
      _voiceController!.stopPlayback();
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
        final voiceController = ref.read(voiceChatControllerProvider.notifier);
        await voiceController.endStorySession();
        await voiceController.stopPlayback();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
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
                  onCall: _openVoicePage,
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
    required this.onCall,
  });

  final String storyId;
  final String interactionMode;
  final VoidCallback onCall;

  @override
  ConsumerState<_InteractiveStoryTab> createState() =>
      _InteractiveStoryTabState();
}

class _InteractiveStoryTabState extends ConsumerState<_InteractiveStoryTab> {
  final _textController = TextEditingController();
  bool _canSend = false;
  bool _started = false;

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
    unawaited(ref.read(interactiveStoryProvider.notifier).submitText(text));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<InteractiveStoryState>(interactiveStoryProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      final error = next.error;
      if (error != null &&
          error.isNotEmpty &&
          error != (previous?.error ?? '')) {
        showToast(context, error, success: false);
        ref.read(interactiveStoryProvider.notifier).clearError();
      }
    });

    final state = ref.watch(interactiveStoryProvider);
    final notifier = ref.read(interactiveStoryProvider.notifier);
    final session = state.session;
    final isDark = context.isDarkMode;
    final mutedSurface = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF3F3F3);
    final mutedText = isDark ? Colors.white60 : Colors.black54;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      children: [
        Expanded(
          child: session == null
              ? const _StorySessionLoadingShell()
              : RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: InteractiveStoryRenderer(
                    session: session,
                    pendingKeys: state.pendingInputKeys,
                    localQuizSelections: state.localQuizSelections,
                    onRetryGeneration: () =>
                        unawaited(notifier.retryGeneration()),
                    onReplay: () => unawaited(
                      notifier.restart(
                        storyId: widget.storyId,
                        interactionMode: widget.interactionMode,
                      ),
                    ),
                    onLeave: () {
                      unawaited(notifier.leaveSession());
                      Navigator.of(context).maybePop();
                    },
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
                        hintText: 'Message',
                        hintStyle: TextStyle(color: mutedText, fontSize: 16),
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
        ),
      ],
    );
  }
}

class _StorySessionLoadingShell extends StatelessWidget {
  const _StorySessionLoadingShell();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final mutedSurface = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF3F3F3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: mutedSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const _StorySessionLoadingShimmer(),
      ),
    );
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
    final hasAiText = voiceState.aiResponse?.isNotEmpty ?? false;
    final awaitingAi = voiceState.isProcessing || voiceState.isConnecting;
    if (hasAiText || awaitingAi) {
      messages.add(
        ChatMessageModel(
          id: 'story_live_ai',
          role: ChatRole.assistant,
          message: voiceState.aiResponse ?? '',
          ts: DateTime.now(),
          streaming: awaitingAi || voiceState.isPlaying || !hasAiText,
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
        if (!voiceState.isSessionReady) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: mutedSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const _StorySessionLoadingShimmer(),
            ),
          ),
        ],
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
              'Chat here or call Aura 🌝',
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

class _StorySessionLoadingShimmer extends StatelessWidget {
  const _StorySessionLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        ShimmerBox(width: 36, height: 36, radius: 18),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerText(width: 150, height: 12, radius: 6),
              SizedBox(height: 8),
              ShimmerText(height: 10, radius: 6),
            ],
          ),
        ),
      ],
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
