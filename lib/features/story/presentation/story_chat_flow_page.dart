import 'dart:async';

import 'package:antroph_mobile/core/navigation/app_route_observer.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/presentation/voice_chat_screen.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/chat_bubble.dart';
import 'package:antroph_mobile/features/home/widgets/permission_modal.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
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
  });

  final String storyId;
  final String? storyTitle;
  final String? storySessionId;
  final MascotConfig? mascotConfig;
  final String? storySubtitle;
  final String? storyImage;
  final bool isAddedToPlaylist;

  @override
  ConsumerState<StoryChatFlowPage> createState() => _StoryChatFlowPageState();
}

class _StoryChatFlowPageState extends ConsumerState<StoryChatFlowPage>
    with WidgetsBindingObserver, RouteAware, TickerProviderStateMixin {
  ModalRoute<void>? _modalRoute;
  late final TabController _tabController;
  int _lastTabIndex = 0;
  bool _sessionStarted = false;
  bool _voiceTabVisited = false;
  bool _buildVoiceUi = false;
  VoiceChatController? _voiceController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _lastTabIndex = _tabController.index;
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceController = ref.read(voiceChatControllerProvider.notifier);
      _initStorySessionAndChatMode();
    });
  }

  void _initStorySessionAndChatMode() {
    if (_sessionStarted) return;
    _sessionStarted = true;

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if ((widget.storySessionId ?? '').trim().isNotEmpty) {
      unawaited(voiceController.resumeStorySession(widget.storySessionId!));
    } else {
      unawaited(voiceController.startStorySession(widget.storyId));
    }

    // Chat-first: keep this tab silent and prevent auto-listen from kicking in.
    unawaited(voiceController.stopPlayback());
    final voiceState = ref.read(voiceChatControllerProvider);
    if (!voiceState.isMuted) {
      voiceController.toggleMute();
    }
  }

  void _handleTabChange() {
    final index = _tabController.index;
    if (index == _lastTabIndex) return;
    _lastTabIndex = index;
    if (index == 0) {
      _enterChatTab();
    } else {
      _enterVoiceTab();
    }
  }

  void _enterChatTab() {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final voiceState = ref.read(voiceChatControllerProvider);

    if (!voiceState.isMuted) {
      voiceController.toggleMute();
    }
    unawaited(voiceController.stopPlayback());
  }

  void _enterVoiceTab() {
    if (!_voiceTabVisited) {
      setState(() => _voiceTabVisited = true);
    }
    if (!_buildVoiceUi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_buildVoiceUi) return;
        setState(() => _buildVoiceUi = true);
      });
    }

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final voiceState = ref.read(voiceChatControllerProvider);

    if (voiceState.isMuted) {
      voiceController.toggleMute();
    } else if (!voiceState.isBusy && voiceState.isSessionReady) {
      unawaited(voiceController.startRecording());
    }
  }

  void _openStoryDetails(BuildContext context) {
    showAppBottomSheet(
      context: context,
      builder: (_, scrollController) => StorySheetContent(
        storyId: widget.storyId,
        title:
            (widget.storyTitle?.isNotEmpty ?? false) ? widget.storyTitle! : 'Story',
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
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    if (_voiceController != null) {
      _voiceController!.pauseStorySession();
      _voiceController!.endStorySession();
    }
    WidgetsBinding.instance.removeObserver(this);
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
  void didPushNext() {
    ref.read(voiceChatControllerProvider.notifier).pauseStorySession();
  }

  @override
  void didPopNext() {
    ref.read(voiceChatControllerProvider.notifier).resumePausedSession();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceChatState>(voiceChatControllerProvider, (
      previous,
      next,
    ) async {
      // When the Aura tab is selected but the voice UI isn't built yet (first
      // open), we still need to handle microphone education/settings dialogs.
      if (mounted && _tabController.index == 1 && !_buildVoiceUi) {
        await _handleVoicePermissionDialogs(previous, next);
      }
      if (!mounted) return;
      final error = next.errorMessage;
      if (error != null &&
          error.isNotEmpty &&
          error != (previous?.errorMessage ?? '')) {
        showToast(context, error);
      }
    });

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final title = (widget.storyTitle?.isNotEmpty ?? false)
        ? widget.storyTitle!
        : 'Chat';

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: TypographyText(
          title,
          variant: TypographyVariant.h4,
          color: context.primaryTextColor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.primaryTextColor,
          labelColor: context.primaryTextColor,
          unselectedLabelColor: context.secondaryTextColor,
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Aura'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _StoryTextChatTab(),
          _voiceTabVisited
              ? (_buildVoiceUi
                    ? SafeArea(
                        child: VoiceChatScreen(
                          isStoryMode: true,
                          mascotConfig: widget.mascotConfig,
                          expressionStream: voiceController.mascotExpressionStream,
                          onEnd: () {
                            voiceController.endStorySession();
                            Navigator.of(context).pop();
                          },
                        ),
                      )
                    : const _VoiceTabPlaceholder(
                        title: 'Loading Aura…',
                        subtitle: 'Getting the mascot ready.',
                      ))
              : const _VoiceTabPlaceholder(
                  title: 'Switch to Aura',
                  subtitle: 'Open the Aura tab to start voice.',
                ),
        ],
      ),
    );
  }
}

