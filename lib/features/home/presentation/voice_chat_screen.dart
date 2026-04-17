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

const _accent = Color(0xFF9CC6FF);

class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({
    super.key,
    this.isStoryMode = false,
    this.mascotConfig,
    this.expressionStream,
    this.onEnd,
  });

  final bool isStoryMode;
  final MascotConfig? mascotConfig;
  final Stream<MascotExpressionEvent>? expressionStream;
  final VoidCallback? onEnd;

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

    final ChatController? chatController =
        widget.isStoryMode ? null : ref.read(chatControllerProvider.notifier);
    final voiceState = ref.watch(voiceChatControllerProvider);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = AppPadding.horizontal.fromConstraints(
          constraints,
        );
        final faceSize = (constraints.maxWidth * 0.75).clamp(250.0, 380.0);
        return Column(
          children: [
            Padding(
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
                onReconnect: chatController?.forceReconnect,
                onStartVoice: voiceController.startRecording,
                onStopVoice: voiceController.stopRecordingAndSend,
                onStopVoicePlayback: () {
                  voiceController.stopPlayback(restartListening: true);
                },
                faceSize: faceSize,
                hasConversation:
                    voiceState.conversationHistory.isNotEmpty ||
                    (voiceState.userTranscription?.isNotEmpty ?? false) ||
                    (voiceState.aiResponse?.isNotEmpty ?? false),
              ),
            ),
            const Spacer(),
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
                      onEnd: widget.onEnd ??
                          () {
                            if (widget.isStoryMode) {
                              voiceController.endStorySession();
                            } else {
                              voiceController.cancelRecording();
                            }
                            Navigator.of(context).pop();
                          },
                    ),
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
    this.onReconnect,
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onStopVoicePlayback,
    required this.faceSize,
    this.hasConversation = false,
  });

  final VoiceChatState voiceState;
  final Stream<double> aiAudioLevelStream;
  final MascotConfig? mascotConfig;
  final Stream<MascotExpressionEvent>? expressionStream;
  final VoidCallback? onReconnect;
  final VoidCallback onStartVoice;
  final VoidCallback onStopVoice;
  final VoidCallback onStopVoicePlayback;
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
                  child: VoiceActivityFace(
                    levelStream: aiAudioLevelStream,
                    expressionStream: expressionStream,
                    threshold: 0.008,
                    silenceDelay: const Duration(milliseconds: 450),
                    mascotConfig: mascotConfig,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                _StatusPill(label: status.label, icon: status.icon),
              ],
            ),
            if (!hasConversation &&
                !voiceState.isPlaying &&
                !voiceState.isProcessing) ...[
              const SizedBox(height: 16),
              _ReadyPrompt(isListening: voiceState.isRecording),
            ],
            const SizedBox(height: 22),
            _HeroMicButton(
              voiceState: voiceState,
              onStart: onStartVoice,
              onStop: onStopVoice,
              onStopPlayback: onStopVoicePlayback,
            ),
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
        case RealtimeVoicePhase.recording:
          return const _StatusData('Listening', Icons.mic);
        case RealtimeVoicePhase.processing:
          return const _StatusData('Processing', Icons.cloud_sync);
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
      return const _StatusData('Listening', Icons.mic);
    }
    if (voice.isProcessing) {
      return const _StatusData('Processing', Icons.cloud_sync);
    }
    if (voice.isPlaying) {
      return const _StatusData('Replying', Icons.graphic_eq);
    }
    return const _StatusData('Ready', Icons.bolt);
  }
}

class _StatusData {
  const _StatusData(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1E2631) : const Color(0xFFE6EBF1);
    final labelColor = isDark ? Colors.white : Colors.black87;
    final iconColor = labelColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
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

class _HeroMicButton extends StatelessWidget {
  const _HeroMicButton({
    required this.voiceState,
    required this.onStart,
    required this.onStop,
    required this.onStopPlayback,
  });

  final VoiceChatState voiceState;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onStopPlayback;

  @override
  Widget build(BuildContext context) {
    final recording = voiceState.isRecording;
    final waiting = voiceState.isProcessing || voiceState.isConnecting;
    final playing = voiceState.isPlaying;
    final canRecord = !recording && !waiting && !playing;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = LinearGradient(
      colors: recording
          ? [isDark ? Colors.white : Colors.black87, _accent]
          : [
              _accent.withValues(alpha: 0.8),
              isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.08),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: () {
        if (canRecord) {
          onStart();
        } else if (recording) {
          onStop();
        } else if (waiting || playing) {
          onStopPlayback();
        }
      },
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          recording
              ? Icons.stop_rounded
              : (waiting || playing)
                  ? Icons.close_rounded
                  : Icons.mic_rounded,
          color: recording
              ? Colors.black
              : (isDark ? Colors.white : Colors.black),
          size: 34,
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
    final bgColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMuted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
              size: 18,
              color: labelColor,
            ),
            const SizedBox(width: 8),
            Text(
              isMuted ? 'Muted' : 'Mute',
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
