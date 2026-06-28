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
    this.currentUserId,
    required this.onChoice,
    required this.onQuizAnswer,
    required this.onRetryGeneration,
    required this.onReplay,
    required this.onLeave,
    this.pendingKeys = const <String>{},
    this.pendingTextMessages = const <PendingInteractiveTextMessage>[],
    this.localQuizSelections = const <String, String>{},
    this.streamingAssistantText,
    this.recentStreamedAssistantText,
  });

  final InteractiveSessionState session;
  final String? currentUserId;
  final ValueChanged<String> onChoice;
  final QuizAnswerCallback onQuizAnswer;
  final VoidCallback onRetryGeneration;
  final VoidCallback onReplay;
  final VoidCallback onLeave;
  final Set<String> pendingKeys;
  final List<PendingInteractiveTextMessage> pendingTextMessages;
  final Map<String, String> localQuizSelections;
  final String? streamingAssistantText;
  final String? recentStreamedAssistantText;

  @override
  Widget build(BuildContext context) {
    final turn = session.currentTurn;
    final blocks = turn?.blocks ?? const <InteractiveBlock>[];
    final liveQuiz = _LiveQuizQuestion.fromState(session.interactiveState);
    final phase = (session.interactiveState['phase'] as String?) ?? '';
    final isQuizSession = session.interactiveState['template'] == 'quiz';
    if (isQuizSession) {
      return _QuizTranscriptView(
        session: session,
        currentUserId: currentUserId,
        pendingKeys: pendingKeys,
        pendingTextMessages: pendingTextMessages,
        localQuizSelections: localQuizSelections,
        streamingAssistantText: streamingAssistantText,
        recentStreamedAssistantText: recentStreamedAssistantText,
        onChoice: onChoice,
        onQuizAnswer: onQuizAnswer,
        onRetryGeneration: onRetryGeneration,
        onReplay: onReplay,
        onLeave: onLeave,
      );
    }
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

class _QuizTranscriptView extends StatefulWidget {
  const _QuizTranscriptView({
    required this.session,
    required this.currentUserId,
    required this.pendingKeys,
    required this.pendingTextMessages,
    required this.localQuizSelections,
    this.streamingAssistantText,
    this.recentStreamedAssistantText,
    required this.onChoice,
    required this.onQuizAnswer,
    required this.onRetryGeneration,
    required this.onReplay,
    required this.onLeave,
  });

  final InteractiveSessionState session;
  final String? currentUserId;
  final Set<String> pendingKeys;
  final List<PendingInteractiveTextMessage> pendingTextMessages;
  final Map<String, String> localQuizSelections;
  final String? streamingAssistantText;
  final String? recentStreamedAssistantText;
  final ValueChanged<String> onChoice;
  final QuizAnswerCallback onQuizAnswer;
  final VoidCallback onRetryGeneration;
  final VoidCallback onReplay;
  final VoidCallback onLeave;

  @override
  State<_QuizTranscriptView> createState() => _QuizTranscriptViewState();
}

class _QuizTranscriptViewState extends State<_QuizTranscriptView> {
  final _controller = ScrollController();
  int _lastSeq = -1;
  int _lastPendingCount = 0;
  int _lastPendingKeyCount = 0;
  String _lastStreamingAssistantText = '';

  @override
  void initState() {
    super.initState();
    _lastSeq = widget.session.lastSeq;
    _lastPendingCount = widget.pendingTextMessages.length;
    _lastPendingKeyCount = widget.pendingKeys.length;
    _lastStreamingAssistantText = widget.streamingAssistantText ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void didUpdateWidget(covariant _QuizTranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pendingCount = widget.pendingTextMessages.length;
    final pendingKeyCount = widget.pendingKeys.length;
    final streamingAssistantText = widget.streamingAssistantText ?? '';
    if (widget.session.lastSeq != _lastSeq ||
        pendingCount != _lastPendingCount ||
        pendingKeyCount != _lastPendingKeyCount ||
        streamingAssistantText != _lastStreamingAssistantText) {
      _lastSeq = widget.session.lastSeq;
      _lastPendingCount = pendingCount;
      _lastPendingKeyCount = pendingKeyCount;
      _lastStreamingAssistantText = streamingAssistantText;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_controller.hasClients) return;
    _controller.jumpTo(_controller.position.maxScrollExtent);
  }

  void _scrollToBottom() {
    if (!_controller.hasClients) return;
    final distanceFromBottom =
        _controller.position.maxScrollExtent - _controller.offset;
    if (distanceFromBottom > 180) return;
    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final items = _QuizTranscriptItem.build(
      session: session,
      currentUserId: widget.currentUserId,
      pendingKeys: widget.pendingKeys,
      pendingTextMessages: widget.pendingTextMessages,
      localQuizSelections: widget.localQuizSelections,
      streamingAssistantText: widget.streamingAssistantText,
    );

    return ListView(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(2, 42, 2, 28),
      children: [
        const SizedBox(height: 4),
        if (items.isEmpty)
          _ChatMessageBubble(
            child: _QuizStatusContent(
              icon: CupertinoIcons.person_3_fill,
              title: 'Waiting for the first question',
              body: _lobbyText(session),
            ),
          )
        else
          for (final item in items) ...[
            _QuizTranscriptRow(
              item: item,
              session: session,
              pendingKeys: widget.pendingKeys,
              recentStreamedAssistantText: widget.recentStreamedAssistantText,
              onChoice: widget.onChoice,
              onQuizAnswer: widget.onQuizAnswer,
              onRetryGeneration: widget.onRetryGeneration,
              onReplay: widget.onReplay,
              onLeave: widget.onLeave,
              onTextRevealTick: _scrollToBottom,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

enum _QuizTranscriptItemKind {
  status,
  aiMessage,
  userMessage,
  choiceGroup,
  pendingAssistant,
  streamingAssistant,
  question,
  progress,
  result,
  finalStandings,
}

class _QuizTranscriptItem {
  const _QuizTranscriptItem({
    required this.kind,
    required this.seq,
    this.event,
    this.question,
    this.answer,
    this.result,
    this.statusTitle,
    this.statusBody,
    this.userText,
    this.statusIcon = CupertinoIcons.info_circle_fill,
    this.choicePrompt,
    this.choiceOptions = const <InteractiveOption>[],
    this.choiceTurnId,
    this.showLoading = false,
    this.isActiveQuestion = false,
    this.isPending = false,
  });

  final _QuizTranscriptItemKind kind;
  final int seq;
  final StorySessionEvent? event;
  final _LiveQuizQuestion? question;
  final _UserQuizAnswer? answer;
  final Map<String, dynamic>? result;
  final String? statusTitle;
  final String? statusBody;
  final String? userText;
  final IconData? statusIcon;
  final String? choicePrompt;
  final List<InteractiveOption> choiceOptions;
  final String? choiceTurnId;
  final bool showLoading;
  final bool isActiveQuestion;
  final bool isPending;

  _QuizTranscriptItem copyWith({
    Map<String, dynamic>? result,
    bool? isActiveQuestion,
  }) {
    return _QuizTranscriptItem(
      kind: kind,
      seq: seq,
      event: event,
      question: question,
      answer: answer,
      result: result ?? this.result,
      statusTitle: statusTitle,
      statusBody: statusBody,
      userText: userText,
      statusIcon: statusIcon,
      choicePrompt: choicePrompt,
      choiceOptions: choiceOptions,
      choiceTurnId: choiceTurnId,
      showLoading: showLoading,
      isActiveQuestion: isActiveQuestion ?? this.isActiveQuestion,
      isPending: isPending,
    );
  }

  static List<_QuizTranscriptItem> build({
    required InteractiveSessionState session,
    required String? currentUserId,
    required Set<String> pendingKeys,
    required List<PendingInteractiveTextMessage> pendingTextMessages,
    required Map<String, String> localQuizSelections,
    String? streamingAssistantText,
  }) {
    final events = _dedupeEvents(session.events)
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final startedRounds = events
        .where((event) => event.eventType == 'question_started')
        .map((event) => (event.payload['round'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    final items = <_QuizTranscriptItem>[];
    final questionIds = <String>{};
    final resultQuestionIds = <String>{};
    final answerQuestionIds = <String>{};
    final liveQuiz = _LiveQuizQuestion.fromState(session.interactiveState);
    final phase = (session.interactiveState['phase'] as String?) ?? '';
    final currentRound = (session.interactiveState['current_round'] as num?)
        ?.toInt();
    final totalRounds =
        (session.interactiveState['total_rounds'] as num?)?.toInt() ?? 1;

    for (final event in events) {
      switch (event.eventType) {
        case 'topic_selection_started':
          _addTopicPromptItems(
            items: items,
            baseSeq: event.seq,
            event: event,
            prompt:
                (event.payload['prompt'] as String?) ??
                'What topic do you want to play?',
          );
          break;
        case 'topic_selected':
          final topic = (event.payload['topic'] as String?)?.trim();
          if (topic == null || topic.isEmpty) break;
          items.add(
            _QuizTranscriptItem(
              kind: _QuizTranscriptItemKind.userMessage,
              seq: event.seq,
              event: event,
              userText: topic,
            ),
          );
          break;
        case 'solo_user_message':
          final text = (event.payload['text'] as String?)?.trim();
          if (text == null || text.isEmpty) break;
          final eventPhase = (event.payload['phase'] as String?)?.trim();
          items.add(
            _QuizTranscriptItem(
              kind: _QuizTranscriptItemKind.userMessage,
              seq: event.seq,
              event: event,
              userText: _routeChoiceLabel(text, phase: eventPhase) ?? text,
            ),
          );
          break;
        case 'interactive_turn':
          final turn = InteractiveTurn.fromJson(event.payload);
          final texts = _turnTexts(turn);
          for (final text in texts) {
            items.add(
              _QuizTranscriptItem(
                kind: _QuizTranscriptItemKind.aiMessage,
                seq: event.seq,
                event: event,
                statusTitle: text,
              ),
            );
          }
          items.addAll(
            _turnChoiceItems(turn, event.seq, phase: phase, event: event),
          );
          break;
        case 'question_generation_started':
          final round = (event.payload['round'] as num?)?.toInt();
          if (round != null && startedRounds.contains(round)) break;
          items.add(
            _QuizTranscriptItem(
              kind: _QuizTranscriptItemKind.status,
              seq: event.seq,
              event: event,
              statusTitle: 'Aura is getting the next question ready',
              statusBody: '',
              statusIcon: CupertinoIcons.sparkles,
              showLoading: true,
            ),
          );
          break;
        case 'generation_failed':
          items.add(
            _QuizTranscriptItem(
              kind: _QuizTranscriptItemKind.status,
              seq: event.seq,
              event: event,
              statusTitle: 'Question failed to load',
              statusBody: 'The host can retry the question.',
              statusIcon: CupertinoIcons.exclamationmark_triangle_fill,
            ),
          );
          break;
        case 'question_started':
          final question = _LiveQuizQuestion.fromPayload(
            event.payload,
            session.interactiveState,
          );
          if (question == null) break;
          questionIds.add(question.questionId);
          items.add(
            _QuizTranscriptItem(
              kind: _QuizTranscriptItemKind.question,
              seq: event.seq,
              event: event,
              question: question,
              answer: localQuizSelections[question.questionId] == null
                  ? null
                  : _UserQuizAnswer(
                      questionId: question.questionId,
                      optionId: localQuizSelections[question.questionId]!,
                      optionLabel: _optionLabel(
                        question.options,
                        localQuizSelections[question.questionId]!,
                      ),
                    ),
              isActiveQuestion:
                  phase == 'question_active' &&
                  liveQuiz?.questionId == question.questionId,
            ),
          );
          break;
        case 'answer_submitted':
          if (!_isCurrentUserEvent(event, currentUserId)) break;
          final answer = _UserQuizAnswer.fromEvent(event);
          if (answer == null) break;
          answerQuestionIds.add(answer.questionId);
          break;
        case 'answer_received':
          items.add(
            _QuizTranscriptItem(
              kind: _QuizTranscriptItemKind.progress,
              seq: event.seq,
              event: event,
              result: event.payload,
            ),
          );
          break;
        case 'question_completed':
          final result = event.payload;
          final questionId = (result['question_id'] as String?)?.trim();
          if (questionId != null && questionId.isNotEmpty) {
            resultQuestionIds.add(questionId);
            final questionIndex = _questionItemIndex(items, questionId);
            if (questionIndex != -1) {
              items[questionIndex] = items[questionIndex].copyWith(
                result: result,
                isActiveQuestion: false,
              );
            }
          }
          items.add(
            _QuizTranscriptItem(
              kind: _QuizTranscriptItemKind.result,
              seq: event.seq,
              event: event,
              result: result,
            ),
          );
          break;
        case 'session_completed':
          items.add(
            _QuizTranscriptItem(
              kind: _QuizTranscriptItemKind.finalStandings,
              seq: event.seq,
              event: event,
            ),
          );
          break;
      }
    }

    if (liveQuiz != null && !questionIds.contains(liveQuiz.questionId)) {
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.question,
          seq: session.lastSeq + 1,
          question: liveQuiz,
          answer: localQuizSelections[liveQuiz.questionId] == null
              ? null
              : _UserQuizAnswer(
                  questionId: liveQuiz.questionId,
                  optionId: localQuizSelections[liveQuiz.questionId]!,
                  optionLabel: _optionLabel(
                    liveQuiz.options,
                    localQuizSelections[liveQuiz.questionId]!,
                  ),
                ),
          isActiveQuestion: true,
        ),
      );
    }

    final currentTurn = session.currentTurn;
    if (currentTurn != null &&
        !events.any(
          (event) =>
              event.eventType == 'interactive_turn' &&
              event.seq == currentTurn.seq,
        )) {
      for (final text in _turnTexts(currentTurn)) {
        items.add(
          _QuizTranscriptItem(
            kind: _QuizTranscriptItemKind.aiMessage,
            seq: currentTurn.seq,
            statusTitle: text,
          ),
        );
      }
      items.addAll(
        _turnChoiceItems(currentTurn, currentTurn.seq, phase: phase),
      );
    }

    final stateResult = (session.interactiveState['result'] as Map?)
        ?.cast<String, dynamic>();
    final stateResultQuestionId = (stateResult?['question_id'] as String?)
        ?.trim();
    if (stateResult != null &&
        stateResultQuestionId != null &&
        stateResultQuestionId.isNotEmpty &&
        !resultQuestionIds.contains(stateResultQuestionId)) {
      final questionIndex = _questionItemIndex(items, stateResultQuestionId);
      if (questionIndex != -1) {
        items[questionIndex] = items[questionIndex].copyWith(
          result: stateResult,
          isActiveQuestion: false,
        );
      }
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.result,
          seq: session.lastSeq + 3,
          result: stateResult,
        ),
      );
    }

    final questionForCurrentRoundIsRendered =
        liveQuiz != null ||
        (currentRound != null && startedRounds.contains(currentRound));
    if (phase == 'topic_selection' &&
        !events.any((event) => event.eventType == 'topic_selection_started')) {
      final topicPrompt = (session.interactiveState['topic_prompt'] as String?)
          ?.trim();
      if (topicPrompt != null && topicPrompt.isNotEmpty) {
        _addTopicPromptItems(
          items: items,
          baseSeq: session.lastSeq + 2,
          prompt: topicPrompt,
        );
      } else {
        items.add(
          _QuizTranscriptItem(
            kind: _QuizTranscriptItemKind.pendingAssistant,
            seq: session.lastSeq + 2,
            showLoading: true,
          ),
        );
      }
    }

    final waitingForQuestion =
        (phase == 'generating_question' ||
            phase == 'question_generation_started') &&
        !questionForCurrentRoundIsRendered;
    final waitingAfterResult =
        phase == 'showing_results' &&
        currentRound != null &&
        currentRound < totalRounds &&
        !startedRounds.contains(currentRound + 1);
    final waitingForFinalResults =
        phase == 'showing_results' &&
        currentRound != null &&
        currentRound >= totalRounds &&
        !session.isCompleted;
    final checkingAnswers = phase == 'finalizing_question';

    if ((waitingForQuestion ||
            waitingAfterResult ||
            waitingForFinalResults ||
            checkingAnswers) &&
        (items.isEmpty || items.last.kind != _QuizTranscriptItemKind.status)) {
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.status,
          seq: session.lastSeq + 4,
          statusTitle: waitingForFinalResults
              ? 'Calculating results...'
              : checkingAnswers
              ? 'Checking answers'
              : 'Aura is getting the next question ready',
          statusBody: checkingAnswers ? _lobbyText(session) : '',
          statusIcon: CupertinoIcons.person_3_fill,
          showLoading:
              waitingForQuestion ||
              waitingAfterResult ||
              waitingForFinalResults,
        ),
      );
    }

    if (phase == 'generation_failed' &&
        (items.isEmpty || items.last.kind != _QuizTranscriptItemKind.status)) {
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.status,
          seq: session.lastSeq + 5,
          statusTitle: 'Question failed to load',
          statusBody:
              (session.interactiveState['generation_error'] as String?) ??
              'The host can retry the question.',
          statusIcon: CupertinoIcons.exclamationmark_triangle_fill,
        ),
      );
    }

    if (phase == 'completed' &&
        !items.any(
          (item) => item.kind == _QuizTranscriptItemKind.finalStandings,
        )) {
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.finalStandings,
          seq: session.lastSeq + 6,
        ),
      );
    }

    for (var i = 0; i < pendingTextMessages.length; i += 1) {
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.userMessage,
          seq: session.lastSeq + 1000 + i,
          userText: pendingTextMessages[i].text,
          isPending: true,
        ),
      );
    }
    final liveAssistantText = streamingAssistantText?.trim() ?? '';
    final waitingForAssistant =
        pendingTextMessages.isNotEmpty ||
        pendingKeys.any(
          (key) => key.contains('-text-') || key.contains('-option_select-'),
        );
    if (liveAssistantText.isNotEmpty) {
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.streamingAssistant,
          seq: session.lastSeq + 2000 + pendingKeys.length,
          statusTitle: liveAssistantText,
        ),
      );
    } else if (waitingForAssistant) {
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.pendingAssistant,
          seq: session.lastSeq + 2000 + pendingKeys.length,
          showLoading: true,
        ),
      );
    }

    return items;
  }

  static void _addTopicPromptItems({
    required List<_QuizTranscriptItem> items,
    required int baseSeq,
    required String prompt,
    StorySessionEvent? event,
  }) {
    final chunks = _topicPromptChunks(prompt);
    for (var i = 0; i < chunks.length; i += 1) {
      items.add(
        _QuizTranscriptItem(
          kind: _QuizTranscriptItemKind.status,
          seq: baseSeq + i,
          event: i == 0 ? event : null,
          statusTitle: chunks[i],
          statusBody: '',
          statusIcon: null,
        ),
      );
    }
  }

  static List<String> _topicPromptChunks(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return const ['What topic do you want to play?'];

    final sentenceMatches = RegExp(r'[^.!?]+[.!?]*').allMatches(normalized);
    var parts = sentenceMatches
        .map((match) => match.group(0)?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length <= 1 && normalized.length > 90) {
      parts = normalized
          .split(RegExp(r'(?<=,)\s+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }
    if (parts.isEmpty) parts = [normalized];
    if (parts.length <= 3) return parts;

    return [parts[0], parts[1], parts.skip(2).join(' ')];
  }

  static int _questionItemIndex(
    List<_QuizTranscriptItem> items,
    String questionId,
  ) {
    return items.indexWhere(
      (item) =>
          item.kind == _QuizTranscriptItemKind.question &&
          item.question?.questionId == questionId,
    );
  }

  static List<String> _turnTexts(InteractiveTurn turn) {
    final texts = <String>[];
    for (final block in turn.blocks) {
      if (block case InteractiveTextBlock b) {
        final text = b.text.trim();
        if (text.isNotEmpty) texts.add(text);
      } else if (block case InteractiveSystemBlock b) {
        final text = b.text.trim();
        if (text.isNotEmpty) texts.add(text);
      } else if (block case InteractivePrivatePromptBlock b) {
        final text = b.text.trim();
        if (text.isNotEmpty) texts.add(text);
      }
    }
    return texts;
  }

  static List<_QuizTranscriptItem> _turnChoiceItems(
    InteractiveTurn turn,
    int seq, {
    required String phase,
    StorySessionEvent? event,
  }) {
    final items = <_QuizTranscriptItem>[];
    for (final block in turn.blocks) {
      if (block case InteractiveChoiceGroupBlock b) {
        if (b.options.isEmpty) continue;
        final choiceKind = (b.metadata['choice_kind'] as String?)?.trim();
        if (choiceKind == 'solo_quiz_mode' && phase != 'mode_selection') {
          continue;
        }
        items.add(
          _QuizTranscriptItem(
            kind: _QuizTranscriptItemKind.choiceGroup,
            seq: seq,
            event: event,
            choicePrompt: b.prompt,
            choiceOptions: b.options,
            choiceTurnId: turn.turnId,
          ),
        );
      }
    }
    return items;
  }

  static String? _routeChoiceLabel(String text, {String? phase}) {
    if (phase != null && phase != 'mode_selection') return null;
    return switch (text.trim().toLowerCase()) {
      'chat' || 'discuss' || 'discussion' => 'Chat',
      'quiz' || 'quiz_now' => 'Quiz',
      _ => null,
    };
  }

  static bool _isCurrentUserEvent(StorySessionEvent event, String? userId) {
    if (userId == null || userId.isEmpty) {
      return event.visibility == 'private';
    }
    return event.actorUserId == userId || event.targetUserIds.contains(userId);
  }

  static List<StorySessionEvent> _dedupeEvents(List<StorySessionEvent> events) {
    final seen = <String>{};
    final deduped = <StorySessionEvent>[];
    for (final event in events) {
      final key = _eventKey(event);
      if (!seen.add(key)) continue;
      deduped.add(event);
    }
    return deduped;
  }

  static String _eventKey(StorySessionEvent event) {
    final payload = event.payload;
    final questionId = (payload['question_id'] as String?)?.trim() ?? '';
    final participantId = (payload['participant_id'] as String?)?.trim() ?? '';
    final optionId = (payload['option_id'] as String?)?.trim() ?? '';
    final round = payload['round']?.toString() ?? '';
    return [
      event.seq,
      event.eventType,
      questionId,
      participantId,
      optionId,
      round,
    ].join('|');
  }

  static String _optionLabel(List<InteractiveOption> options, String optionId) {
    for (final option in options) {
      if (option.id == optionId) {
        return option.label.isEmpty ? option.id : option.label;
      }
    }
    return optionId;
  }
}

class _QuizTranscriptRow extends StatelessWidget {
  const _QuizTranscriptRow({
    required this.item,
    required this.session,
    required this.pendingKeys,
    required this.recentStreamedAssistantText,
    required this.onChoice,
    required this.onQuizAnswer,
    required this.onRetryGeneration,
    required this.onReplay,
    required this.onLeave,
    required this.onTextRevealTick,
  });

  final _QuizTranscriptItem item;
  final InteractiveSessionState session;
  final Set<String> pendingKeys;
  final String? recentStreamedAssistantText;
  final ValueChanged<String> onChoice;
  final QuizAnswerCallback onQuizAnswer;
  final VoidCallback onRetryGeneration;
  final VoidCallback onReplay;
  final VoidCallback onLeave;
  final VoidCallback onTextRevealTick;

  @override
  Widget build(BuildContext context) {
    return switch (item.kind) {
      _QuizTranscriptItemKind.aiMessage => _ChatMessageBubble(
        child: _StreamingTranscriptText(
          id: _itemAnimationId(item),
          text: item.statusTitle ?? '',
          skipAnimation: _sameTranscriptText(
            item.statusTitle,
            recentStreamedAssistantText,
          ),
          onTick: onTextRevealTick,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.26,
          ),
        ),
      ),
      _QuizTranscriptItemKind.userMessage => _UserMessageBubble(
        text: item.userText ?? '',
        pending: item.isPending,
      ),
      _QuizTranscriptItemKind.choiceGroup => _ChoiceTranscriptBubble(
        prompt: item.choicePrompt ?? '',
        options: item.choiceOptions,
        turnId: item.choiceTurnId,
        pendingKeys: pendingKeys,
        onSelected: onChoice,
      ),
      _QuizTranscriptItemKind.pendingAssistant => const _ChatMessageBubble(
        child: _QuizLoadingContent(),
      ),
      _QuizTranscriptItemKind.streamingAssistant => _ChatMessageBubble(
        child: Text(
          item.statusTitle ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.26,
          ),
        ),
      ),
      _QuizTranscriptItemKind.question => _QuestionTranscriptBubble(
        question: item.question!,
        session: session,
        result: item.result,
        selectedAnswer: _selectedAnswer(item.question!.questionId),
        busyOptionId: _busyOptionId(item.question!.questionId),
        active: item.isActiveQuestion,
        onSelected: (optionId) =>
            onQuizAnswer(optionId, item.question!.questionId),
      ),
      _QuizTranscriptItemKind.progress => _ChatMessageBubble(
        child: _AnswerProgressContent(
          answeredCount: _intFromState(item.result?['answered_count']),
          eligibleCount: _intFromState(item.result?['eligible_count']),
        ),
      ),
      _QuizTranscriptItemKind.result => _QuizResultGroup(
        session: session,
        result: item.result ?? const <String, dynamic>{},
      ),
      _QuizTranscriptItemKind.finalStandings => _ChatMessageBubble(
        child: _FinalStandingsContent(
          session: session,
          onReplay: onReplay,
          onLeave: onLeave,
        ),
      ),
      _QuizTranscriptItemKind.status => _ChatMessageBubble(
        child: item.showLoading
            ? _QuizLoadingContent(title: item.statusTitle)
            : _QuizStatusContent(
                icon: item.statusIcon,
                title: item.statusTitle ?? 'Game update',
                body: item.statusBody ?? _lobbyText(session),
                animationId: item.statusTitle == 'Question failed to load'
                    ? null
                    : _itemAnimationId(item),
                onTextRevealTick: item.statusTitle == 'Question failed to load'
                    ? null
                    : onTextRevealTick,
                actionLabel: item.statusTitle == 'Question failed to load'
                    ? 'Retry'
                    : null,
                onAction: item.statusTitle == 'Question failed to load'
                    ? onRetryGeneration
                    : null,
              ),
      ),
    };
  }

  String _itemAnimationId(_QuizTranscriptItem item) {
    final eventId = item.event?.id ?? '';
    return '${item.kind.name}-${item.seq}-$eventId-${item.statusTitle ?? ''}';
  }

  String? _busyOptionId(String questionId) {
    final prefix = '$questionId-quiz_answer-';
    for (final key in pendingKeys) {
      if (key.startsWith(prefix)) return key.substring(prefix.length);
    }
    return null;
  }

  String? _selectedAnswer(String questionId) {
    if (item.answer?.questionId == questionId) return item.answer?.optionId;
    for (final event in session.events.reversed) {
      if (event.eventType != 'answer_submitted') continue;
      if ((event.payload['question_id'] as String?) != questionId) continue;
      return (event.payload['option_id'] as String?)?.trim();
    }
    return null;
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xED101112);
    const textColor = Colors.white;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: textColor),
            child: IconTheme.merge(
              data: IconThemeData(color: textColor),
              child: child,
            ),
          ),
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: _QuizBotAvatar(size: 20),
        ),
        const SizedBox(width: 6),
        Flexible(child: bubble),
      ],
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.text, this.pending = false});

  final String text;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.64;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Opacity(
                  opacity: pending ? 0.72 : 1,
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizBotAvatar extends StatelessWidget {
  const _QuizBotAvatar({this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.game_controller_solid,
          size: size * 0.58,
          color: const Color(0xFF22C55E),
        ),
      ),
    );
  }
}

