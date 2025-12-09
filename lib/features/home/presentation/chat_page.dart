import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/providers/chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/face_avatar.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

const _chatBg = Color(0xFF121516);
const _userBubble = Color(0xFF2E6EFF);
const _assistantBubble = Color(0xFF1B1F22);

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.storyTitle});

  final String? storyTitle;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(chatControllerProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      controller.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chatBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TypographyText(
          widget.storyTitle ?? 'Chat',
          variant: TypographyVariant.h3,
          color: Colors.white,
        ),
      ),
      body: const SafeArea(child: ChatScreen()),
    );
  }
}

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final failedMessage = _lastFailed(state.messages);

    return Column(
      children: [
        const SizedBox(height: 12),
        _Header(state: state, onReconnect: controller.forceReconnect),
        if (state.error != null && state.error!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ErrorChip(
              message: state.error!,
              onClear: controller.clearError,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ChatList(
            messages: state.messages,
            onRetry: controller.retrySend,
          ),
        ),
        MessageInput(
          enabled: state.isConnected,
          isConnecting: state.isConnecting,
          retryIn: state.retryIn,
          error: state.error,
          failedMessage: failedMessage,
          onSend: controller.sendMessage,
          onReconnect: controller.forceReconnect,
          onRetryFailed: failedMessage != null
              ? () => controller.retrySend(failedMessage.id)
              : null,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onReconnect});

  final ChatState state;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final faceSize = (size.width * 0.5).clamp(140.0, 220.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          FaceAvatar(pose: state.face, size: faceSize),
          const SizedBox(height: 10),
          _ConnectionChip(state: state, onReconnect: onReconnect),
        ],
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state, required this.onReconnect});

  final ChatState state;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (state.isConnected) {
      color = Colors.greenAccent;
      label = 'Connected';
    } else if (state.isConnecting) {
      color = Colors.amberAccent;
      label = 'Connecting...';
    } else {
      color = Colors.redAccent;
      final retry = state.retryIn?.inSeconds ?? 0;
      label = retry > 0 ? 'Reconnecting in ${retry}s' : 'Disconnected';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (state.isDisconnected) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onReconnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Reconnect'),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatList extends StatelessWidget {
  const ChatList({super.key, required this.messages, required this.onRetry});

  final List<ChatMessageModel> messages;
  final void Function(String messageId) onRetry;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyState();
    }
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return _ChatBubble(
          message: message,
          onRetry: () => onRetry(message.id),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onRetry});

  final ChatMessageModel message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bgColor = message.isUser ? _userBubble : _assistantBubble;
    final textColor = message.isUser ? Colors.white : Colors.white;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.message,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
              ),
              if (message.isPending || message.isFailed) ...[
                const SizedBox(height: 8),
                _StatusRow(message: message, onRetry: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.message, required this.onRetry});

  final ChatMessageModel message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.isPending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Sending...',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
        const SizedBox(width: 6),
        const Text(
          'Failed',
          style: TextStyle(color: Colors.redAccent, fontSize: 11),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class MessageInput extends StatefulWidget {
  const MessageInput({
    super.key,
    required this.enabled,
    required this.isConnecting,
    required this.retryIn,
    this.error,
    this.failedMessage,
    required this.onSend,
    required this.onReconnect,
    this.onRetryFailed,
  });

  final bool enabled;
  final bool isConnecting;
  final Duration? retryIn;
  final String? error;
  final ChatMessageModel? failedMessage;
  final ValueChanged<String> onSend;
  final VoidCallback onReconnect;
  final VoidCallback? onRetryFailed;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && _controller.text.trim().isNotEmpty;
    final retrySeconds = widget.retryIn?.inSeconds ?? 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: widget.enabled,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: canSend ? _handleSend : null,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.isConnecting)
                  const Text(
                    'Connecting...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  )
                else if (!widget.enabled)
                  Text(
                    retrySeconds > 0
                        ? 'Reconnecting in ${retrySeconds}s'
                        : 'Disconnected',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  )
                else
                  const Text(
                    'Connected',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                const Spacer(),
                if (!widget.enabled)
                  TextButton(
                    onPressed: widget.onReconnect,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Reconnect'),
                  ),
              ],
            ),
            if (widget.failedMessage != null &&
                widget.onRetryFailed != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last message failed to send.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onRetryFailed,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 42),
          SizedBox(height: 8),
          Text(
            'Say hello to start chatting',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorChip extends StatelessWidget {
  const _ErrorChip({required this.message, required this.onClear});

  final String message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }
}

ChatMessageModel? _lastFailed(List<ChatMessageModel> messages) {
  for (final m in messages.reversed) {
    if (m.isFailed) return m;
  }
  return null;
}
