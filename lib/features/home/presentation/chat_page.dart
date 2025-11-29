import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/expression_widgets.dart';
import 'package:antroph_mobile/features/home/widgets/permission_modal.dart';
import 'package:antroph_mobile/features/story/models/story_playlists_models.dart';
import 'package:antroph_mobile/features/story/providers/story_playlists_provider.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

const _chatBg = Color(0xFF121516);

class ChatPage extends StatelessWidget {
  const ChatPage({super.key, this.storyTitle});

  final String? storyTitle;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _chatBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TypographyText(
          storyTitle ?? 'Chat',
          variant: TypographyVariant.h3,
          color: Colors.white,
        ),
      ),
      body: SafeArea(child: _InteractContent(size: size, showCollectionsChips: true)),
    );
  }
}

class _InteractContent extends ConsumerStatefulWidget {
  const _InteractContent({required this.size, required this.showCollectionsChips});

  final Size size;
  final bool showCollectionsChips;

  @override
  ConsumerState<_InteractContent> createState() => _InteractContentState();
}

class _InteractContentState extends ConsumerState<_InteractContent> {
  @override
  void initState() {
    super.initState();
    // Listen for permission modal state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(voiceChatControllerProvider.select((state) => state.permissionDialog), (
        previous,
        next,
      ) {
        if (!mounted || next == PermissionDialogType.none) {
          return;
        }
        _showPermissionDialog(next);
      });
    });
  }

  Future<void> _showPermissionDialog(PermissionDialogType type) async {
    final controller = ref.read(voiceChatControllerProvider.notifier);
    if (type == PermissionDialogType.education) {
      final continueRequest = await MicrophoneEducationDialog.show(context) ?? false;
      controller.handleEducationDialogResult(continueRequest);
    } else if (type == PermissionDialogType.settings) {
      await MicrophonePermissionModal.show(context);
      controller.dismissPermissionDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceChatState = ref.watch(voiceChatControllerProvider);
    final voiceChatController = ref.read(voiceChatControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _VoiceStatusCard(state: voiceChatState),
        ),
        const SizedBox(height: 20),

        // AI Response or Status Text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: widget.size.height * 0.24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: LayoutBuilder(
                key: ValueKey(voiceChatState.aiResponse ?? voiceChatState.isRecording),
                builder: (context, constraints) {
                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: TypographyText(
                            _getStatusText(voiceChatState),
                            variant: TypographyVariant.h2,
                            textAlign: TextAlign.center,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Error message display
        if (voiceChatState.errorMessage != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      voiceChatState.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    onPressed: () => voiceChatController.clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ],

        const Spacer(),

        // Recording/Processing indicator
        if (voiceChatState.isRecording)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Recording...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          )
        else if (voiceChatState.isProcessing || voiceChatState.isConnecting)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    voiceChatState.isConnecting ? 'Connecting...' : 'Processing...',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  )
                ],
              ),
            ),
          )
        else if (voiceChatState.isPlaying)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Streaming reply...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Voice Record Button
        Center(
          child: VoiceRecordButton(
            isRecording: voiceChatState.isRecording,
            onPressed: voiceChatState.isProcessing || voiceChatState.isPlaying
                ? null
                : () async {
                    if (voiceChatState.isRecording) {
                      await voiceChatController.stopRecordingAndSend();
                    } else {
                      await voiceChatController.startRecording();
                    }
                  },
            size: 75,
          ),
        ),
        SizedBox(height: widget.size.height * 0.15),
      ],
    );
  }

  String _getStatusText(VoiceChatState state) {
    if (state.isRecording) {
      return 'Listening...';
    } else if (state.isConnecting) {
      return 'Connecting to the voice service...';
    } else if (state.isProcessing) {
      return 'Transcribing and thinking...';
    } else if (state.aiResponse != null) {
      return state.aiResponse!;
    }
    return 'Tap the mic and speak to stream the reply.';
  }
}

class _VoiceStatusCard extends StatelessWidget {
  const _VoiceStatusCard({required this.state});

  final VoiceChatState state;

  @override
  Widget build(BuildContext context) {
    final meta = _resolveStatus();
    final prompt =
        state.aiResponse ?? 'Send a quick clip and the backend will stream the TTS reply over websocket.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: meta.color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, color: meta.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  meta.label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (state.isProcessing || state.isConnecting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            prompt,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.3),
          ),
          if (state.userTranscription != null && state.userTranscription!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Heard: ${state.userTranscription}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          if (state.audioFormats.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Server formats: ${state.audioFormats.join(", ")}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  _VoiceStatusMeta _resolveStatus() {
    if (state.isRecording) {
      return _VoiceStatusMeta('Listening for your voice', Icons.mic, Colors.redAccent);
    }
    if (state.isConnecting) {
      return _VoiceStatusMeta('Connecting to /ws/voice', Icons.wifi_tethering, Colors.blueAccent);
    }
    if (state.isProcessing) {
      return _VoiceStatusMeta('Transcribing & thinking', Icons.auto_awesome, Colors.blueAccent);
    }
    if (state.isPlaying) {
      return _VoiceStatusMeta('Streaming the reply', Icons.volume_up, Colors.greenAccent);
    }
    return _VoiceStatusMeta('Ready for voice upload', Icons.chat_bubble_outline, Colors.white70);
  }
}

class _VoiceStatusMeta {
  const _VoiceStatusMeta(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

// ignore: unused_element
class _LoadingChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (_, __) => Container(
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1D1F),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 120, height: 14),
              SizedBox(height: 10),
              ShimmerBox(width: 160, height: 10),
            ],
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 4,
      ),
    );
  }
}

class PlaylistChip extends ConsumerWidget {
  const PlaylistChip({super.key, required this.playlist});

  final PlaylistDto playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = ref
        .watch(playlistDetailProvider(playlist.id))
        .when(
          loading: () => _collectionSubtitleFromCount(playlist.storyCount),
          error: (_, __) => _collectionSubtitleFromCount(playlist.storyCount),
          data: (detail) {
            final titles = detail.stories
                .map((s) => s.title)
                .where((title) => title.isNotEmpty)
                .take(2)
                .toList();
            if (titles.isEmpty) return _collectionSubtitleFromCount(playlist.storyCount);
            return titles.join(', ');
          },
        );

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TypographyText(playlist.name, variant: TypographyVariant.body1, color: Colors.white),
          const SizedBox(height: 4),
          TypographyText(
            subtitle,
            variant: TypographyVariant.body2,
            color: Colors.white70,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

String _collectionSubtitleFromCount(int count) {
  if (count <= 0) return 'No stories yet';
  final label = count == 1 ? 'story' : 'stories';
  return '$count $label';
}