class _QuestionTranscriptBubble extends StatelessWidget {
  const _QuestionTranscriptBubble({
    required this.question,
    required this.session,
    required this.result,
    required this.selectedAnswer,
    required this.busyOptionId,
    required this.active,
    required this.onSelected,
  });

  final _LiveQuizQuestion question;
  final InteractiveSessionState session;
  final Map<String, dynamic>? result;
  final String? selectedAnswer;
  final String? busyOptionId;
  final bool active;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (active) {
      return _LiveQuizQuestionGroup(
        question: question,
        session: session,
        selectedOptionId: selectedAnswer,
        busyOptionId: busyOptionId,
        onSelected: onSelected,
      );
    }
    return _PastQuizQuestionGroup(
      question: question,
      session: session,
      result: result,
    );
  }
}

class _ChoiceTranscriptBubble extends StatelessWidget {
  const _ChoiceTranscriptBubble({
    required this.prompt,
    required this.options,
    required this.turnId,
    required this.pendingKeys,
    required this.onSelected,
  });

  final String prompt;
  final List<InteractiveOption> options;
  final String? turnId;
  final Set<String> pendingKeys;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prompt.trim().isNotEmpty) ...[
                Text(
                  prompt.trim(),
                  style: TextStyle(
                    color: context.secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in options)
                    _QuickReplyButton(
                      option: option,
                      busy: pendingKeys.contains(
                        '$turnId-option_select-${option.id}',
                      ),
                      onTap: () => onSelected(option.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickReplyButton extends StatelessWidget {
  const _QuickReplyButton({
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
    final label = option.label.isEmpty ? option.id : option.label;
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.primaryTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.primaryTextColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamingTranscriptText extends StatelessWidget {
  const _StreamingTranscriptText({
    required this.id,
    required this.text,
    required this.style,
    required this.onTick,
    this.skipAnimation = false,
  });

  final String id;
  final String text;
  final TextStyle style;
  final VoidCallback onTick;
  final bool skipAnimation;

  @override
  Widget build(BuildContext context) {
    return _AnimatedQuestionText(
      questionId: id,
      text: text,
      style: style,
      skipAnimation: skipAnimation,
      onTick: onTick,
    );
  }
}

bool _sameTranscriptText(String? left, String? right) {
  final normalizedLeft = _normalizeTranscriptText(left);
  final normalizedRight = _normalizeTranscriptText(right);
  return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
}

String _normalizeTranscriptText(String? text) {
  return (text ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
}

class _AnimatedQuestionText extends StatefulWidget {
  const _AnimatedQuestionText({
    required this.questionId,
    required this.text,
    required this.style,
    this.skipAnimation = false,
    this.onComplete,
    this.onTick,
  });

  final String questionId;
  final String text;
  final TextStyle style;
  final bool skipAnimation;
  final VoidCallback? onComplete;
  final VoidCallback? onTick;

  @override
  State<_AnimatedQuestionText> createState() => _AnimatedQuestionTextState();
}

class _AnimatedQuestionTextState extends State<_AnimatedQuestionText> {
  static const _tick = Duration(milliseconds: 22);

  Timer? _timer;
  List<String> _symbols = const <String>[];
  int _visibleCount = 0;
  bool _didNotifyComplete = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _AnimatedQuestionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionId != widget.questionId ||
        oldWidget.text != widget.text ||
        oldWidget.skipAnimation != widget.skipAnimation) {
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _symbols = widget.text.runes
        .map((value) => String.fromCharCode(value))
        .toList(growable: false);
    _didNotifyComplete = false;

    if (_symbols.isEmpty) {
      _visibleCount = 0;
      _notifyComplete();
      return;
    }

    if (widget.skipAnimation || _symbols.length == 1) {
      _visibleCount = _symbols.length;
      _notifyComplete();
      return;
    }

    _visibleCount = 1;
    final step = _revealStep(_symbols.length);
    _timer = Timer.periodic(_tick, (timer) {
      if (!mounted) return;
      final nextCount = (_visibleCount + step).clamp(0, _symbols.length);
      if (nextCount == _visibleCount) return;
      setState(() => _visibleCount = nextCount);
      if (_visibleCount >= _symbols.length) {
        timer.cancel();
        _notifyComplete();
      }
      widget.onTick?.call();
    });
  }

  int _revealStep(int length) {
    if (length > 220) return 7;
    if (length > 150) return 5;
    if (length > 90) return 4;
    if (length > 50) return 3;
    if (length > 24) return 2;
    return 1;
  }

  void _notifyComplete() {
    if (_didNotifyComplete) return;
    _didNotifyComplete = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleText = _symbols.take(_visibleCount).join();
    return Text(visibleText, style: widget.style);
  }
}

class _PastQuizQuestionGroup extends StatelessWidget {
  const _PastQuizQuestionGroup({
    required this.question,
    required this.session,
    required this.result,
  });

  final _LiveQuizQuestion question;
  final InteractiveSessionState session;
  final Map<String, dynamic>? result;

  @override
  Widget build(BuildContext context) {
    final correctOptionId =
        (result?['correct_option_id'] as String?)?.trim() ??
        question.correctOptionId;
    final participantsByOption = _participantsByOption(session, result);
    final bubbleWidth = MediaQuery.sizeOf(context).width * 0.72;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((question.leadText ?? '').isNotEmpty) ...[
          _ChatMessageBubble(
            child: Text(
              question.leadText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.26,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _ChatMessageBubble(
          child: Text(
            question.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: SizedBox(
            width: bubbleWidth,
            child: Column(
              children: [
                for (final option in question.options) ...[
                  _ResultOptionRow(
                    option: option,
                    correct:
                        correctOptionId.isNotEmpty &&
                        option.id == correctOptionId,
                    participants:
                        participantsByOption[option.id] ??
                        const <StoryParticipant>[],
                  ),
                  if (option != question.options.last)
                    const SizedBox(height: 2),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserQuizAnswer {
  const _UserQuizAnswer({
    required this.questionId,
    required this.optionId,
    required this.optionLabel,
  });

  final String questionId;
  final String optionId;
  final String optionLabel;

  static _UserQuizAnswer? fromEvent(StorySessionEvent event) {
    final questionId = (event.payload['question_id'] as String?)?.trim() ?? '';
    final optionId = (event.payload['option_id'] as String?)?.trim() ?? '';
    final optionLabel =
        (event.payload['option_label'] as String?)?.trim() ?? optionId;
    if (questionId.isEmpty || optionId.isEmpty) return null;
    return _UserQuizAnswer(
      questionId: questionId,
      optionId: optionId,
      optionLabel: optionLabel,
    );
  }
}

class _AnswerProgressContent extends StatelessWidget {
  const _AnswerProgressContent({
    required this.answeredCount,
    required this.eligibleCount,
  });

  final int answeredCount;
  final int eligibleCount;

  @override
  Widget build(BuildContext context) {
    final total = eligibleCount <= 0 ? 1 : eligibleCount.clamp(1, 12);
    final answered = answeredCount.clamp(0, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$answeredCount/$eligibleCount players have locked in their answers',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < answered
                        ? const Color(0xFF63F26B)
                        : Colors.white.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (i != total - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuizLoadingContent extends StatefulWidget {
  const _QuizLoadingContent({this.title});

  final String? title;

  @override
  State<_QuizLoadingContent> createState() => _QuizLoadingContentState();
}

class _QuizLoadingContentState extends State<_QuizLoadingContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title?.trim() ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty &&
            title != 'Aura is getting the next question ready') ...[
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        SizedBox(
          width: 34,
          height: 14,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Opacity(
                      opacity: ((_controller.value * 3 - i).abs() < 0.55)
                          ? 1
                          : 0.34,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (i != 2) const SizedBox(width: 5),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuizStatusContent extends StatelessWidget {
  const _QuizStatusContent({
    this.icon,
    required this.title,
    required this.body,
    this.animationId,
    this.onTextRevealTick,
    this.actionLabel,
    this.onAction,
  });

  final IconData? icon;
  final String title;
  final String body;
  final String? animationId;
  final VoidCallback? onTextRevealTick;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: const Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: animationId == null || onTextRevealTick == null
                  ? Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : _StreamingTranscriptText(
                      id: animationId!,
                      text: title,
                      onTick: onTextRevealTick!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ],
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
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
    this.leadText,
    this.expiresAt,
    this.explanation,
  });

  final String questionId;
  final String text;
  final List<InteractiveOption> options;
  final String correctOptionId;
  final int currentRound;
  final int totalRounds;
  final String? leadText;
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
      leadText: (question['lead_text'] as String?)?.trim(),
      expiresAt: _parseQuizDate(question['expires_at']),
      explanation: (question['explanation'] as String?)?.trim(),
    );
  }

  static _LiveQuizQuestion? fromPayload(
    Map<String, dynamic> payload,
    Map<String, dynamic> state,
  ) {
    final raw = payload['question'];
    if (raw is! Map) return null;
    final question = raw.cast<String, dynamic>();
    final questionId = (question['question_id'] as String?)?.trim() ?? '';
    final text =
        (question['text'] as String?)?.trim() ??
        (question['question'] as String?)?.trim() ??
        '';
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
      correctOptionId: (question['correct_option_id'] as String?)?.trim() ?? '',
      currentRound:
          (payload['round'] as num?)?.toInt() ??
          (state['current_round'] as num?)?.toInt() ??
          1,
      totalRounds: (state['total_rounds'] as num?)?.toInt() ?? 1,
      leadText: (question['lead_text'] as String?)?.trim(),
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
  bool _questionRevealComplete = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _LiveQuizBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.questionId != widget.question.questionId) {
      _questionRevealComplete = false;
    }
    if (widget.selectedOptionId != null) {
      _questionRevealComplete = true;
    }
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
    final isExpired = question.expiresAt != null && seconds == 0;
    final skipReveal = _shouldSkipQuestionReveal(question, selected, seconds);
    final questionReady = _questionRevealComplete || skipReveal;
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
                child: _AnimatedQuestionText(
                  questionId: question.questionId,
                  text: question.text,
                  skipAnimation: skipReveal,
                  onComplete: () {
                    if (!_questionRevealComplete && mounted) {
                      setState(() => _questionRevealComplete = true);
                    }
                  },
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
          if (questionReady)
            for (final option in question.options) ...[
              _OptionButton(
                option: option,
                busy: widget.busyOptionId == option.id,
                disabled: answered || isExpired,
                status: _statusForOption(
                  option.id,
                  selected,
                  question.correctOptionId,
                ),
                onTap: () => widget.onSelected(option.id),
              ),
              if (option != question.options.last) const SizedBox(height: 8),
            ],
          if (isExpired && !answered) ...[
            const SizedBox(height: 12),
            Text(
              "Time's up",
              style: TextStyle(
                color: context.secondaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
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

class _LiveQuizContent extends StatefulWidget {
  const _LiveQuizContent({
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
  State<_LiveQuizContent> createState() => _LiveQuizContentState();
}

class _LiveQuizQuestionGroup extends StatefulWidget {
  const _LiveQuizQuestionGroup({
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
  State<_LiveQuizQuestionGroup> createState() => _LiveQuizQuestionGroupState();
}

class _LiveQuizQuestionGroupState extends State<_LiveQuizQuestionGroup> {
  Timer? _timer;
  String? _draftOptionId;
  bool _questionRevealComplete = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _LiveQuizQuestionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.questionId != widget.question.questionId) {
      _questionRevealComplete = false;
      _draftOptionId = null;
    }
    if (widget.selectedOptionId != null) {
      _questionRevealComplete = true;
      _draftOptionId = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final confirmedOptionId = widget.selectedOptionId;
    final selected = confirmedOptionId ?? _draftOptionId;
    final answered = confirmedOptionId != null;
    final seconds = _LiveQuizBlockState._remainingSeconds(question.expiresAt);
    final isExpired = question.expiresAt != null && seconds == 0;
    final skipReveal = _shouldSkipQuestionReveal(
      question,
      confirmedOptionId,
      seconds,
    );
    final questionReady = _questionRevealComplete || skipReveal;
    final bubbleWidth = MediaQuery.sizeOf(context).width * 0.72;
    final draftLabel = _draftOptionId == null
        ? null
        : _QuizTranscriptItem._optionLabel(question.options, _draftOptionId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((question.leadText ?? '').isNotEmpty) ...[
          _ChatMessageBubble(
            child: Text(
              question.leadText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.26,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _ChatMessageBubble(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AnimatedQuestionText(
                  questionId: question.questionId,
                  text: question.text,
                  skipAnimation: skipReveal,
                  onComplete: () {
                    if (!_questionRevealComplete && mounted) {
                      setState(() => _questionRevealComplete = true);
                    }
                  },
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.24,
                  ),
                ),
              ),
              if (question.expiresAt != null) ...[
                const SizedBox(width: 12),
                _QuizTimerRing(seconds: seconds),
              ],
            ],
          ),
        ),
        if (questionReady) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: SizedBox(
              width: bubbleWidth,
              child: Column(
                children: [
                  for (final option in question.options) ...[
                    _OptionButton(
                      option: option,
                      busy: widget.busyOptionId == option.id,
                      disabled: answered || isExpired,
                      quizStyle: true,
                      status: selected == option.id
                          ? _OptionStatus.selected
                          : null,
                      onTap: () {
                        if (answered || isExpired) return;
                        setState(() => _draftOptionId = option.id);
                      },
                    ),
                    if (option != question.options.last)
                      const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (questionReady &&
            _draftOptionId != null &&
            !answered &&
            !isExpired) ...[
          const SizedBox(height: 10),
          _ChatMessageBubble(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'You selected $draftLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 24,
                  child: FilledButton(
                    onPressed: widget.busyOptionId == _draftOptionId
                        ? null
                        : () => widget.onSelected(_draftOptionId!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111111),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: widget.busyOptionId == _draftOptionId
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isExpired && !answered)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 8),
            child: Text(
              "Time's up",
              style: TextStyle(
                color: context.secondaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuizTimerRing extends StatelessWidget {
  const _QuizTimerRing({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 5;
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: null,
            strokeWidth: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.20),
            valueColor: AlwaysStoppedAnimation<Color>(
              urgent ? const Color(0xFFEF4444) : const Color(0xFFF87171),
            ),
          ),
          Text(
            '${seconds}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveQuizContentState extends State<_LiveQuizContent> {
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
    final seconds = _LiveQuizBlockState._remainingSeconds(question.expiresAt);
    final isExpired = question.expiresAt != null && seconds == 0;
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

    return Column(
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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
                color: seconds <= 5 ? const Color(0xFFDC2626) : Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                '${seconds}s',
                style: TextStyle(
                  color: seconds <= 5
                      ? const Color(0xFFDC2626)
                      : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$answeredCount/$eligibleCount answered',
                style: const TextStyle(
                  color: Colors.white70,
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
            disabled: answered || isExpired,
            quizStyle: true,
            status: _LiveQuizBlockState._statusForOption(
              option.id,
              selected,
              question.correctOptionId,
            ),
            onTap: () => widget.onSelected(option.id),
          ),
          if (option != question.options.last) const SizedBox(height: 8),
        ],
        if (isExpired && !answered) ...[
          const SizedBox(height: 12),
          Text(
            "Time's up",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if (answered) ...[
          const SizedBox(height: 12),
          Text(
            isCorrect
                ? 'Correct'
                : 'Not quite. Correct answer: ${_LiveQuizBlockState._correctLabel(question)}',
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (answeredCount < eligibleCount) ...[
            const SizedBox(height: 8),
            Text(
              'Waiting for others...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _QuizResultGroup extends StatelessWidget {
  const _QuizResultGroup({required this.session, required this.result});

  final InteractiveSessionState session;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final correctOptionId = (result['correct_option_id'] as String?) ?? '';
    final explanation = (result['explanation'] as String?)?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChatMessageBubble(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Correct Answer: $correctOptionId',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (explanation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.25,
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

class _ResultOptionRow extends StatelessWidget {
  const _ResultOptionRow({
    required this.option,
    required this.correct,
    required this.participants,
  });

  final InteractiveOption option;
  final bool correct;
  final List<StoryParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final optionId = option.id.isEmpty ? '?' : option.id.toUpperCase();
    final label = option.label.isEmpty ? option.id : option.label;
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF0131415),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: correct
              ? const Color(0xFFF59E0B)
              : Colors.white.withValues(alpha: 0.04),
          width: correct ? 1.2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: correct
                  ? const Color(0xFFF59E0B)
                  : Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              optionId.substring(0, 1),
              style: TextStyle(
                color: correct ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: correct ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (participants.isNotEmpty)
            _ParticipantAvatarStack(participants: participants),
        ],
      ),
    );
  }
}

class _ParticipantAvatarStack extends StatelessWidget {
  const _ParticipantAvatarStack({required this.participants});

  final List<StoryParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final visible = participants.take(4).toList();
    return SizedBox(
      width: (visible.length * 16) + 6,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              right: i * 14,
              top: 0,
              child: _ParticipantAvatar(participant: visible[i]),
            ),
        ],
      ),
    );
  }
}

Map<String, List<StoryParticipant>> _participantsByOption(
  InteractiveSessionState session,
  Map<String, dynamic>? result,
) {
  final answerRows = ((result?['answers'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>());
  final participantsByOption = <String, List<StoryParticipant>>{};
  for (final answer in answerRows) {
    final optionId = (answer['option_id'] as String?)?.trim() ?? '';
    final participant = _participantById(
      session.participants,
      answer['participant_id'] as String?,
    );
    if (optionId.isEmpty || participant == null) continue;
    participantsByOption.putIfAbsent(optionId, () => []).add(participant);
  }
  return participantsByOption;
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.participant});

  final StoryParticipant participant;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl(participant);
    final name = _displayName(participant);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF111111), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }

  static String? _avatarUrl(StoryParticipant participant) {
    for (final key in const [
      'avatar_url',
      'avatarUrl',
      'photo_url',
      'photoUrl',
      'image_url',
      'profile_image_url',
    ]) {
      final value = participant.metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

class _FinalStandingsContent extends StatelessWidget {
  const _FinalStandingsContent({
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

    return Column(
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
                  fontSize: 17,
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
    );
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
                color: Colors.white70,
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

bool _shouldSkipQuestionReveal(
  _LiveQuizQuestion question,
  String? selectedOptionId,
  int secondsRemaining,
) {
  if (selectedOptionId != null) return true;
  if (question.expiresAt != null && secondsRemaining <= 6) return true;
  return false;
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

StoryParticipant? _participantById(
  List<StoryParticipant> participants,
  String? id,
) {
  for (final participant in participants) {
    if (participant.id == id) return participant;
  }
  return null;
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
    this.disabled = false,
    this.quizStyle = false,
    this.status,
    required this.onTap,
  });

  final InteractiveOption option;
  final bool busy;
  final bool disabled;
  final bool quizStyle;
  final _OptionStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    if (quizStyle) return _buildQuizStyle(context);
    final color = switch (status) {
      _OptionStatus.correct => const Color(0xFF16A34A),
      _OptionStatus.incorrect => const Color(0xFFDC2626),
      _OptionStatus.selected => const Color(0xFF2563EB),
      null => null,
    };
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy || disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          foregroundColor: context.primaryTextColor,
          disabledForegroundColor: color ?? context.secondaryTextColor,
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

  Widget _buildQuizStyle(BuildContext context) {
    final accent = switch (status) {
      _OptionStatus.selected => const Color(0xFFF59E0B),
      _OptionStatus.correct => const Color(0xFF16A34A),
      _OptionStatus.incorrect => const Color(0xFFDC2626),
      null => null,
    };
    final optionId = option.id.isEmpty ? '?' : option.id.toUpperCase();
    final label = option.label.isEmpty ? option.id : option.label;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy || disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          side: BorderSide(
            color: accent ?? Colors.white.withValues(alpha: 0.04),
            width: accent == null ? 1 : 1.2,
          ),
          backgroundColor: const Color(0xF0131415),
          disabledBackgroundColor: const Color(0xE5131415),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: accent ?? Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                optionId.substring(0, 1),
                style: TextStyle(
                  color: accent == null ? Colors.white70 : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: accent == null ? Colors.white70 : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
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
