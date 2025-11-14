import 'package:flutter/material.dart';
import '../models/expression_models.dart';

/// Widget to display animated robot facial expressions
class ExpressionDisplay extends StatelessWidget {
  final RobotExpression expression;
  final double size;
  final bool showGlow;

  const ExpressionDisplay({
    super.key,
    required this.expression,
    this.size = 200,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showGlow
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(color: Colors.white.withOpacity(0.05), blurRadius: 40, spreadRadius: 8),
              ],
            )
          : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: Image.asset(
          expression.assetPath,
          key: ValueKey(expression),
          fit: BoxFit.contain,
          width: size,
          height: size,
        ),
      ),
    );
  }
}

/// Widget for voice recording button with visual feedback
class VoiceRecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback? onPressed;
  final double size;

  const VoiceRecordButton({super.key, required this.isRecording, this.onPressed, this.size = 75});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isRecording ? Colors.red : Colors.white,
          shape: BoxShape.circle,
          boxShadow: isRecording
              ? [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)]
              : [],
        ),
        child: Center(
          child: Icon(
            isRecording ? Icons.stop : Icons.mic,
            color: isRecording ? Colors.white : Colors.black,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// Widget to show audio playback progress
class AudioPlaybackIndicator extends StatelessWidget {
  final bool isPlaying;
  final double progress; // 0.0 to 1.0
  final String? currentTime;
  final String? totalTime;

  const AudioPlaybackIndicator({
    super.key,
    required this.isPlaying,
    this.progress = 0.0,
    this.currentTime,
    this.totalTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPlaying ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
          ),
          if (currentTime != null && totalTime != null) ...[
            const SizedBox(width: 12),
            Text(
              '$currentTime / $totalTime',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
