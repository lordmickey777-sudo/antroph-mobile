import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/chat_bubble.dart';

class ChatBottomSheet extends ConsumerStatefulWidget {
  const ChatBottomSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends ConsumerState<ChatBottomSheet> {
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

  void _onSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref
        .read(voiceChatControllerProvider.notifier)
        .sendTextPrompt(text, textOnly: true);
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
          id: 'voice_$i',
          role: item.isUser ? ChatRole.user : ChatRole.assistant,
          message: item.content,
          ts: DateTime.now(),
        ),
      );
    }
    // Live streaming AI response
    if (voiceState.aiResponse?.isNotEmpty ?? false) {
      messages.add(
        ChatMessageModel(
          id: 'voice_live_ai',
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
    final messages = _buildMessages(voiceState);
    final isDark = context.isDarkMode;
    final sheetColor = context.backgroundColor;
    final sectionDivider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final mutedSurface = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF3F3F3);
    final mutedText = isDark ? Colors.white60 : Colors.black54;
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = (screenWidth * 0.82).clamp(0.0, 420.0);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Auto-scroll when new messages arrive
    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }
    // Also scroll on streaming updates
    if (messages.isNotEmpty && messages.last.isStreaming) {
      _scrollToBottom();
    }

    return ColoredBox(
      color: sheetColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat',
                        style: TextStyle(
                          color: context.primaryTextColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Continue this voice conversation in text.',
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: mutedSurface,
                    foregroundColor: context.primaryTextColor,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(CupertinoIcons.xmark, size: 18),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: sectionDivider),
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
              color: sheetColor,
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
                        contentPadding: const EdgeInsets.fromLTRB(
                          18,
                          14,
                          10,
                          14,
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _onSend(),
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
                        onPressed: _canSend ? _onSend : null,
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
              'Ask anything here and keep the voice session in sync.',
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

/// Wraps a chat bubble with a fade-in + slide-up animation on first build.
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
