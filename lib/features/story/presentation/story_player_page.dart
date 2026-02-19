import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antroph_mobile/features/home/presentation/chat_page.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/story/models/story_playlists_models.dart';
import 'package:antroph_mobile/features/story/providers/story_socket_provider.dart';
import 'package:antroph_mobile/widgets/app_button.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class StoryPlayerPage extends ConsumerStatefulWidget {
  const StoryPlayerPage({super.key, required this.story});

  final PlaylistStoryDto story;

  @override
  ConsumerState<StoryPlayerPage> createState() => _StoryPlayerPageState();
}

class _StoryPlayerPageState extends ConsumerState<StoryPlayerPage> {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(storySocketProvider.notifier)
          .startStory(
            storyId: widget.story.storyId,
            storyTitle: widget.story.title,
          );
    });
  }

  @override
  void dispose() {
    ref.read(storySocketProvider.notifier).endStory();
    _textController.dispose();
    super.dispose();
  }

  void _openVoiceMode(BuildContext context) {
    // End the current text-based story session before switching to voice mode
    ref.read(storySocketProvider.notifier).endStory();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          storyTitle: widget.story.title,
          storyId: widget.story.storyId,
          mascotConfig: widget.story.mascot,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storySocketProvider);
    final notifier = ref.read(storySocketProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TypographyText(
          widget.story.title,
          variant: TypographyVariant.h2,
          color: Colors.white,
        ),
        actions: [
          IconButton(
            onPressed: () => _openVoiceMode(context),
            icon: const Icon(Icons.mic, color: Colors.white),
            tooltip: 'Voice Mode',
          ),
          TextButton(
            onPressed: () => notifier.endStory(),
            child: const TypographyText(
              'End',
              variant: TypographyVariant.body2,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusRow(state: state, onRetry: notifier.retryLastStart),
            const SizedBox(height: 12),
            _SessionInfo(state: state),
            const SizedBox(height: 12),
            _NodeCard(state: state),
            if (state.choices.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ChoicesCard(state: state, onSelect: notifier.sendChoice),
            ],
            if (state.currentAudio != null) ...[
              const SizedBox(height: 12),
              _AudioCard(state: state),
            ],
            const SizedBox(height: 12),
            _LogList(state: state),
            const SizedBox(height: 16),
            _TextInput(
              controller: _textController,
              onSend: (text) {
                notifier.sendUserText(text);
                _textController.clear();
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state, required this.onRetry});

  final StorySocketState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = state.phase == StoryWsPhase.error || state.error != null;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _phaseDot(state.phase),
              const SizedBox(width: 8),
              TypographyText(
                _phaseLabel(state.phase),
                variant: TypographyVariant.body2,
                color: Colors.white,
              ),
            ],
          ),
        ),
        const Spacer(),
        if (hasError)
          AppButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.actionButtonBackground,
              foregroundColor: context.actionButtonForeground,
              elevation: 0,
            ),
            child: TypographyText(
              'Retry',
              variant: TypographyVariant.body2,
              color: context.actionButtonForeground,
            ),
          ),
      ],
    );
  }

  Widget _phaseDot(StoryWsPhase phase) {
    Color color;
    switch (phase) {
      case StoryWsPhase.connecting:
      case StoryWsPhase.authenticating:
        color = Colors.orangeAccent;
        break;
      case StoryWsPhase.running:
      case StoryWsPhase.awaitingChoice:
      case StoryWsPhase.streamingAudio:
        color = Colors.greenAccent;
        break;
      case StoryWsPhase.error:
        color = Colors.redAccent;
        break;
      default:
        color = Colors.white54;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _phaseLabel(StoryWsPhase phase) {
    switch (phase) {
      case StoryWsPhase.connecting:
        return 'Connecting';
      case StoryWsPhase.authenticating:
        return 'Authenticating';
      case StoryWsPhase.starting:
        return 'Starting story';
      case StoryWsPhase.awaitingChoice:
        return 'Awaiting choice';
      case StoryWsPhase.streamingAudio:
        return 'Playing audio';
      case StoryWsPhase.running:
        return 'Live';
      case StoryWsPhase.error:
        return 'Error';
      case StoryWsPhase.closed:
        return 'Closed';
      default:
        return 'Idle';
    }
  }
}

class _SessionInfo extends StatelessWidget {
  const _SessionInfo({required this.state});

  final StorySocketState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TypographyText(
            'Session',
            variant: TypographyVariant.body1,
            color: Colors.white,
          ),
          const SizedBox(height: 6),
          TypographyText(
            state.sessionId ?? 'Awaiting ack…',
            variant: TypographyVariant.body2,
            color: Colors.white70,
          ),
          if (state.resumeToken != null) ...[
            const SizedBox(height: 6),
            TypographyText(
              'Resume token: ${state.resumeToken}',
              variant: TypographyVariant.body2,
              color: Colors.white54,
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 10),
            TypographyText(
              state.error!,
              variant: TypographyVariant.body2,
              color: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.state});

  final StorySocketState state;

  @override
  Widget build(BuildContext context) {
    final node = state.currentNode;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TypographyText(
            node?.nodeType.toUpperCase() ?? 'Node',
            variant: TypographyVariant.body1,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          TypographyText(
            node?.text.isNotEmpty == true
                ? node!.text
                : 'Waiting for story content…',
            variant: TypographyVariant.body2,
            color: Colors.white70,
            height: 1.4,
          ),
          if (node?.audioExpected == true) ...[
            const SizedBox(height: 8),
            TypographyText(
              'Audio expected (${node?.audioFormat ?? 'unknown'})',
              variant: TypographyVariant.body2,
              color: Colors.white54,
            ),
          ],
          if (state.lastTranscript != null) ...[
            const SizedBox(height: 10),
            TypographyText(
              state.lastTranscriptIsFinal
                  ? 'Transcript (final)'
                  : 'Transcript (partial)',
              variant: TypographyVariant.body2,
              color: Colors.white,
            ),
            const SizedBox(height: 4),
            TypographyText(
              state.lastTranscript!,
              variant: TypographyVariant.body2,
              color: Colors.white70,
            ),
          ],
          if (state.latestExpression != null) ...[
            const SizedBox(height: 10),
            TypographyText(
              'Expression: ${state.latestExpression!.name}',
              variant: TypographyVariant.body2,
              color: Colors.white70,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoicesCard extends StatelessWidget {
  const _ChoicesCard({required this.state, required this.onSelect});

  final StorySocketState state;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2224),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TypographyText(
            'Choices',
            variant: TypographyVariant.body1,
            color: Colors.white,
          ),
          const SizedBox(height: 10),
          for (final choice in state.choices) ...[
            AppButton(
              onPressed: () => onSelect(choice.choiceId),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.actionButtonBackground,
                foregroundColor: context.actionButtonForeground,
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TypographyText(
                      choice.label,
                      variant: TypographyVariant.body2,
                      color: context.actionButtonForeground,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.actionButtonForeground,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AudioCard extends StatelessWidget {
  const _AudioCard({required this.state});

  final StorySocketState state;

  @override
  Widget build(BuildContext context) {
    final audio = state.currentAudio!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TypographyText(
            'Audio stream',
            variant: TypographyVariant.body1,
            color: Colors.white,
          ),
          const SizedBox(height: 6),
          TypographyText(
            'ID: ${audio.audioId}',
            variant: TypographyVariant.body2,
            color: Colors.white70,
          ),
          TypographyText(
            'Format: ${audio.format}, length: ${audio.lengthMs} ms',
            variant: TypographyVariant.body2,
            color: Colors.white54,
          ),
          if (audio.sampleRate != null)
            TypographyText(
              'Sample rate: ${audio.sampleRate}',
              variant: TypographyVariant.body2,
              color: Colors.white54,
            ),
          if (audio.expressions.isNotEmpty) ...[
            const SizedBox(height: 8),
            TypographyText(
              'Expressions: ${audio.expressions.length}',
              variant: TypographyVariant.body2,
              color: Colors.white70,
            ),
          ],
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.state});

  final StorySocketState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.log.reversed.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TypographyText(
            'Events',
            variant: TypographyVariant.body1,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const TypographyText(
              'Waiting for events…',
              variant: TypographyVariant.body2,
              color: Colors.white54,
            )
          else
            for (final entry in entries) ...[
              TypographyText(
                entry.label,
                variant: TypographyVariant.body2,
                color: Colors.white70,
              ),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final void Function(String text) onSend;

  @override
  Widget build(BuildContext context) {
    final textColor = context.primaryTextColor;
    final hintColor = context.tertiaryTextColor;
    final borderColor = context.dividerColor;
    final backgroundColor = context.inputBackground;
    final sendBg = context.actionButtonBackground;
    final sendFg = context.actionButtonForeground;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Send text to the story',
                hintStyle: TextStyle(color: hintColor),
                border: InputBorder.none,
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            onPressed: () => onSend(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: sendBg,
              foregroundColor: sendFg,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Icon(Icons.send, color: sendFg, size: 18),
          ),
        ],
      ),
    );
  }
}
