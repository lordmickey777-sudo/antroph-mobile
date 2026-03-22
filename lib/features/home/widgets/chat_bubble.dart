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
    final borderColor = message.isUser
        ? Colors.transparent
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06));
    final borderRadius = message.isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(10),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(24),
          );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                const SizedBox(height: 6),
                Row(
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
                      'Streaming...',
                      style: TextStyle(color: statusColor, fontSize: 11),
                    ),
                  ],
                ),
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
