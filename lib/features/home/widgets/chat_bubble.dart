import 'package:flutter/material.dart';
import 'package:antroph_mobile/features/home/models/chat_models.dart';

// Dark mode colors
const chatBubbleBgDark = Color(0xFF0B1118);
const userBubbleDark = Color(0xFF1C2533);
const assistantBubbleDark = Color(0xFF0F1720);

// Light mode colors
const chatBubbleBgLight = Color(0xFFF5F5F7);
const userBubbleLight = Color(0xFF007AFF);
const assistantBubbleLight = Color(0xFFE9E9EB);

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
    final userBubble = isDark ? userBubbleDark : userBubbleLight;
    final assistantBubble = isDark ? assistantBubbleDark : assistantBubbleLight;
    final bgColor = message.isUser ? userBubble : assistantBubble;
    final textColor = message.isUser
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    final statusColor = message.isUser
        ? Colors.white70
        : (isDark ? Colors.white70 : Colors.black45);
    final isStreaming = !message.isUser && message.isStreaming;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.message,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
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
  const ChatStatusRow({super.key, required this.message, required this.onRetry});

  final ChatMessageModel message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = message.isUser
        ? Colors.white70
        : (isDark ? Colors.white70 : Colors.black45);
    final actionColor = message.isUser
        ? Colors.white
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
