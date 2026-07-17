import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:antroph_mobile/features/home/models/chat_models.dart';

const _userBubbleDark = Color(0xFFF5F5F5);
const _assistantBubbleDark = Color(0xFF1A1A1A);
const _userBubbleLight = Color(0xFF111111);
const _assistantBubbleLight = Color(0xFFF3F3F3);

enum ChatBubblePlayState { play, loading, pause }

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.onRetry,
    required this.maxWidth,
    this.renderMarkdownBold = false,
    this.loadingLabel = 'Thinking…',
    this.showPlayIcon = false,
    this.onPlayIcon,
    this.playState = ChatBubblePlayState.play,
  });

  final ChatMessageModel message;
  final VoidCallback onRetry;
  final double maxWidth;
  final bool renderMarkdownBold;
  final String loadingLabel;
  final bool showPlayIcon;
  final VoidCallback? onPlayIcon;
  final ChatBubblePlayState playState;

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
    final showsStatusOnly = isStreaming && message.message.trim().isEmpty;

    final showEdgePlayIcon =
        showPlayIcon &&
        onPlayIcon != null &&
        !message.isUser &&
        !isStreaming &&
        !showsStatusOnly;
    final contentPadding = EdgeInsets.fromLTRB(
      16,
      13,
      showEdgePlayIcon ? 42 : 16,
      showEdgePlayIcon ? 24 : 13,
    );
    final bubble = Container(
      decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!showsStatusOnly)
            _BubbleText(
              text: message.message,
              renderMarkdownBold: renderMarkdownBold,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          if (showsStatusOnly)
            _StreamingStatusLabel(loadingLabel, color: statusColor)
          else if (isStreaming) ...[
            const SizedBox(height: 8),
            _StreamingStatusLabel(loadingLabel, color: statusColor),
          ] else if (message.isPending || message.isFailed) ...[
            const SizedBox(height: 8),
            ChatStatusRow(message: message, onRetry: onRetry),
          ],
        ],
      ),
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: showEdgePlayIcon
              ? const EdgeInsets.only(right: 8, bottom: 10)
              : EdgeInsets.zero,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              bubble,
              if (showEdgePlayIcon)
                Positioned(
                  right: -8,
                  bottom: -10,
                  child: _BubblePlayIcon(state: playState, onTap: onPlayIcon!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubblePlayIcon extends StatelessWidget {
  const _BubblePlayIcon({required this.state, required this.onTap});

  final ChatBubblePlayState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play story narration',
      child: Tooltip(
        message: state == ChatBubblePlayState.pause
            ? 'Pause narration'
            : 'Play narration',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox.square(
              dimension: 38,
              child: Center(child: _BubblePlayIconGlyph(state: state)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePlayIconGlyph extends StatelessWidget {
  const _BubblePlayIconGlyph({required this.state});

  final ChatBubblePlayState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ChatBubblePlayState.loading => const SizedBox.square(
        dimension: 17,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
      ),
      ChatBubblePlayState.pause => const Icon(
        Icons.pause_rounded,
        color: Colors.black,
        size: 24,
      ),
      _ => const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 25),
    };
  }
}

class _StreamingStatusLabel extends StatefulWidget {
  const _StreamingStatusLabel(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  State<_StreamingStatusLabel> createState() => _StreamingStatusLabelState();
}

class _StreamingStatusLabelState extends State<_StreamingStatusLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _labelWidthBasis => switch (widget.label) {
    'Connecting…' ||
    'Preparing…' ||
    'Loading…' => const ['Connecting…', 'Preparing…', 'Loading…'],
    _ => const ['Thinking…', 'Processing…', 'Generating…'],
  };

  Size _measureLabelBox(BuildContext context, List<String> labels) {
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    const style = TextStyle(
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w500,
    );
    var width = 0.0;
    var height = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: _visualStatusLabel(label), style: style),
        textDirection: direction,
        textScaler: textScaler,
      )..layout();
      width = math.max(width, painter.width);
      height = math.max(height, painter.height);
    }
    return Size(width + 8, height + 6);
  }

  @override
  Widget build(BuildContext context) {
    final labelBoxSize = _measureLabelBox(context, _labelWidthBasis);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: labelBoxSize.width,
          height: labelBoxSize.height,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _HandwritingStatusLabel(
                key: ValueKey(widget.label),
                label: widget.label,
                color: widget.color,
                progress: _controller.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

String _visualStatusLabel(String label) => label.replaceAll('…', '...');

class _HandwritingStatusLabel extends StatelessWidget {
  const _HandwritingStatusLabel({
    super.key,
    required this.label,
    required this.color,
    required this.progress,
  });

  final String label;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final displayLabel = _visualStatusLabel(label);
    final easedProgress = Curves.easeInOutCubic.transform(
      (progress / 0.62).clamp(0.0, 1.0),
    );
    final cursorOpacity = progress < 0.76
        ? 1.0
        : 1.0 - ((progress - 0.76) / 0.24).clamp(0.0, 1.0);
    return Semantics(
      label: label,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ExcludeSemantics(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: easedProgress,
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.94),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: _cursorLeft(context, displayLabel, easedProgress),
            top: 2,
            bottom: 2,
            child: ExcludeSemantics(
              child: Opacity(
                opacity: cursorOpacity,
                child: Container(
                  width: 1.6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _cursorLeft(BuildContext context, String label, double progress) {
    final painter = TextPainter(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    painter.text = TextSpan(
      text: label,
      style: const TextStyle(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
    );
    painter.layout();
    return (painter.width * progress).clamp(0.0, painter.width + 1);
  }
}

class _BubbleText extends StatelessWidget {
  const _BubbleText({
    required this.text,
    required this.style,
    required this.renderMarkdownBold,
  });

  final String text;
  final TextStyle style;
  final bool renderMarkdownBold;

  @override
  Widget build(BuildContext context) {
    if (!renderMarkdownBold) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*|__)(.*?)\1', dotAll: true);
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(2) ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: style, children: spans));
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
