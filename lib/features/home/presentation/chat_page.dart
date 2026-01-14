import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/navigation/app_route_observer.dart';

import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/models/realtime_voice_bridge_models.dart';
import 'package:antroph_mobile/features/home/providers/chat_provider.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/permission_modal.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/voice_activity_face.dart';

const _chatBg = Color(0xFF0B1118);
const _surface = Color(0xFF111822);
const _userBubble = Color(0xFF1C2533);
const _assistantBubble = Color(0xFF0F1720);
const _accent = Color(0xFF9CC6FF);
const _pageGradient = Colors.transparent;

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    this.storyTitle,
    this.storyId,
    this.storySessionId,
  });

  final String? storyTitle;
  /// If provided, starts a new story voice session with this story ID
  final String? storyId;
  /// If provided, resumes an existing story voice session
  final String? storySessionId;

  /// Whether this chat page is in story mode
  bool get isStoryMode => storyId != null || storySessionId != null;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver, RouteAware {
  ModalRoute<void>? _modalRoute;
  bool _storySessionStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start story session if in story mode
    if (widget.isStoryMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initStorySession();
      });
    }
  }

  void _initStorySession() {
    if (_storySessionStarted) return;
    _storySessionStarted = true;

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (widget.storySessionId != null) {
      voiceController.resumeStorySession(widget.storySessionId!);
    } else if (widget.storyId != null) {
      voiceController.startStorySession(widget.storyId!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _modalRoute) {
      if (_modalRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _modalRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    if (_modalRoute != null) {
      appRouteObserver.unsubscribe(this);
    }
    // Stop voice playback and end session when leaving
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (widget.isStoryMode) {
      voiceController.pauseStorySession();
      voiceController.endStorySession();
    } else {
      voiceController.stopPlayback();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Only use chatController in non-story mode
      if (!widget.isStoryMode) {
        ref.read(chatControllerProvider.notifier).pause();
      }
      // Pause voice session to stop AI from talking in the background
      if (widget.isStoryMode) {
        voiceController.pauseStorySession();
      } else {
        voiceController.stopPlayback();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Only use chatController in non-story mode
      if (!widget.isStoryMode) {
        ref.read(chatControllerProvider.notifier).resume();
      }
      // Resume voice session if it was paused
      if (widget.isStoryMode) {
        voiceController.resumePausedSession();
      }
    }
  }

  @override
  void didPushNext() {
    // Only use chatController in non-story mode
    if (!widget.isStoryMode) {
      ref.read(chatControllerProvider.notifier).pause();
    }
    // Pause voice session when navigating to another page
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (widget.isStoryMode) {
      voiceController.pauseStorySession();
    } else {
      voiceController.stopPlayback();
    }
  }

  @override
  void didPopNext() {
    // Only use chatController in non-story mode
    if (!widget.isStoryMode) {
      ref.read(chatControllerProvider.notifier).resume();
    }
    // Resume voice session when returning to this page
    if (widget.isStoryMode) {
      ref.read(voiceChatControllerProvider.notifier).resumePausedSession();
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypographyText(
                      widget.storyTitle ?? 'Voice chat',
                      variant: TypographyVariant.h4,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(child: SafeArea(child: ChatScreen(isStoryMode: widget.isStoryMode))),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.isStoryMode = false});

  final bool isStoryMode;

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

    // Only listen to chatControllerProvider errors in non-story mode
    // In story mode, we only use voiceChatControllerProvider to avoid double WebSocket connections
    if (!widget.isStoryMode) {
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
    }

    // Only watch chatControllerProvider in non-story mode to avoid double WebSocket connection
    final ChatState? chatState = widget.isStoryMode ? null : ref.watch(chatControllerProvider);
    final ChatController? chatController = widget.isStoryMode ? null : ref.read(chatControllerProvider.notifier);
    final voiceState = ref.watch(voiceChatControllerProvider);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final headline = _chatHeadline(chatState, voiceState);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 900
            ? 40.0
            : constraints.maxWidth > 600
            ? 32.0
            : 16.0;
        final faceSize = (constraints.maxWidth * 0.75).clamp(250.0, 380.0);
        final availableWidth = math.max(0, constraints.maxWidth - horizontalPadding * 2);
        final bubbleMaxWidth = math.min(460.0, availableWidth * 0.95);
        const bottomPadding = 200.0;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 4),
              child: _Header(
                voiceState: voiceState,
                aiAudioLevelStream: voiceController.aiAudioLevelStream,
                onReconnect: chatController?.forceReconnect,
                onStartVoice: voiceController.startRecording,
                onStopVoice: voiceController.stopRecordingAndSend,
                onStopVoicePlayback: voiceController.stopPlayback,
                faceSize: faceSize,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: ChatList(
                  messages: chatState?.messages ?? const [],
                  onRetry: chatController?.retrySend,
                  bubbleMaxWidth: bubbleMaxWidth,
                  bottomPadding: bottomPadding,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TranscriptButton(
                      voiceState: voiceState,
                      headline: headline,
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
                    const SizedBox(width: 24),
                    _HeroMicButton(
                      voiceState: voiceState,
                      onStart: voiceController.startRecording,
                      onStop: voiceController.stopRecordingAndSend,
                      onStopPlayback: voiceController.stopPlayback,
                    ),
                    const SizedBox(width: 24 + 48),
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

String _chatHeadline(ChatState? chat, VoiceChatState voice) {
  if (voice.isRecording) return 'Listening';
  if (voice.userTranscription?.isNotEmpty ?? false) {
    return voice.userTranscription!;
  }
  if (voice.aiResponse?.isNotEmpty ?? false) {
    return voice.aiResponse!;
  }
  if (chat != null && chat.messages.isNotEmpty) {
    return chat.messages.last.message;
  }
  return '';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.voiceState,
    required this.aiAudioLevelStream,
    this.onReconnect,
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onStopVoicePlayback,
    required this.faceSize,
  });

  final VoiceChatState voiceState;
  final Stream<double> aiAudioLevelStream;
  final VoidCallback? onReconnect;
  final VoidCallback onStartVoice;
  final VoidCallback onStopVoice;
  final VoidCallback onStopVoicePlayback;
  final double faceSize;

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
                  child: VoiceActivityFace(levelStream: aiAudioLevelStream, threshold: 0.008),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Expanded(
                //   child: Align(
                //     alignment: Alignment.centerLeft,
                //     child: _ConnectionChip(
                //       state: state,
                //       onReconnect: onReconnect,
                //     ),
                //   ),
                // ),
                const SizedBox(width: 12),
                _StatusPill(label: status.label, icon: status.icon),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _StatusData _voiceStatus(VoiceChatState voice) {
    // Story mode status
    if (voice.isStoryMode) {
      switch (voice.phase) {
        case RealtimeVoicePhase.connecting:
        case RealtimeVoicePhase.waitingForReady:
          return const _StatusData('Connecting', Icons.wifi);
        case RealtimeVoicePhase.ready:
          return const _StatusData('Story Ready', Icons.auto_stories);
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
    // Regular voice chat status
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
    final canRecord = !recording && !waiting && !playing;
    final gradient = LinearGradient(
      colors: recording
          ? [Colors.white, _accent]
          : [_accent.withOpacity(0.8), Colors.white.withOpacity(0.2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      // Tap to toggle recording or stop playback
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
                ? Icons.mic
                : waiting || playing
                    ? Icons.stop_rounded
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
  const ChatList({
    super.key,
    required this.messages,
    this.onRetry,
    this.bubbleMaxWidth = 360,
    this.bottomPadding = 160,
  });

  final List<ChatMessageModel> messages;
  final void Function(String messageId)? onRetry;
  final double bubbleMaxWidth;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyState();
    }
    return ListView.separated(
      reverse: true,
      padding: EdgeInsets.only(top: 12, bottom: bottomPadding),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return _ChatBubble(
          message: message,
          onRetry: () => onRetry?.call(message.id),
          maxWidth: bubbleMaxWidth,
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onRetry, required this.maxWidth});

  final ChatMessageModel message;
  final VoidCallback onRetry;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = message.isUser ? _userBubble : _assistantBubble;
    final textColor = message.isUser ? Colors.white : Colors.white;
    final isStreaming = !message.isUser && message.isStreaming;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18)),
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

class _TranscriptButton extends StatelessWidget {
  const _TranscriptButton({
    required this.voiceState,
    required this.headline,
    required this.onStop,
    required this.onCancel,
  });

  final VoiceChatState voiceState;
  final String headline;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  bool get _hasContent =>
      (voiceState.userTranscription?.isNotEmpty ?? false) ||
      (voiceState.aiResponse?.isNotEmpty ?? false) ||
      headline.trim().isNotEmpty ||
      (voiceState.errorMessage?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final hasError = voiceState.errorMessage?.isNotEmpty ?? false;

    return GestureDetector(
      onTap: _hasContent ? () => _showTranscriptSheet(context) : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _hasContent
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: hasError
                ? Colors.redAccent.withOpacity(0.6)
                : _hasContent
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Icon(
          hasError ? Icons.error_outline : Icons.chat_bubble_outline,
          color: hasError
              ? Colors.redAccent
              : _hasContent
                  ? Colors.white
                  : Colors.white38,
          size: 22,
        ),
      ),
    );
  }

  void _showTranscriptSheet(BuildContext context) {
    final hasError = voiceState.errorMessage?.isNotEmpty ?? false;
    final active = voiceState.isRecording || voiceState.isProcessing || voiceState.isPlaying;
    final title = voiceState.isRecording
        ? 'Listening...'
        : voiceState.isProcessing
            ? 'Processing voice...'
            : voiceState.isPlaying
                ? 'Playing reply...'
                : hasError
                    ? 'Voice chat issue'
                    : 'Transcript';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (active || hasError)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (hasError) {
                          onCancel();
                        } else {
                          onStop();
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: hasError ? Colors.redAccent : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(hasError ? 'Dismiss' : 'Stop'),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  if (voiceState.userTranscription?.isNotEmpty ?? false) ...[
                    _TranscriptLine(label: 'You', text: voiceState.userTranscription!),
                    const SizedBox(height: 16),
                  ],
                  if (voiceState.aiResponse?.isNotEmpty ?? false) ...[
                    _TranscriptLine(label: 'AI', text: voiceState.aiResponse!),
                    const SizedBox(height: 16),
                  ],
                  if (headline.trim().isNotEmpty &&
                      headline != voiceState.userTranscription &&
                      headline != voiceState.aiResponse) ...[
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (hasError && voiceState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              voiceState.errorMessage!,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: label == 'You' ? _accent : Colors.lightGreenAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
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
          const Text('', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}
