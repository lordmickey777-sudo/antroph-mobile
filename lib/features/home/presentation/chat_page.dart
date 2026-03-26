import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antroph_mobile/core/navigation/app_route_observer.dart';
import 'package:antroph_mobile/core/responsive/responsive.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

import 'package:antroph_mobile/features/home/models/expression_models.dart';
import 'package:antroph_mobile/features/home/models/realtime_voice_bridge_models.dart';
import 'package:antroph_mobile/features/home/providers/chat_provider.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/providers/story_providers.dart';
import 'package:antroph_mobile/features/home/widgets/permission_modal.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/voice_activity_face.dart';
import 'package:antroph_mobile/widgets/app_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/features/home/presentation/chat_bottom_sheet.dart';
import 'package:antroph_mobile/features/story/models/story_detail.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';

const _accent = Color(0xFF9CC6FF);

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    this.storyTitle,
    this.storyId,
    this.storySessionId,
    this.mascotConfig,
    this.storySubtitle,
    this.storyImage,
    this.isAddedToPlaylist = false,
  });

  final String? storyTitle;

  /// If provided, starts a new story voice session with this story ID
  final String? storyId;

  /// If provided, resumes an existing story voice session
  final String? storySessionId;
  final MascotConfig? mascotConfig;
  final String? storySubtitle;
  final String? storyImage;
  final bool isAddedToPlaylist;

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

  void _openChatSheet(
    BuildContext context,
    VoiceChatController voiceController,
    VoiceChatState voiceState,
  ) {
    final wasMuted = voiceState.isMuted;
    // Mute voice and stop playback when entering text chat
    if (!wasMuted) {
      voiceController.toggleMute();
    }
    voiceController.stopPlayback();

    showAppBottomSheet(
      context: context,
      backgroundColor: context.backgroundColor,
      builder: (ctx, scrollController) =>
          ChatBottomSheet(scrollController: scrollController),
    ).then((_) {
      // Restore mute state when sheet closes
      if (!wasMuted && mounted) {
        ref.read(voiceChatControllerProvider.notifier).toggleMute();
      }
    });
  }

  void _openStoryDetails(BuildContext context, StoryDetailDto? detail) {
    final storyId = widget.storyId;
    if (storyId == null) return;

    showAppBottomSheet(
      context: context,
      builder: (_, scrollController) => StorySheetContent(
        storyId: storyId,
        title: (detail?.title.isNotEmpty ?? false)
            ? detail!.title
            : (widget.storyTitle?.isNotEmpty ?? false)
            ? widget.storyTitle!
            : 'Story',
        subtitle: (detail?.description.isNotEmpty ?? false)
            ? detail!.description
            : (widget.storySubtitle ?? ''),
        imageAsset: (widget.storyImage?.isNotEmpty ?? false)
            ? widget.storyImage!
            : 'assets/images/default.png',
        mascotConfig: widget.mascotConfig ?? detail?.effectiveMascot,
        isAdded: widget.isAddedToPlaylist,
        scrollController: scrollController,
      ),
    );
  }

  void _precacheMascot(MascotConfig mascot) {
    final mascotId = mascot.id.trim();
    if (mascotId.isEmpty || mascotId == _lastPrecachedMascotId) return;
    final riveRef = mascot.riveAssetUrl.trim();
    if (riveRef.isEmpty || riveRef.startsWith('assets/')) return;
    _lastPrecachedMascotId = mascotId;
    unawaited(() async {
      try {
        await ref.read(riveRegistryServiceProvider).cacheMascotConfig(mascot);
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
    final storyDetail = widget.storyId != null
        ? ref.watch(storyDetailProvider(widget.storyId!)).asData?.value
        : null;
    MascotConfig? mascotConfig = widget.mascotConfig;
    final detailedMascot = storyDetail?.effectiveMascot;
    if (widget.storyId != null &&
        (mascotConfig == null ||
            ((detailedMascot?.localAssetPath ?? '').trim().isNotEmpty))) {
      mascotConfig = detailedMascot;
    }
    if (mascotConfig != null) {
      _precacheMascot(mascotConfig);
    }
    final isDark = context.isDarkMode;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
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
            if (widget.storyId != null)
              IconButton(
                onPressed: () => _openStoryDetails(context, storyDetail),
                icon: const Icon(CupertinoIcons.info_circle),
                color: context.primaryTextColor,
                tooltip: 'Story details',
              ),
            _ChatButton(
              onTap: () => _openChatSheet(context, voiceController, voiceState),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: ChatScreen(
            isStoryMode: widget.isStoryMode,
            mascotConfig: mascotConfig,
            expressionStream: voiceController.mascotExpressionStream,
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.isStoryMode = false,
    this.mascotConfig,
    this.expressionStream,
  });

  final bool isStoryMode;
  final MascotConfig? mascotConfig;
  final Stream<MascotExpressionEvent>? expressionStream;

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
        // Use centralized responsive utilities for consistent breakpoints
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

class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Open chat',
      icon: Icon(
        Icons.chat_bubble_outline_rounded,
        color: context.primaryTextColor,
        size: 22,
      ),
    );
  }
}
