import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/theme_provider.dart';
import '../models/interactive_story_models.dart';

typedef QuizAnswerCallback = void Function(String optionId, String? questionId);

class InteractiveStoryRenderer extends StatelessWidget {
  const InteractiveStoryRenderer({
    super.key,
    required this.session,
    required this.onChoice,
    required this.onQuizAnswer,
    required this.onRetryGeneration,
    required this.onReplay,
    required this.onLeave,
    this.pendingKeys = const <String>{},
    this.localQuizSelections = const <String, String>{},
  });

  final InteractiveSessionState session;
  final ValueChanged<String> onChoice;
  final QuizAnswerCallback onQuizAnswer;
  final VoidCallback onRetryGeneration;
  final VoidCallback onReplay;
  final VoidCallback onLeave;
  final Set<String> pendingKeys;
  final Map<String, String> localQuizSelections;

  @override
  Widget build(BuildContext context) {
    final turn = session.currentTurn;
    final blocks = turn?.blocks ?? const <InteractiveBlock>[];
    final liveQuiz = _LiveQuizQuestion.fromState(session.interactiveState);
    final phase = (session.interactiveState['phase'] as String?) ?? '';
    final isQuizSession = session.interactiveState['template'] == 'quiz';
    String? busyOptionId;
    if (liveQuiz != null) {
      final prefix = '${liveQuiz.questionId}-quiz_answer-';
      for (final key in pendingKeys) {
        if (key.startsWith(prefix)) {
          busyOptionId = key.substring(prefix.length);
          break;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _SessionHeader(session: session),
        const SizedBox(height: 14),
        if (liveQuiz != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LiveQuizBlock(
              question: liveQuiz,
              session: session,
              selectedOptionId: localQuizSelections[liveQuiz.questionId],
              busyOptionId: busyOptionId,
              onSelected: (optionId) =>
                  onQuizAnswer(optionId, liveQuiz.questionId),
            ),
          )
        else if (isQuizSession && phase == 'showing_results')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QuizResultsBlock(session: session),
          )
        else if (isQuizSession && phase == 'completed')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FinalStandingsBlock(
              session: session,
              onReplay: onReplay,
              onLeave: onLeave,
            ),
          )
        else if (isQuizSession && phase == 'generation_failed')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QuizStatusBlock(
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              title: 'Question failed to load',
              body:
                  (session.interactiveState['generation_error'] as String?) ??
                  'The host can retry the question.',
              actionLabel: 'Retry',
              onAction: onRetryGeneration,
            ),
          )
        else if (isQuizSession &&
            (phase == 'generating_question' ||
                phase == 'question_generation_started' ||
                phase == 'finalizing_question'))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QuizStatusBlock(
              icon: CupertinoIcons.person_3_fill,
              title: phase == 'finalizing_question'
                  ? 'Checking answers'
                  : 'Waiting for the next question',
              body: _lobbyText(session),
            ),
          )
        else if (blocks.isEmpty)
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
                localQuizSelections: localQuizSelections,
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
    required this.localQuizSelections,
  });

  final InteractiveBlock block;
  final String? turnId;
  final ValueChanged<String> onChoice;
  final QuizAnswerCallback onQuizAnswer;
  final Set<String> pendingKeys;
  final Map<String, String> localQuizSelections;

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
        selectedOptionId: turnId == null ? null : localQuizSelections[turnId],
        onSelected: (optionId) => onQuizAnswer(optionId, null),
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
    required this.selectedOptionId,
    required this.onSelected,
  });

  final InteractiveQuizBlock block;
  final String? turnId;
  final Set<String> pendingKeys;
  final String? selectedOptionId;
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
              status: selectedOptionId == option.id
                  ? _OptionStatus.selected
                  : null,
              onTap: () => onSelected(option.id),
            ),
            if (option != block.options.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _LiveQuizQuestion {
  const _LiveQuizQuestion({
    required this.questionId,
    required this.text,
    required this.options,
    required this.correctOptionId,
    required this.currentRound,
    required this.totalRounds,
    this.expiresAt,
    this.explanation,
  });

  final String questionId;
  final String text;
  final List<InteractiveOption> options;
  final String correctOptionId;
  final int currentRound;
  final int totalRounds;
  final DateTime? expiresAt;
  final String? explanation;

  static _LiveQuizQuestion? fromState(Map<String, dynamic> state) {
    if (state['phase'] != 'question_active') return null;
    final raw = state['question'];
    if (raw is! Map) return null;
    final question = raw.cast<String, dynamic>();
    final questionId = (question['question_id'] as String?)?.trim() ?? '';
    final text =
        (question['text'] as String?)?.trim() ??
        (question['question'] as String?)?.trim() ??
        '';
    final correctOptionId =
        (question['correct_option_id'] as String?)?.trim() ?? '';
    final options = ((question['options'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => InteractiveOption.fromJson(e.cast<String, dynamic>()))
        .where((option) => option.id.isNotEmpty || option.label.isNotEmpty)
        .toList();
    if (questionId.isEmpty || text.isEmpty || options.isEmpty) return null;
    return _LiveQuizQuestion(
      questionId: questionId,
      text: text,
      options: options,
      correctOptionId: correctOptionId,
      currentRound: (state['current_round'] as num?)?.toInt() ?? 1,
      totalRounds: (state['total_rounds'] as num?)?.toInt() ?? 1,
      expiresAt: _parseQuizDate(question['expires_at']),
      explanation: (question['explanation'] as String?)?.trim(),
    );
  }
}

class _LiveQuizBlock extends StatefulWidget {
  const _LiveQuizBlock({
    required this.question,
    required this.session,
    required this.selectedOptionId,
    required this.busyOptionId,
    required this.onSelected,
  });

  final _LiveQuizQuestion question;
  final InteractiveSessionState session;
  final String? selectedOptionId;
  final String? busyOptionId;
  final ValueChanged<String> onSelected;

  @override
  State<_LiveQuizBlock> createState() => _LiveQuizBlockState();
}

class _LiveQuizBlockState extends State<_LiveQuizBlock> {
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
    final question = widget.question;
    final selected = widget.selectedOptionId;
    final answered = selected != null;
    final isCorrect = selected == question.correctOptionId;
    final seconds = _remainingSeconds(question.expiresAt);
    final answeredCount = _intFromState(
      widget.session.interactiveState['answered_count'],
      fallback:
          (widget.session.interactiveState['answered_participant_ids'] as List?)
              ?.length ??
          0,
    );
    final eligibleCount = _intFromState(
      widget.session.interactiveState['eligible_count'],
      fallback:
          (widget.session.interactiveState['eligible_participant_ids'] as List?)
              ?.length ??
          widget.session.participants.where((p) => p.status == 'active').length,
    );
    return _Panel(
      accent: const Color(0xFF2563EB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundPill(
                current: question.currentRound,
                total: question.totalRounds,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.text,
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
          if (question.expiresAt != null) ...[
            Row(
              children: [
                Icon(
                  CupertinoIcons.timer,
                  color: seconds <= 5
                      ? const Color(0xFFDC2626)
                      : context.secondaryTextColor,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  '${seconds}s',
                  style: TextStyle(
                    color: seconds <= 5
                        ? const Color(0xFFDC2626)
                        : context.secondaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '$answeredCount/$eligibleCount answered',
                  style: TextStyle(
                    color: context.secondaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          for (final option in question.options) ...[
            _OptionButton(
              option: option,
              busy: widget.busyOptionId == option.id,
              status: _statusForOption(
                option.id,
                selected,
                question.correctOptionId,
              ),
              onTap: answered || seconds == 0
                  ? () {}
                  : () => widget.onSelected(option.id),
            ),
            if (option != question.options.last) const SizedBox(height: 8),
          ],
          if (answered) ...[
            const SizedBox(height: 12),
            Text(
              isCorrect
                  ? 'Correct'
                  : 'Not quite. Correct answer: ${_correctLabel(question)}',
              style: TextStyle(
                color: isCorrect
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            if ((question.explanation ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                question.explanation!,
                style: TextStyle(
                  color: context.secondaryTextColor,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            if (answeredCount < eligibleCount) ...[
              const SizedBox(height: 8),
              Text(
                'Waiting for others...',
                style: TextStyle(
                  color: context.secondaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static int _remainingSeconds(DateTime? expiresAt) {
    if (expiresAt == null) return 0;
    final remaining = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    return remaining.clamp(0, 9999);
  }

  static _OptionStatus? _statusForOption(
    String optionId,
    String? selectedOptionId,
    String correctOptionId,
  ) {
    if (selectedOptionId == null) return null;
    if (optionId == correctOptionId) return _OptionStatus.correct;
    if (optionId == selectedOptionId) return _OptionStatus.incorrect;
    return null;
  }

  static String _correctLabel(_LiveQuizQuestion question) {
    for (final option in question.options) {
      if (option.id == question.correctOptionId) {
        return option.label.isEmpty ? option.id : option.label;
      }
    }
    return question.correctOptionId;
  }
}

class _QuizResultsBlock extends StatelessWidget {
  const _QuizResultsBlock({required this.session});

  final InteractiveSessionState session;

  @override
  Widget build(BuildContext context) {
    final state = session.interactiveState;
    final result =
        (state['result'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final correctOptionId = (result['correct_option_id'] as String?) ?? '';
    final explanation = (result['explanation'] as String?)?.trim() ?? '';
    final answeredCount = _intFromState(result['answered_count']);
    final eligibleCount = _intFromState(result['eligible_count']);
    final standings = _standingsFromState(state, session.participants);
    final answerRows = ((result['answers'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    return _Panel(
      accent: const Color(0xFF16A34A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: Color(0xFF16A34A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Answer revealed',
                  style: TextStyle(
                    color: context.primaryTextColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$answeredCount/$eligibleCount answered',
                style: TextStyle(
                  color: context.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Correct answer: $correctOptionId',
            style: TextStyle(
              color: context.primaryTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: TextStyle(
                color: context.secondaryTextColor,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (answerRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...answerRows.map(
              (answer) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _AnswerResultRow(
                  name: _participantName(
                    session.participants,
                    answer['participant_id'] as String?,
                  ),
                  correct: answer['is_correct'] == true,
                  points: (answer['points_awarded'] as num?)?.toInt() ?? 0,
                ),
              ),
            ),
          ],
          if (standings.isNotEmpty) ...[
            const SizedBox(height: 10),
            _StandingsList(rows: standings.take(4).toList(), compact: true),
          ],
          const SizedBox(height: 10),
          Text(
            'Next question starting...',
            style: TextStyle(
              color: context.secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalStandingsBlock extends StatelessWidget {
  const _FinalStandingsBlock({
    required this.session,
    required this.onReplay,
    required this.onLeave,
  });

  final InteractiveSessionState session;
  final VoidCallback onReplay;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final standings = _standingsFromState(
      session.interactiveState,
      session.participants,
    );
    final winnerIds =
        ((session.interactiveState['winner_participant_ids'] as List?) ??
                const [])
            .whereType<String>()
            .toSet();
    final winners = standings
        .where((row) => winnerIds.contains(row.participantId))
        .map((row) => row.name)
        .where((name) => name.isNotEmpty)
        .join(', ');

    return _Panel(
      accent: const Color(0xFFF59E0B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.rosette,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  winners.isEmpty ? 'Final scores' : 'Winner: $winners',
                  style: TextStyle(
                    color: context.primaryTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (standings.isEmpty)
            Text(
              'No scores were recorded.',
              style: TextStyle(color: context.secondaryTextColor),
            )
          else
            _StandingsList(rows: standings),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onLeave,
                  child: const Text('Leave'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onReplay,
                  child: const Text('Replay'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizStatusBlock extends StatelessWidget {
  const _QuizStatusBlock({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB), size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.primaryTextColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: context.secondaryTextColor,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _AnswerResultRow extends StatelessWidget {
  const _AnswerResultRow({
    required this.name,
    required this.correct,
    required this.points,
  });

  final String name;
  final bool correct;
  final int points;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Row(
      children: [
        Icon(
          correct
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.xmark_circle_fill,
          color: color,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: context.primaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '+$points',
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _StandingsList extends StatelessWidget {
  const _StandingsList({required this.rows, this.compact = false});

  final List<_StandingRow> rows;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: EdgeInsets.only(bottom: compact ? 6 : 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '#${row.rank}',
                      style: TextStyle(
                        color: context.secondaryTextColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.name,
                      style: TextStyle(
                        color: context.primaryTextColor,
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${row.score}',
                    style: TextStyle(
                      color: context.primaryTextColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StandingRow {
  const _StandingRow({
    required this.rank,
    required this.participantId,
    required this.name,
    required this.score,
  });

  final int rank;
  final String participantId;
  final String name;
  final int score;
}

enum _OptionStatus { selected, correct, incorrect }

class _RoundPill extends StatelessWidget {
  const _RoundPill({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          '$current/$total',
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

DateTime? _parseQuizDate(dynamic raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    final value = raw.trim();
    final hasTimezone = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value);
    return DateTime.tryParse(hasTimezone ? value : '${value}Z')?.toUtc();
  }
  return null;
}

int _intFromState(dynamic raw, {int fallback = 0}) {
  if (raw is num) return raw.toInt();
  return fallback;
}

String _lobbyText(InteractiveSessionState session) {
  final state = session.interactiveState;
  final config = (state['quiz_config'] as Map?)?.cast<String, dynamic>();
  final maxPlayers = _intFromState(
    state['max_participants'],
    fallback: _intFromState(config?['max_players']),
  );
  final count = session.participants.where((p) => p.status == 'active').length;
  final join = (session.joinCode ?? '').trim();
  final playerText = maxPlayers > 0
      ? '$count/$maxPlayers players'
      : '$count players';
  if (join.isEmpty) return '$playerText are in the room.';
  return '$playerText are in the room. Join code: $join';
}

List<_StandingRow> _standingsFromState(
  Map<String, dynamic> state,
  List<StoryParticipant> participants,
) {
  final rawStandings =
      ((state['final_standings'] as List?) ??
              (state['standings'] as List?) ??
              ((state['result'] as Map?)?['standings'] as List?) ??
              const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
  if (rawStandings.isNotEmpty) {
    return rawStandings
        .map(
          (row) => _StandingRow(
            rank: _intFromState(row['rank'], fallback: 1),
            participantId: (row['participant_id'] as String?) ?? '',
            name: (row['display_name'] as String?)?.trim().isNotEmpty == true
                ? (row['display_name'] as String).trim()
                : _participantName(
                    participants,
                    row['participant_id'] as String?,
                  ),
            score: _intFromState(row['score']),
          ),
        )
        .toList();
  }

  final sorted = [...participants]..sort((a, b) => b.score.compareTo(a.score));
  final rows = <_StandingRow>[];
  var rank = 0;
  int? previousScore;
  for (var i = 0; i < sorted.length; i++) {
    final participant = sorted[i];
    if (participant.score != previousScore) {
      rank = i + 1;
      previousScore = participant.score;
    }
    rows.add(
      _StandingRow(
        rank: rank,
        participantId: participant.id,
        name: _displayName(participant),
        score: participant.score,
      ),
    );
  }
  return rows;
}

String _participantName(List<StoryParticipant> participants, String? id) {
  for (final participant in participants) {
    if (participant.id == id) return _displayName(participant);
  }
  return 'Player';
}

String _displayName(StoryParticipant participant) {
  final name = participant.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return participant.role == 'host' ? 'Host' : 'Player';
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.busy,
    this.status,
    required this.onTap,
  });

  final InteractiveOption option;
  final bool busy;
  final _OptionStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final color = switch (status) {
      _OptionStatus.correct => const Color(0xFF16A34A),
      _OptionStatus.incorrect => const Color(0xFFDC2626),
      _OptionStatus.selected => const Color(0xFF2563EB),
      null => null,
    };
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          foregroundColor: context.primaryTextColor,
          side: BorderSide(
            color:
                color?.withValues(alpha: 0.75) ??
                (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.12)),
          ),
          backgroundColor: color?.withValues(alpha: isDark ? 0.14 : 0.09),
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
            else if (status == _OptionStatus.correct)
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 17,
                color: Color(0xFF16A34A),
              )
            else if (status == _OptionStatus.incorrect)
              const Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 17,
                color: Color(0xFFDC2626),
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
