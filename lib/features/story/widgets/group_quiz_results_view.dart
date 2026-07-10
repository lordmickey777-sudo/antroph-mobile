import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../../core/theme/theme_provider.dart';
import '../models/interactive_story_models.dart';

class GroupQuizScoreEntry {
  const GroupQuizScoreEntry({
    required this.rank,
    required this.participantId,
    required this.userId,
    required this.name,
    required this.score,
    required this.roundDelta,
    required this.participant,
  });

  final int rank;
  final String participantId;
  final String? userId;
  final String name;
  final int score;
  final int roundDelta;
  final StoryParticipant? participant;
}

List<GroupQuizScoreEntry> groupQuizScoresFromSession(
  InteractiveSessionState session,
) {
  final state = session.interactiveState;
  final result = (state['result'] as Map?)?.cast<String, dynamic>();
  final rawStandings =
      ((state['final_standings'] as List?) ??
              (state['standings'] as List?) ??
              (result?['standings'] as List?) ??
              const [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
  final rawScores =
      ((state['scores'] as Map?) ?? (result?['scores'] as Map?) ?? const {})
          .cast<dynamic, dynamic>();
  final rawDeltas =
      ((state['score_delta'] as Map?) ??
              (result?['score_delta'] as Map?) ??
              const {})
          .cast<dynamic, dynamic>();
  final participantsById = <String, StoryParticipant>{
    for (final participant in session.participants) participant.id: participant,
  };
  final rows = <GroupQuizScoreEntry>[];
  final includedParticipantIds = <String>{};

  for (final raw in rawStandings) {
    final participantId = (raw['participant_id'] as String?)?.trim() ?? '';
    final participant = participantsById[participantId];
    final name = (raw['display_name'] as String?)?.trim();
    rows.add(
      GroupQuizScoreEntry(
        rank: _asInt(raw['rank'], fallback: rows.length + 1),
        participantId: participantId,
        userId:
            (raw['user_id'] as String?)?.trim() ?? participant?.userId?.trim(),
        name: name?.isNotEmpty == true
            ? name!
            : _participantDisplayName(participant, fallback: rows.length + 1),
        score: _asInt(
          raw['score'],
          fallback: _asInt(
            rawScores[participantId],
            fallback: participant?.score,
          ),
        ),
        roundDelta: _asInt(rawDeltas[participantId]),
        participant: participant,
      ),
    );
    if (participantId.isNotEmpty) includedParticipantIds.add(participantId);
  }

  for (final participant in session.participants) {
    if (includedParticipantIds.contains(participant.id)) continue;
    rows.add(
      GroupQuizScoreEntry(
        rank: rows.length + 1,
        participantId: participant.id,
        userId: participant.userId,
        name: _participantDisplayName(participant, fallback: rows.length + 1),
        score: _asInt(rawScores[participant.id], fallback: participant.score),
        roundDelta: _asInt(rawDeltas[participant.id]),
        participant: participant,
      ),
    );
  }

  rows.sort((left, right) {
    final byScore = right.score.compareTo(left.score);
    if (byScore != 0) return byScore;
    final byRank = left.rank.compareTo(right.rank);
    if (byRank != 0) return byRank;
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });

  final ranked = <GroupQuizScoreEntry>[];
  var rank = 0;
  int? previousScore;
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    if (row.score != previousScore) {
      rank = index + 1;
      previousScore = row.score;
    }
    ranked.add(
      GroupQuizScoreEntry(
        rank: rank,
        participantId: row.participantId,
        userId: row.userId,
        name: row.name,
        score: row.score,
        roundDelta: row.roundDelta,
        participant: row.participant,
      ),
    );
  }
  return ranked;
}

Future<void> showGroupQuizResultsBottomSheet(
  BuildContext context, {
  required InteractiveSessionState session,
  String? currentUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.9,
      child: GroupQuizResultsView(
        session: session,
        currentUserId: currentUserId,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    ),
  );
}

class GroupQuizResultsView extends StatelessWidget {
  const GroupQuizResultsView({
    super.key,
    required this.session,
    required this.onClose,
    this.currentUserId,
  });

  final InteractiveSessionState session;
  final String? currentUserId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final entries = groupQuizScoresFromSession(session);
    final currentRound = _asInt(session.interactiveState['current_round']);
    final totalRounds = _asInt(
      session.interactiveState['total_rounds'],
      fallback: currentRound,
    );

    return Material(
      key: const ValueKey('group-quiz-results-sheet'),
      color: AppTheme.searchInputBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ResultsHeader(onClose: onClose),
          Expanded(
            child: ListView(
              key: const ValueKey('group-quiz-results-list'),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              children: [
                _ScoreAvatarCluster(entries: entries),
                const SizedBox(height: 8),
                Text(
                  entries.isEmpty ? '0 pts' : '${entries.first.score} pts',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentRound > 0 && totalRounds > 0
                      ? 'Top score  •  $currentRound of $totalRounds rounds'
                      : 'Top score',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Player scores',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  const _EmptyScores()
                else
                  for (final entry in entries)
                    _PlayerScoreRow(
                      entry: entry,
                      isCurrentUser: _isCurrentUser(entry, currentUserId),
                    ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('group-quiz-results-done'),
                onPressed: onClose,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      child: Row(
        children: [
          TextButton.icon(
            key: const ValueKey('group-quiz-results-back'),
            onPressed: onClose,
            icon: const Icon(CupertinoIcons.chevron_left, size: 16),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              'Final results',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('group-quiz-results-close'),
            onPressed: onClose,
            tooltip: 'Close results',
            icon: const Icon(CupertinoIcons.xmark, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreAvatarCluster extends StatelessWidget {
  const _ScoreAvatarCluster({required this.entries});

  final List<GroupQuizScoreEntry> entries;

  static const _alignments = <Alignment>[
    Alignment(-0.82, 0.34),
    Alignment(-0.48, -0.42),
    Alignment(0.48, -0.48),
    Alignment(0.84, 0.34),
    Alignment(-0.34, 0.70),
    Alignment(0.38, 0.74),
  ];

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox(height: 104);
    }
    final surrounding = entries.skip(1).take(_alignments.length).toList();
    return SizedBox(
      height: 112,
      child: Stack(
        children: [
          for (var index = 0; index < surrounding.length; index++)
            Align(
              alignment: _alignments[index],
              child: _ScoreAvatar(
                entry: surrounding[index],
                size: index < 2 ? 38 : 30,
              ),
            ),
          Align(
            alignment: const Alignment(0, 0.10),
            child: _ScoreAvatar(entry: entries.first, size: 68, winner: true),
          ),
        ],
      ),
    );
  }
}

class _PlayerScoreRow extends StatelessWidget {
  const _PlayerScoreRow({required this.entry, required this.isCurrentUser});

  final GroupQuizScoreEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final role = entry.participant?.role.toLowerCase();
    final details = <String>[
      if (isCurrentUser) 'You',
      if (role == 'host') 'Host',
      if (entry.roundDelta > 0) '+${entry.roundDelta} this round',
    ];
    if (details.isEmpty) details.add('Player');

    return Container(
      key: ValueKey('group-score-row-${entry.participantId}'),
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: entry.rank == 1
                    ? const Color(0xFF7C3AED)
                    : Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _ScoreAvatar(entry: entry, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${entry.score} pts',
            key: ValueKey('group-score-value-${entry.participantId}'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreAvatar extends StatelessWidget {
  const _ScoreAvatar({
    required this.entry,
    required this.size,
    this.winner = false,
  });

  final GroupQuizScoreEntry entry;
  final double size;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _participantAvatarUrl(entry.participant);
    final initial = entry.name.trim().isEmpty
        ? '?'
        : entry.name.trim().substring(0, 1).toUpperCase();
    final fallback = ColoredBox(
      color: _avatarColor(entry.participantId),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: winner ? const Color(0xFF7C3AED) : Colors.white,
          width: winner ? 4 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: winner ? 14 : 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null
          ? fallback
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class _EmptyScores extends StatelessWidget {
  const _EmptyScores();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'No player scores were recorded.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white60,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

bool _isCurrentUser(GroupQuizScoreEntry entry, String? currentUserId) {
  final normalized = currentUserId?.trim();
  if (normalized == null || normalized.isEmpty) return false;
  return entry.userId == normalized || entry.participant?.userId == normalized;
}

String _participantDisplayName(
  StoryParticipant? participant, {
  required int fallback,
}) {
  final name = participant?.displayName?.trim();
  return name?.isNotEmpty == true ? name! : 'Player $fallback';
}

String? _participantAvatarUrl(StoryParticipant? participant) {
  if (participant == null) return null;
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

Color _avatarColor(String seed) {
  const colors = [
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFFDB2777),
    Color(0xFF059669),
    Color(0xFFEA580C),
    Color(0xFF4F46E5),
  ];
  final hash = seed.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return colors[hash.abs() % colors.length];
}

int _asInt(dynamic value, {int? fallback}) {
  if (value is num) return value.toInt();
  return fallback ?? 0;
}
