import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/navigation/app_route_observer.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

import 'package:antroph_mobile/features/home/models/chat_models.dart';
import 'package:antroph_mobile/features/home/models/realtime_voice_bridge_models.dart';
import 'package:antroph_mobile/features/home/providers/chat_provider.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/features/home/widgets/permission_modal.dart';
import 'package:antroph_mobile/features/profile/providers/profile_controller.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/voice_activity_face.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/toast.dart';

// Dark mode colors
const _chatBgDark = Color(0xFF0B1118);
const _userBubbleDark = Color(0xFF1C2533);
const _assistantBubbleDark = Color(0xFF0F1720);

// Light mode colors
const _chatBgLight = Color(0xFFF5F5F7);
const _userBubbleLight = Color(0xFF007AFF);
const _assistantBubbleLight = Color(0xFFE9E9EB);

const _accent = Color(0xFF9CC6FF);

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    this.storyTitle,
    this.storyId,
    this.storySessionId,
    this.mascotConfig,
  });

  final String? storyTitle;

  /// If provided, starts a new story voice session with this story ID
  final String? storyId;

  /// If provided, resumes an existing story voice session
  final String? storySessionId;
  final MascotConfig? mascotConfig;

  /// Whether this chat page is in story mode
  bool get isStoryMode => storyId != null || storySessionId != null;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<void>? _modalRoute;
  bool _storySessionStarted = false;
  String? _lastPrecachedMascotId;
  // Store reference for safe use in dispose()
  VoiceChatController? _voiceController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Save controller reference for safe disposal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceController = ref.read(voiceChatControllerProvider.notifier);
      // Auto-start listening when entering the page
      _autoStartListening();
    });
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

  /// Auto-start listening when entering chat page
  Future<void> _autoStartListening() async {
    // Small delay to let the page settle
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final voiceState = ref.read(voiceChatControllerProvider);

    // Story mode auto-starts via _scheduleAutoListen after AI intro
    if (widget.isStoryMode) return;

    // Regular mode: start recording immediately
    if (!voiceState.isBusy && !voiceState.isMuted) {
      voiceController.startRecording();
    }
  }

  void _precacheMascot(MascotConfig mascot) {
    final mascotId = mascot.id.trim();
    if (mascotId.isEmpty || mascotId == _lastPrecachedMascotId) return;
    final riveRef = mascot.riveAssetUrl.trim();
    if (riveRef.isEmpty || riveRef.startsWith('assets/')) return;
    _lastPrecachedMascotId = mascotId;
    unawaited(() async {
      try {
        await ref.read(mascotCacheServiceProvider).cacheMascot(mascot);
      } catch (_) {
        // Cache warmup is best effort.
      }
    }());
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
    // Use saved reference to avoid using ref after unmount
    if (_voiceController != null) {
      if (widget.isStoryMode) {
        _voiceController!.pauseStorySession();
        _voiceController!.endStorySession();
      } else {
        _voiceController!.stopPlayback();
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
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
    final voiceState = ref.watch(voiceChatControllerProvider);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);
    final chatState = widget.isStoryMode
        ? null
        : ref.watch(chatControllerProvider);
    MascotConfig? mascotConfig = widget.mascotConfig;
    if (mascotConfig == null && widget.storyId != null) {
      final detailAsync = ref.watch(storyDetailProvider(widget.storyId!));
      mascotConfig = detailAsync.asData?.value.effectiveMascot;
    }
    if (mascotConfig != null) {
      _precacheMascot(mascotConfig);
    }
    final userProfile = ref.watch(profileControllerProvider).value;
    final userName = userProfile?.displayName ?? userProfile?.username;
    final headline = _chatHeadline(chatState, voiceState);
    final isDark = context.isDarkMode;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: isDark ? _chatBgDark : _chatBgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 76,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: TypographyText(
            widget.storyTitle ?? 'Voice chat',
            variant: TypographyVariant.h4,
            color: context.primaryTextColor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          actions: [
            _TranscriptButton(
              voiceState: voiceState,
              headline: headline,
              userName: userName,
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
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          child: SafeArea(
            child: ChatScreen(
              isStoryMode: widget.isStoryMode,
              mascotConfig: mascotConfig,
            ),
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.isStoryMode = false, this.mascotConfig});

  final bool isStoryMode;
  final MascotConfig? mascotConfig;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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

  /// Build chat messages from voice conversation history + live current turn.
  List<ChatMessageModel> _buildVoiceMessages(VoiceChatState voiceState) {
    final messages = <ChatMessageModel>[];
    // Add completed conversation history
    for (var i = 0; i < voiceState.conversationHistory.length; i++) {
      final item = voiceState.conversationHistory[i];
      if (item.content.isEmpty) continue;
      messages.add(ChatMessageModel(
        id: 'voice_$i',
        role: item.isUser ? ChatRole.user : ChatRole.assistant,
        message: item.content,
        ts: DateTime.now(),
      ));
    }
    // Add live current turn (not yet saved to history)
    if (voiceState.userTranscription?.isNotEmpty ?? false) {
      messages.add(ChatMessageModel(
        id: 'voice_live_user',
        role: ChatRole.user,
        message: voiceState.userTranscription!,
        ts: DateTime.now(),
      ));
    }
    if (voiceState.aiResponse?.isNotEmpty ?? false) {
      messages.add(ChatMessageModel(
        id: 'voice_live_ai',
        role: ChatRole.assistant,
        message: voiceState.aiResponse!,
        ts: DateTime.now(),
        streaming: voiceState.isProcessing || voiceState.isPlaying,
      ));
    }
    return messages;
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

    // Only watch chatControllerProvider in non-story mode to avoid double WebSocket connection
    final ChatState? chatState = widget.isStoryMode
        ? null
        : ref.watch(chatControllerProvider);
    final ChatController? chatController = widget.isStoryMode
        ? null
        : ref.read(chatControllerProvider.notifier);
    final voiceState = ref.watch(voiceChatControllerProvider);
    final voiceController = ref.read(voiceChatControllerProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use centralized responsive utilities for consistent breakpoints
        final horizontalPadding = AppPadding.horizontal.fromConstraints(
          constraints,
        );
        final faceSize = (constraints.maxWidth * 0.75).clamp(250.0, 380.0);
        final availableWidth = math.max(
          0,
          constraints.maxWidth - horizontalPadding * 2,
        );
        final bubbleMaxWidth = math.min(460.0, availableWidth * 0.95);
        const bottomPadding = 200.0;

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
                  messages: widget.isStoryMode
                      ? _buildVoiceMessages(voiceState)
                      : chatState?.messages ?? const [],
                  onRetry: chatController?.retrySend,
                  bubbleMaxWidth: bubbleMaxWidth,
                  bottomPadding: bottomPadding,
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
                      onEnd: () {
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
    this.mascotConfig,
    this.onReconnect,
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onStopVoicePlayback,
    required this.faceSize,
  });

  final VoiceChatState voiceState;
  final Stream<double> aiAudioLevelStream;
  final MascotConfig? mascotConfig;
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
                  child: VoiceActivityFace(
                    levelStream: aiAudioLevelStream,
                    threshold: 0.008,
                    mascotConfig: mascotConfig,
                  ),
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
    // Show muted status when muted
    if (voice.isMuted) {
      return const _StatusData('Muted', Icons.mic_off);
    }

    // Story mode status
    if (voice.isStoryMode) {
      switch (voice.phase) {
        case RealtimeVoicePhase.connecting:
        case RealtimeVoicePhase.waitingForReady:
          return const _StatusData('Connecting', Icons.wifi);
        case RealtimeVoicePhase.ready:
          return const _StatusData('Listening', Icons.mic);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.04);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final actionColor = isDark ? Colors.white : Colors.black87;
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
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
          if (state.isDisconnected) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onReconnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                foregroundColor: actionColor,
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
              _accent.withOpacity(0.8),
              isDark
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.08),
            ],
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
              color: _accent.withOpacity(
                recording ? 0.6 : (isDark ? 0.25 : 0.18),
              ),
              blurRadius: 30,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.black.withOpacity(0.55)
                : Colors.white.withOpacity(0.9),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.12),
            ),
          ),
          child: Icon(
            recording
                ? Icons.mic
                : waiting || playing
                ? Icons.stop_rounded
                : Icons.mic_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 30,
          ),
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
    final bgColor = isMuted
        ? Colors.red
        : (isDark ? Colors.white : Colors.black87);
    final iconColor = isMuted
        ? Colors.white
        : (isDark ? Colors.black : Colors.white);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
        child: Icon(
          isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: iconColor,
          size: 28,
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
  const _ChatBubble({
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

class _TranscriptButton extends StatelessWidget {
  const _TranscriptButton({
    required this.voiceState,
    required this.headline,
    required this.onStop,
    required this.onCancel,
    this.userName,
  });

  final VoiceChatState voiceState;
  final String headline;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final String? userName;

  bool get _hasContent =>
      (voiceState.userTranscription?.isNotEmpty ?? false) ||
      (voiceState.aiResponse?.isNotEmpty ?? false) ||
      headline.trim().isNotEmpty ||
      (voiceState.errorMessage?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final hasError = voiceState.errorMessage?.isNotEmpty ?? false;
    final iconColor = hasError
        ? Colors.redAccent
        : _hasContent
        ? context.primaryTextColor
        : context.tertiaryTextColor;
    final activeBg = context.isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final inactiveBg = context.isDarkMode
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.04);
    final bgColor = hasError
        ? Colors.redAccent.withValues(alpha: 0.12)
        : _hasContent
        ? activeBg
        : inactiveBg;

    return GestureDetector(
      onTap: _hasContent ? () => _showTranscriptSheet(context) : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(
            hasError ? Icons.error_rounded : Icons.subtitles_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showTranscriptSheet(BuildContext context) {
    final hasError = voiceState.errorMessage?.isNotEmpty ?? false;
    final active =
        voiceState.isRecording ||
        voiceState.isProcessing ||
        voiceState.isPlaying;
    final title = voiceState.isRecording
        ? 'Listening...'
        : voiceState.isProcessing
        ? 'Processing voice...'
        : voiceState.isPlaying
        ? 'Playing reply...'
        : hasError
        ? 'Voice chat issue'
        : 'Transcript';

    showAppBottomSheet(
      context: context,
      builder: (context, scrollController) => _TranscriptSheetContent(
        title: title,
        hasError: hasError,
        active: active,
        voiceState: voiceState,
        headline: headline,
        userName: userName,
        onStop: onStop,
        onCancel: onCancel,
        scrollController: scrollController,
      ),
    );
  }
}

class _TranscriptSheetContent extends StatelessWidget {
  const _TranscriptSheetContent({
    required this.title,
    required this.hasError,
    required this.active,
    required this.voiceState,
    required this.headline,
    required this.userName,
    required this.onStop,
    required this.onCancel,
    required this.scrollController,
  });

  final String title;
  final bool hasError;
  final bool active;
  final VoiceChatState voiceState;
  final String headline;
  final String? userName;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final textColor = context.primaryTextColor;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
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
                    foregroundColor: hasError ? Colors.redAccent : textColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Text(hasError ? 'Dismiss' : 'Stop'),
                ),
            ],
          ),
        ),
        Divider(color: context.dividerColor, height: 1),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              if (voiceState.userTranscription?.isNotEmpty ?? false) ...[
                _TranscriptLine(
                  label: userName ?? 'You',
                  text: voiceState.userTranscription!,
                  isUser: true,
                ),
                const SizedBox(height: 16),
              ],
              if (voiceState.aiResponse?.isNotEmpty ?? false) ...[
                _TranscriptLine(label: 'Aura', text: voiceState.aiResponse!),
                const SizedBox(height: 16),
              ],
              if (headline.trim().isNotEmpty &&
                  headline != voiceState.userTranscription &&
                  headline != voiceState.aiResponse) ...[
                Text(
                  headline,
                  style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                ),
              ],
              if (hasError && voiceState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          voiceState.errorMessage!,
                          style: TextStyle(
                            color: context.secondaryTextColor,
                            fontSize: 13,
                          ),
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
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({
    required this.label,
    required this.text,
    this.isUser = false,
  });

  final String label;
  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final textColor = context.primaryTextColor;
    final isDark = context.isDarkMode;
    final userLabelColor = isDark
        ? _accent
        : Theme.of(context).colorScheme.primary;
    final assistantLabelColor = isDark ? Colors.lightGreenAccent : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isUser ? userLabelColor : assistantLabelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
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
          Text(
            '',
            style: TextStyle(color: context.secondaryTextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