extension on _StoryChatFlowPageState {
  Future<void> _handleVoicePermissionDialogs(
    VoiceChatState? previous,
    VoiceChatState next,
  ) async {
    if (!mounted || previous?.permissionDialog == next.permissionDialog) {
      return;
    }
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    switch (next.permissionDialog) {
      case PermissionDialogType.education:
        final accepted = await MicrophoneEducationDialog.show(context);
        voiceController.handleEducationDialogResult(accepted ?? false);
        break;
      case PermissionDialogType.settings:
        await MicrophonePermissionModal.show(context);
        voiceController.dismissPermissionDialog();
        break;
      case PermissionDialogType.none:
        break;
    }
  }
}

class _VoiceTabPlaceholder extends StatelessWidget {
  const _VoiceTabPlaceholder({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surface = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final border = isDark ? Colors.white12 : Colors.black12;
    final secondary = isDark ? Colors.white70 : Colors.black54;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.sparkles, color: context.primaryTextColor),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: context.primaryTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: secondary, fontSize: 14, height: 1.35),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryTextChatTab extends ConsumerStatefulWidget {
  const _StoryTextChatTab();

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

    // Avoid sending before story session is ready (prevents confusing backend errors).
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
    if (voiceState.aiResponse?.isNotEmpty ?? false) {
      messages.add(
        ChatMessageModel(
          id: 'story_live_ai',
          role: ChatRole.assistant,
          message: voiceState.aiResponse!,
          ts: DateTime.now(),
          streaming: voiceState.isProcessing || voiceState.isPlaying,
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
    final sectionDivider = isDark ? Colors.white12 : Colors.black12;
    final mutedSurface = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F3F3);
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: mutedSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sectionDivider),
              ),
              child: Row(
                children: [
                  CupertinoActivityIndicator(
                    color: context.primaryTextColor,
                    radius: 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Preparing story session…',
                      style: TextStyle(color: mutedText, fontSize: 13),
                    ),
                  ),
                ],
              ),
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
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 14 + keyboardHeight,
          ),
          decoration: BoxDecoration(
            color: context.backgroundColor,
            border: Border(top: BorderSide(color: sectionDivider)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mutedSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: sectionDivider),
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
                      hintStyle: TextStyle(color: mutedText, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
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
                        Icons.arrow_upward_rounded,
                        color: _canSend
                            ? (isDark ? Colors.black : Colors.white)
                            : mutedText,
                        size: 20,
                      ),
                    ),
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: mutedSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                CupertinoIcons.chat_bubble_text,
                color: primaryTextColor,
                size: 28,
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
              'Chat here first, then switch to Aura when you want voice.',
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
