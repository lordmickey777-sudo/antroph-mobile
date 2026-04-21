import 'package:flutter/material.dart';
import 'package:antroph_mobile/features/home/models/chat_models.dart';

const _userBubbleDark = Color(0xFFF5F5F5);
const _assistantBubbleDark = Color(0xFF1A1A1A);
const _userBubbleLight = Color(0xFF111111);
const _assistantBubbleLight = Color(0xFFF3F3F3);

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.onRetry,
    required this.maxWidth,
  });

  final ChatMessageModel message;
  final VoidCallback onRetry;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final userBubble = isDark ? _userBubbleDark : _userBubbleLight;
    final assistantBubble = isDark
        ? _assistantBubbleDark
        : _assistantBubbleLight;
    final bgColor = message.isUser ? userBubble : assistantBubble;
    final textColor = message.isUser
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : const Color(0xFF171717));
    final statusColor = message.isUser
        ? (isDark ? Colors.black54 : Colors.white70)
        : (isDark ? Colors.white60 : Colors.black45);
    final isStreaming = !message.isUser && message.isStreaming;
    final borderRadius = message.isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(12),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(26),
          );
    final showsTypingOnly = isStreaming && message.message.trim().isEmpty;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!showsTypingOnly)
                Text(
                  message.message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              if (isStreaming) ...[
                SizedBox(height: showsTypingOnly ? 0 : 8),
                _TypingDots(color: statusColor),
              ] else if (message.isPending || message.isFailed) ...[
                const SizedBox(height: 8),
                ChatStatusRow(message: message, onRetry: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final progress = (_controller.value - (index * 0.18)) % 1.0;
            final opacity = 0.3 + ((1 - ((progress - 0.5).abs() * 2)) * 0.7);
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: opacity.clamp(0.2, 1.0),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class ChatStatusRow extends StatelessWidget {
  const ChatStatusRow({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final ChatMessageModel message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = message.isUser
        ? (isDark ? Colors.black54 : Colors.white70)
        : (isDark ? Colors.white60 : Colors.black45);
    final actionColor = message.isUser
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black87);
    if (message.isPending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Sending...',
            style: TextStyle(color: statusColor, fontSize: 11),
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
            foregroundColor: actionColor,
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
