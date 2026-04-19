import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/home/models/expression_models.dart';
import 'package:antroph_mobile/features/home/models/realtime_voice_bridge_models.dart';
import 'package:antroph_mobile/features/home/providers/chat_provider.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/permission_modal.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/voice_activity_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({
    super.key,
    this.isStoryMode = false,
    this.mascotConfig,
    this.expressionStream,
    this.onEnd,
    this.onOpenChat,
    this.showMascotFace = true,
  });

  final bool isStoryMode;
  final MascotConfig? mascotConfig;
  final Stream<MascotExpressionEvent>? expressionStream;
  final VoidCallback? onEnd;
  final VoidCallback? onOpenChat;
  final bool showMascotFace;

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen> {
  void _handleVoicePermissionDialogs(
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

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceChatState>(voiceChatControllerProvider, (
      previous,
      next,
    ) async {
      _handleVoicePermissionDialogs(previous, next);
      if (!mounted) return;
      final error = next.errorMessage;
      if (error != null &&
          error.isNotEmpty &&
          error != (previous?.errorMessage ?? '')) {
        showToast(context, error);
      }
    });

    // Only listen to chatControllerProvider errors in non-story mode
    // In story mode, we only use voiceChatControllerProvider to avoid double WebSocket connections
    if (!widget.isStoryMode) {
      ref.listen<ChatState>(chatControllerProvider, (previous, next) {
        if (!mounted) return;
        final error = next.error;
        if (error != null &&
            error.isNotEmpty &&
            error != (previous?.error ?? '')) {
          showToast(context, error);
        }
      });
    }

    final ChatController? chatController = widget.isStoryMode
        ? null
        : ref.read(chatControllerProvider.notifier);
    final voiceState = ref.watch(voiceChatControllerProvider);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = AppPadding.horizontal.fromConstraints(
          constraints,
        );
        final faceSize = math
            .min(constraints.maxWidth * 0.75, constraints.maxHeight * 0.56)
            .clamp(220.0, 380.0);
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    4,
                  ),
                  child: _Header(
                    voiceState: voiceState,
                    aiAudioLevelStream: voiceController.aiAudioLevelStream,
                    mascotConfig: widget.mascotConfig,
                    expressionStream: widget.expressionStream,
                    showMascotFace: widget.showMascotFace,
                    onReconnect: chatController?.forceReconnect,
                    faceSize: faceSize,
                    hasConversation:
                        voiceState.conversationHistory.isNotEmpty ||
                        (voiceState.userTranscription?.isNotEmpty ?? false) ||
                        (voiceState.aiResponse?.isNotEmpty ?? false),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MuteButton(
                      isMuted: voiceState.isMuted,
                      onToggle: voiceController.toggleMute,
                    ),
                    const SizedBox(width: 24),
                    _EndButton(
                      onEnd:
                          widget.onEnd ??
                          () {
                            if (widget.isStoryMode) {
                              voiceController.endStorySession();
                            } else {
                              voiceController.cancelRecording();
                            }
                            Navigator.of(context).pop();
                          },
                    ),
                    if (widget.onOpenChat != null) ...[
                      const SizedBox(width: 24),
                      _ChatCircleButton(onTap: widget.onOpenChat!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.voiceState,
    required this.aiAudioLevelStream,
    this.mascotConfig,
    this.expressionStream,
    this.showMascotFace = true,
    this.onReconnect,
    required this.faceSize,
    this.hasConversation = false,
  });

  final VoiceChatState voiceState;
  final Stream<double> aiAudioLevelStream;
  final MascotConfig? mascotConfig;
  final Stream<MascotExpressionEvent>? expressionStream;
  final bool showMascotFace;
  final VoidCallback? onReconnect;
  final double faceSize;
  final bool hasConversation;

  @override
  Widget build(BuildContext context) {
    final status = _voiceStatus(voiceState);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(),
        child: Column(
          children: [
            RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: faceSize,
                  height: faceSize,
                  child: showMascotFace
                      ? VoiceActivityFace(
                          levelStream: aiAudioLevelStream,
                          expressionStream: expressionStream,
                          threshold: 0.008,
                          silenceDelay: const Duration(milliseconds: 450),
                          mascotConfig: mascotConfig,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.isDarkMode
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.face_rounded,
                              size: (faceSize * 0.22).clamp(36.0, 64.0),
                              color: context.primaryTextColor,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                _StatusPill(
                  label: status.label,
                  icon: status.icon,
                  isActive: status.isActive,
                  variant: status.variant,
                ),
              ],
            ),
            if (!hasConversation &&
                !voiceState.isPlaying &&
                !voiceState.isProcessing) ...[
              const SizedBox(height: 16),
              _ReadyPrompt(isListening: voiceState.isRecording),
            ],
          ],
        ),
      ),
    );
  }

  _StatusData _voiceStatus(VoiceChatState voice) {
    if (voice.isMuted) {
      return const _StatusData('Muted', Icons.mic_off);
    }

    if (voice.isStoryMode) {
      switch (voice.phase) {
        case RealtimeVoicePhase.connecting:
        case RealtimeVoicePhase.waitingForReady:
          return const _StatusData('Connecting', Icons.wifi);
        case RealtimeVoicePhase.ready:
          return const _StatusData('Ready', Icons.bolt);
        case RealtimeVoicePhase.recording:
          return voice.isUserSpeaking
              ? const _StatusData(
                  'Hearing you',
                  Icons.chat_bubble_rounded,
                  isActive: true,
                  variant: _StatusVariant.soundWave,
                )
              : const _StatusData('Mic on', Icons.mic_none_rounded);
        case RealtimeVoicePhase.processing:
          return const _StatusData(
            'hmmmmmnn',
            Icons.cloud_sync,
            isActive: true,
            variant: _StatusVariant.dancingDots,
          );
        case RealtimeVoicePhase.playing:
          return const _StatusData('Narrating', Icons.graphic_eq);
        case RealtimeVoicePhase.paused:
          return const _StatusData('Paused', Icons.pause_circle);
        case RealtimeVoicePhase.error:
          return const _StatusData('Error', Icons.error_outline);
        case RealtimeVoicePhase.closed:
        case RealtimeVoicePhase.idle:
          return const _StatusData('Disconnected', Icons.cloud_off);
      }
    }

    if (voice.isRecording) {
      return voice.isUserSpeaking
          ? const _StatusData(
              'Hearing you',
              Icons.chat_bubble_rounded,
              isActive: true,
              variant: _StatusVariant.soundWave,
            )
          : const _StatusData('Mic on', Icons.mic_none_rounded);
    }
    if (voice.isProcessing) {
      return const _StatusData(
        'hmmmmmnn',
        Icons.cloud_sync,
        isActive: true,
        variant: _StatusVariant.dancingDots,
      );
    }
    if (voice.isPlaying) {
      return const _StatusData('Replying', Icons.graphic_eq);
    }
    return const _StatusData('Ready', Icons.bolt);
  }
}

