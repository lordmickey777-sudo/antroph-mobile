import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/providers/chat_provider.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/antroph_face.dart';
import 'package:antroph_mobile/features/home/widgets/face_canvas.dart';
import 'package:antroph_mobile/features/home/widgets/permission_modal.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

const _chatBg = Color(0xFF0B1118);
const _surface = Color(0xFF111822);
const _userBubble = Color(0xFF1C2533);
const _assistantBubble = Color(0xFF0F1720);
const _accent = Color(0xFF9CC6FF);
const _pageGradient = LinearGradient(
  colors: [Color(0xFF0F1622), Color(0xFF0B1118)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.storyTitle});

  final String? storyTitle;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
        toolbarHeight: 76,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TypographyText(
                    widget.storyTitle ?? 'Voice chat',
                    variant: TypographyVariant.h4,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: _pageGradient),
        child: const SafeArea(child: ChatScreen()),
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  void _handleVoicePermissionDialogs(VoiceChatState? previous, VoiceChatState next) async {
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
    ref.listen<VoiceChatState>(voiceChatControllerProvider, (previous, next) async {
      _handleVoicePermissionDialogs(previous, next);
      if (!mounted) return;
      final error = next.errorMessage;
      if (error != null && error.isNotEmpty && error != (previous?.errorMessage ?? '')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.black87)),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      if (!mounted) return;
      final error = next.error;
      if (error != null && error.isNotEmpty && error != (previous?.error ?? '')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.black87)),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final voiceState = ref.watch(voiceChatControllerProvider);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);

    return Column(
      children: [
        const SizedBox(height: 12),
        _Header(
          state: state,
          voiceState: voiceState,
          onReconnect: controller.forceReconnect,
          onStartVoice: voiceController.startRecording,
          onStopVoice: voiceController.stopRecordingAndSend,
          onStopVoicePlayback: voiceController.stopPlayback,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ChatList(messages: state.messages, onRetry: controller.retrySend),
        ),
        if (_VoiceStatusBar.shouldShow(voiceState))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VoiceStatusBar(
              state: voiceState,
              onStop: () {
                if (voiceState.isRecording) {
                  voiceController.stopRecordingAndSend();
                } else {
                  voiceController.stopPlayback();
                }
              },
              onCancel: () {
                voiceController.cancelRecording();
                voiceController.clearError();
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.voiceState,
    required this.onReconnect,
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onStopVoicePlayback,
  });

  final ChatState state;
  final VoiceChatState voiceState;
  final VoidCallback onReconnect;
  final VoidCallback onStartVoice;
  final VoidCallback onStopVoice;
  final VoidCallback onStopVoicePlayback;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final faceSize = (size.width * 0.42).clamp(140.0, 200.0);
    final voiceFace = voiceState.currentFaceBitmap;
    final headline = _headline(state, voiceState);
    final status = _voiceStatus(voiceState);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(),
        child: Column(
          children: [
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     _ConnectionChip(state: state, onReconnect: onReconnect),
            //     _StatusPill(label: status.label, icon: status.icon),
            //   ],
            // ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: voiceFace != null && voiceFace.isNotEmpty
                  ? FaceCanvas(
                      key: const ValueKey('voice-face'),
                      bitmap: voiceFace,
                      timestampMs: voiceState.faceTimestampMs,
                      size: faceSize,
                      faceColor: AntrophFace.skinTone,
                      backgroundColor: _assistantBubble,
                      showFrame: false,
                    )
                  : RepaintBoundary(
                      key: const ValueKey('chat-face'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF121A26), Color(0xFF0D131B)],
                          ),
                        ),
                        child: SizedBox(
                          width: faceSize,
                          height: faceSize,
                          child: AntrophFace(
                            faceDNA: state.face.toArray(),
                            backgroundColor: _assistantBubble,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
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

  String _headline(ChatState chat, VoiceChatState voice) {
    if (voice.isRecording) return 'Listening';
    if (voice.userTranscription?.isNotEmpty ?? false) {
      return voice.userTranscription!;
    }
    if (voice.aiResponse?.isNotEmpty ?? false) {
      return voice.aiResponse!;
    }
    if (chat.messages.isNotEmpty) {
      return chat.messages.last.message;
    }
    return '';
  }

  _StatusData _voiceStatus(VoiceChatState voice) {
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

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state, required this.onReconnect});

  final ChatState state;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    if (state.isConnected) {
      color = Colors.greenAccent;
      label = 'Connected';
      icon = Icons.bolt;
    } else if (state.isConnecting) {
      color = Colors.amberAccent;
      label = 'Connecting...';
      icon = Icons.wifi_tethering;
    } else {
      color = Colors.redAccent;
      final retry = state.retryIn?.inSeconds ?? 0;
      label = retry > 0 ? 'Reconnecting in ${retry}s' : 'Disconnected';
      icon = Icons.wifi_off;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (state.isDisconnected) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onReconnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Reconnect'),
            ),
          ],
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _accent, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
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
    final action = recording
        ? onStop
        : waiting || playing
        ? onStopPlayback
        : onStart;
    final gradient = LinearGradient(
      colors: recording
          ? [Colors.white, _accent]
          : [_accent.withOpacity(0.8), Colors.white.withOpacity(0.2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: action,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(recording ? 0.6 : 0.25),
              blurRadius: 30,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(
            recording
                ? Icons.stop_rounded
                : waiting || playing
                ? Icons.pause_rounded
                : Icons.mic_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
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
        return _ChatBubble(message: message, onRetry: () => onRetry(message.id));
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
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = message.isUser ? _userBubble : _assistantBubble;
    final textColor = message.isUser ? Colors.white : Colors.white;
    final isStreaming = !message.isUser && message.isStreaming;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.message, style: TextStyle(color: textColor, fontSize: 15, height: 1.4)),
              if (isStreaming) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                    SizedBox(width: 6),
                    Text('Streaming...', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ] else if (message.isPending || message.isFailed) ...[
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
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
          SizedBox(width: 6),
          Text('Sending...', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
        const SizedBox(width: 6),
        const Text('Failed', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _VoiceStatusBar extends StatelessWidget {
  const _VoiceStatusBar({required this.state, required this.onStop, required this.onCancel});

  final VoiceChatState state;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  static bool shouldShow(VoiceChatState state) {
    return state.isRecording ||
        state.isProcessing ||
        state.isPlaying ||
        (state.userTranscription?.isNotEmpty ?? false) ||
        (state.aiResponse?.isNotEmpty ?? false) ||
        (state.errorMessage?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = state.errorMessage?.isNotEmpty ?? false;
    final active = state.isRecording || state.isProcessing || state.isPlaying;
    final iconColor = hasError
        ? Colors.redAccent
        : state.isRecording
        ? Colors.redAccent
        : state.isPlaying
        ? Colors.lightGreenAccent
        : Colors.white70;
    final icon = state.isRecording
        ? Icons.mic
        : state.isProcessing
        ? Icons.cloud_sync
        : state.isPlaying
        ? Icons.graphic_eq
        : hasError
        ? Icons.error_outline
        : Icons.mic_none;
    final title = state.isRecording
        ? 'Listening...'
        : state.isProcessing
        ? 'Processing voice...'
        : state.isPlaying
        ? 'Playing reply...'
        : hasError
        ? 'Voice chat issue'
        : 'Voice chat ready';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasError ? Colors.redAccent.withOpacity(0.12) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasError ? Colors.redAccent.withOpacity(0.6) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (active || hasError)
                TextButton(
                  onPressed: hasError ? onCancel : onStop,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  child: Text(hasError ? 'Dismiss' : 'Stop'),
                ),
            ],
          ),
          if (state.userTranscription?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            _VoiceLine(label: 'You', text: state.userTranscription!),
          ],
          if (state.aiResponse?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            _VoiceLine(label: 'AI', text: state.aiResponse!),
          ],
        ],
      ),
    );
  }
}

class _VoiceLine extends StatelessWidget {
  const _VoiceLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
          ),
        ),
      ],
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
        children: [
          const SizedBox(height: 10),
          const Text(
            'Say hello to start chatting',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
