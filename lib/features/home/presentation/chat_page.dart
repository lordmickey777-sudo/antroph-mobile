import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/widgets/face_canvas.dart';
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

      ref.listen<VoiceChatState>(voiceChatControllerProvider, (previous, next) {
        final prevErr = previous?.errorMessage;
        final err = next.errorMessage;
        if (!mounted || err == null || err.isEmpty || err == prevErr) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(err),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
            ),
          );
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
    final hasFace = voiceChatState.currentFaceBitmap != null && voiceChatState.currentFaceBitmap!.isNotEmpty;
    final faceSize = math.max(140.0, widget.size.width * 0.4);
    final isBusy = voiceChatState.isRecording || voiceChatState.isProcessing || voiceChatState.isConnecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            height: widget.size.height * 0.36,
            child: Center(
              child: hasFace
                  ? FaceCanvas(
                      bitmap: voiceChatState.currentFaceBitmap,
                      timestampMs: voiceChatState.faceTimestampMs,
                      size: faceSize,
                      backgroundColor: Colors.transparent,
                      showFrame: false,
                    )
                  : ExpressionDisplay(
                      expression: voiceChatState.currentExpression,
                      size: faceSize,
                      showGlow: false,
                    ),
            ),
          ),
        ),

        if (isBusy) ...[
          const SizedBox(height: 12),
          const Center(
            child: CupertinoActivityIndicator(radius: 12, color: Colors.white70),
          ),
        ] else if (voiceChatState.isPlaying) ...[
          const SizedBox(height: 12),
          const Center(child: Icon(Icons.graphic_eq, color: Colors.greenAccent, size: 22)),
        ],

        const Spacer(),

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
        SizedBox(height: widget.size.height * 0.12),
      ],
    );
  }
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