enum _StatusVariant { iconLabel, dancingDots, soundWave }

class _StatusData {
  const _StatusData(
    this.label,
    this.icon, {
    this.isActive = false,
    this.variant = _StatusVariant.iconLabel,
  });
  final String label;
  final IconData icon;
  final bool isActive;
  final _StatusVariant variant;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    this.isActive = false,
    this.variant = _StatusVariant.iconLabel,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final _StatusVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final labelColor = isDark ? Colors.white : Colors.black87;
    final highlight = isActive
        ? (isDark
              ? const Color(0xFF42D6A4).withValues(alpha: 0.42)
              : const Color(0xFFCCF6E8))
        : (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.55));
    final tint = isActive
        ? (isDark
              ? const Color(0xFF0E5A46).withValues(alpha: 0.82)
              : const Color(0xFFA9EFD8))
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.25));
    final borderColor = isActive
        ? const Color(0xFF42D6A4).withValues(alpha: isDark ? 0.72 : 0.9)
        : (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.6));

    return AnimatedScale(
      scale: isActive ? 1.04 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? 16 : 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [highlight, tint],
              ),
              border: Border.all(color: borderColor, width: isActive ? 1 : 0.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: isActive ? 16 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildInner(labelColor),
          ),
        ),
      ),
    );
  }

  Widget _buildInner(Color labelColor) {
    switch (variant) {
      case _StatusVariant.dancingDots:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            _DancingDots(color: labelColor),
          ],
        );
      case _StatusVariant.soundWave:
        return _SoundWaveBars(color: labelColor);
      case _StatusVariant.iconLabel:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: labelColor, size: isActive ? 15 : 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }
  }
}

class _DancingDots extends StatefulWidget {
  const _DancingDots({required this.color});

  final Color color;

  @override
  State<_DancingDots> createState() => _DancingDotsState();
}

class _DancingDotsState extends State<_DancingDots>
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
    return SizedBox(
      width: 22,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (i) {
              final phase = (_controller.value + i * 0.18) % 1.0;
              final bob = math.sin(phase * 2 * math.pi);
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                child: Transform.translate(
                  offset: Offset(0, -bob * 2.5),
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _SoundWaveBars extends StatefulWidget {
  const _SoundWaveBars({required this.color});

  final Color color;

  @override
  State<_SoundWaveBars> createState() => _SoundWaveBarsState();
}

class _SoundWaveBarsState extends State<_SoundWaveBars>
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
    const barCount = 5;
    return SizedBox(
      width: 36,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final phase = (_controller.value + i * 0.16) % 1.0;
              final amp = (math.sin(phase * 2 * math.pi) + 1) / 2;
              final h = 4.0 + amp * 11.0;
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                child: Container(
                  width: 2.5,
                  height: h,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ReadyPrompt extends StatefulWidget {
  const _ReadyPrompt({this.isListening = false});

  final bool isListening;

  @override
  State<_ReadyPrompt> createState() => _ReadyPromptState();
}

class _ReadyPromptState extends State<_ReadyPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final textColor = isDark ? Colors.white70 : Colors.black54;
    final text = widget.isListening ? 'Say something when you\'re ready' : '';
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.isMuted, required this.onToggle});

  final bool isMuted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bgColor = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.06);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor),
        ),
        child: Icon(
          isMuted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
          size: 28,
          color: labelColor,
        ),
      ),
    );
  }
}

class _EndButton extends StatelessWidget {
  const _EndButton({required this.onEnd});

  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bgColor = isDark ? Colors.red.shade400 : Colors.red;

    return GestureDetector(
      onTap: onEnd,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
        child: const Icon(
          Icons.call_end_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _ChatCircleButton extends StatelessWidget {
  const _ChatCircleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bgColor = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.06);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor),
        ),
        child: Icon(
          Icons.chat_bubble_rounded,
          size: 26,
          color: labelColor,
        ),
      ),
    );
  }
}
