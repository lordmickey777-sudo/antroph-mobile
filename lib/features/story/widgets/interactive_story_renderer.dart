import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/theme_provider.dart';
import '../models/interactive_story_models.dart';

class InteractiveStoryRenderer extends StatelessWidget {
  const InteractiveStoryRenderer({
    super.key,
    required this.session,
    required this.onChoice,
    required this.onQuizAnswer,
    this.pendingKeys = const <String>{},
  });

  final InteractiveSessionState session;
  final ValueChanged<String> onChoice;
  final ValueChanged<String> onQuizAnswer;
  final Set<String> pendingKeys;

  @override
  Widget build(BuildContext context) {
    final turn = session.currentTurn;
    final blocks = turn?.blocks ?? const <InteractiveBlock>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _SessionHeader(session: session),
        const SizedBox(height: 14),
        if (blocks.isEmpty)
          const _WaitingCard()
        else
          ...blocks.map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BlockView(
                block: block,
                turnId: turn?.turnId,
                onChoice: onChoice,
                onQuizAnswer: onQuizAnswer,
                pendingKeys: pendingKeys,
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final InteractiveSessionState session;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A1B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: CupertinoIcons.person_2_fill,
                    text: '${session.participants.length}',
                  ),
                  _Pill(icon: CupertinoIcons.sparkles, text: session.aiRole),
                  if ((session.joinCode ?? '').isNotEmpty)
                    _Pill(icon: CupertinoIcons.link, text: session.joinCode!),
                ],
              ),
            ),
            Icon(
              session.interactionMode == 'group'
                  ? CupertinoIcons.person_3_fill
                  : CupertinoIcons.hand_point_right_fill,
              color: context.primaryTextColor.withValues(alpha: 0.72),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.secondaryTextColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: context.primaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({
    required this.block,
    required this.turnId,
    required this.onChoice,
    required this.onQuizAnswer,
    required this.pendingKeys,
  });

  final InteractiveBlock block;
  final String? turnId;
  final ValueChanged<String> onChoice;
  final ValueChanged<String> onQuizAnswer;
  final Set<String> pendingKeys;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      InteractiveTextBlock b => _TextBlock(text: b.text),
      InteractiveChoiceGroupBlock b => _ChoiceBlock(
        prompt: b.prompt,
        options: b.options,
        turnId: turnId,
        inputType: 'option_select',
        pendingKeys: pendingKeys,
        onSelected: onChoice,
      ),
      InteractiveQuizBlock b => _QuizBlock(
        block: b,
        turnId: turnId,
        pendingKeys: pendingKeys,
        onSelected: onQuizAnswer,
      ),
      InteractiveMediaBlock b => _MediaBlock(block: b),
      InteractiveTimerBlock b => _TimerBlock(expiresAt: b.expiresAt),
      InteractiveScoreboardBlock b => _ScoreboardBlock(players: b.players),
      InteractivePrivatePromptBlock b => _PrivatePromptBlock(text: b.text),
      InteractiveSystemBlock b => _SystemBlock(text: b.text),
      InteractiveUnknownBlock b => _UnknownBlock(kind: b.kind),
    };
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Text(
        text,
        style: TextStyle(
          color: context.primaryTextColor,
          fontSize: 17,
          height: 1.42,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({
    required this.prompt,
    required this.options,
    required this.turnId,
    required this.inputType,
    required this.pendingKeys,
    required this.onSelected,
  });

  final String prompt;
  final List<InteractiveOption> options;
  final String? turnId;
  final String inputType;
  final Set<String> pendingKeys;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prompt.isNotEmpty)
            Text(
              prompt,
              style: TextStyle(
                color: context.primaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          if (prompt.isNotEmpty) const SizedBox(height: 12),
          for (final option in options) ...[
            _OptionButton(
              option: option,
              busy: pendingKeys.contains('$turnId-$inputType-${option.id}'),
              onTap: () => onSelected(option.id),
            ),
            if (option != options.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _QuizBlock extends StatelessWidget {
  const _QuizBlock({
    required this.block,
    required this.turnId,
    required this.pendingKeys,
    required this.onSelected,
  });

  final InteractiveQuizBlock block;
  final String? turnId;
  final Set<String> pendingKeys;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: const Color(0xFF2563EB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.question_circle_fill,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.question,
                  style: TextStyle(
                    color: context.primaryTextColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final option in block.options) ...[
            _OptionButton(
              option: option,
              busy: pendingKeys.contains('$turnId-quiz_answer-${option.id}'),
              onTap: () => onSelected(option.id),
            ),
            if (option != block.options.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.busy,
    required this.onTap,
  });

  final InteractiveOption option;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          foregroundColor: context.primaryTextColor,
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.label.isEmpty ? option.id : option.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: context.secondaryTextColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaBlock extends StatelessWidget {
  const _MediaBlock({required this.block});

  final InteractiveMediaBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.mediaType == 'video') {
      return _VideoBlock(url: block.url, caption: block.text);
    }
    return _Panel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                block.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _MediaFallback(),
              ),
            ),
            if ((block.text ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  block.text!,
                  style: TextStyle(color: context.secondaryTextColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoBlock extends StatefulWidget {
  const _VideoBlock({required this.url, this.caption});

  final String url;
  final String? caption;

  @override
  State<_VideoBlock> createState() => _VideoBlockState();
}

class _VideoBlockState extends State<_VideoBlock> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    unawaited(
      controller.initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return _Panel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_ready && controller != null)
                    VideoPlayer(controller)
                  else
                    const _MediaFallback(icon: CupertinoIcons.play_rectangle),
                  IconButton.filled(
                    onPressed: !_ready || controller == null
                        ? null
                        : () {
                            setState(() {
                              controller.value.isPlaying
                                  ? controller.pause()
                                  : controller.play();
                            });
                          },
                    icon: Icon(
                      controller?.value.isPlaying == true
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                    ),
                  ),
                ],
              ),
            ),
            if ((widget.caption ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.caption!,
                  style: TextStyle(color: context.secondaryTextColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({this.icon = CupertinoIcons.photo});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.isDarkMode
          ? const Color(0xFF202324)
          : const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: Icon(icon, color: context.secondaryTextColor, size: 32),
    );
  }
}

class _TimerBlock extends StatefulWidget {
  const _TimerBlock({required this.expiresAt});

  final DateTime? expiresAt;

  @override
  State<_TimerBlock> createState() => _TimerBlockState();
}

class _TimerBlockState extends State<_TimerBlock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = widget.expiresAt;
    final remaining = expiresAt?.difference(DateTime.now().toUtc());
    final seconds = remaining == null ? 0 : remaining.inSeconds.clamp(0, 9999);
    return _Panel(
      child: Row(
        children: [
          const Icon(CupertinoIcons.timer, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Text(
            '${seconds}s',
            style: TextStyle(
              color: context.primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreboardBlock extends StatelessWidget {
  const _ScoreboardBlock({required this.players});

  final List<Map<String, dynamic>> players;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scoreboard',
            style: TextStyle(
              color: context.primaryTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final player in players) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    (player['display_name'] as String?)?.trim() ?? 'Player',
                    style: TextStyle(
                      color: context.primaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${(player['score'] as num?)?.toInt() ?? 0}',
                  style: TextStyle(
                    color: context.primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (player != players.last) const Divider(height: 16),
          ],
        ],
      ),
    );
  }
}

class _PrivatePromptBlock extends StatelessWidget {
  const _PrivatePromptBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: const Color(0xFF7C3AED),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.lock_fill,
            color: Color(0xFF7C3AED),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.primaryTextColor,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemBlock extends StatelessWidget {
  const _SystemBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Text(
        text,
        style: TextStyle(
          color: context.secondaryTextColor,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}

class _UnknownBlock extends StatelessWidget {
  const _UnknownBlock({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: context.secondaryTextColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unsupported block: $kind',
              style: TextStyle(color: context.secondaryTextColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Waiting for the next turn',
            style: TextStyle(color: context.secondaryTextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color? accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A1B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              accent?.withValues(alpha: 0.35) ??
              (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
