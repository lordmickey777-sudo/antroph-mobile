import 'dart:async';
import 'dart:math' as math;

import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/story/models/interactive_story_models.dart';
import 'package:antroph_mobile/features/story/providers/interactive_story_provider.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _historySurface = Color(0xF2101112);
const _historyMutedSurface = Color(0xE51A1B1D);

enum SoloInteractiveLaunchAction { continueSession, startFresh, viewHistory }

class SoloInteractiveLaunchResult {
  const SoloInteractiveLaunchResult({required this.action, this.sessionId});

  final SoloInteractiveLaunchAction action;
  final String? sessionId;
}

Future<SoloInteractiveLaunchResult?> showSoloInteractiveLauncherSheet(
  BuildContext context, {
  required String storyId,
}) {
  return showModalBottomSheet<SoloInteractiveLaunchResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SoloInteractiveLauncherSheet(storyId: storyId),
  );
}

class _SoloInteractiveLauncherSheet extends ConsumerStatefulWidget {
  const _SoloInteractiveLauncherSheet({required this.storyId});

  final String storyId;

  @override
  ConsumerState<_SoloInteractiveLauncherSheet> createState() =>
      _SoloInteractiveLauncherSheetState();
}

class _SoloInteractiveLauncherSheetState
    extends ConsumerState<_SoloInteractiveLauncherSheet> {
  List<SoloInteractiveSessionSummary> _history =
      const <SoloInteractiveSessionSummary>[];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = ref
        .read(interactiveStoryProvider.notifier)
        .cachedSoloHistory(storyId: widget.storyId);
    if (cached != null) _history = cached;
    unawaited(_loadHistory());
  }

  SoloInteractiveSessionSummary? get _latestSession {
    for (final session in _history) {
      if (session.isResumable) return session;
    }
    return null;
  }

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final history = await ref
          .read(interactiveStoryProvider.notifier)
          .fetchSoloHistory(
            storyId: widget.storyId,
            limit: 50,
            forceRefresh: forceRefresh,
          );
      if (!mounted) return;
      setState(() => _history = history);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pop(SoloInteractiveLaunchResult result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final surface = isDark ? const Color(0xFF111315) : Colors.white;
    final mutedText = isDark ? Colors.white60 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black;
    final latest = _latestSession;
    final error = _error?.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(constraints.maxWidth, 520.0);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(
                    width: width,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TypographyText(
                          latest == null
                              ? 'Start solo interactivity'
                              : 'Pick up where you stopped',
                          variant: TypographyVariant.h3,
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        const SizedBox(height: 8),
                        TypographyText(
                          latest == null
                              ? 'Start fresh, or open your solo history if you have older sessions.'
                              : latest.displayTopic,
                          variant: TypographyVariant.body2,
                          color: mutedText,
                          fontSize: 14,
                        ),
                        if (_isLoading) ...[
                          const SizedBox(height: 14),
                          LinearProgressIndicator(
                            minHeight: 3,
                            color: const Color(0xFF22C55E),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ],
                        if (error != null && error.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _InlineError(
                            message: error,
                            onRetry: () =>
                                unawaited(_loadHistory(forceRefresh: true)),
                          ),
                        ],
                        const SizedBox(height: 22),
                        if (latest != null) ...[
                          _SoloLauncherTile(
                            key: const ValueKey('continue-solo-session'),
                            icon: CupertinoIcons.play_fill,
                            title: 'Continue last session',
                            subtitle: latest.displayTopic,
                            enabled: !_isLoading,
                            onTap: () => _pop(
                              SoloInteractiveLaunchResult(
                                action:
                                    SoloInteractiveLaunchAction.continueSession,
                                sessionId: latest.sessionId,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _SoloLauncherTile(
                          key: const ValueKey('start-fresh-solo-session'),
                          icon: CupertinoIcons.add,
                          title: 'Start a new session',
                          subtitle: 'Choose a fresh topic and begin again.',
                          enabled: !_isLoading,
                          onTap: () => _pop(
                            const SoloInteractiveLaunchResult(
                              action: SoloInteractiveLaunchAction.startFresh,
                            ),
                          ),
                        ),
                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SoloLauncherTile(
                            key: const ValueKey('view-solo-history'),
                            icon: CupertinoIcons.clock,
                            title: 'View session history',
                            subtitle: 'Browse older solo sessions.',
                            enabled: !_isLoading,
                            onTap: () => _pop(
                              const SoloInteractiveLaunchResult(
                                action: SoloInteractiveLaunchAction.viewHistory,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SoloLauncherTile extends StatelessWidget {
  const _SoloLauncherTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TypographyText(
                        title,
                        variant: TypographyVariant.body1,
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      const SizedBox(height: 3),
                      TypographyText(
                        subtitle,
                        variant: TypographyVariant.body2,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 12,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SoloInteractiveSessionLauncher extends StatelessWidget {
  const SoloInteractiveSessionLauncher({
    super.key,
    required this.latestSession,
    required this.hasHistory,
    required this.isBusy,
    required this.onContinue,
    required this.onStartFresh,
    required this.onViewHistory,
    required this.onRetry,
    this.error,
  });

  final SoloInteractiveSessionSummary? latestSession;
  final bool hasHistory;
  final bool isBusy;
  final VoidCallback onContinue;
  final VoidCallback onStartFresh;
  final VoidCallback onViewHistory;
  final VoidCallback onRetry;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactText = textScale > 1.25;
    final latest = latestSession;

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 560 && !compactText;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 380 ? 16 : 24,
              20,
              constraints.maxWidth < 380 ? 16 : 24,
              20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 40
                    ? constraints.maxHeight - 40
                    : 0,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _historySurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        constraints.maxWidth < 380 ? 18 : 22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            CupertinoIcons.clock,
                            color: Color(0xFF22C55E),
                            size: 28,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            latest == null
                                ? 'Start a solo session'
                                : 'Pick up where you stopped',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            latest == null
                                ? 'Choose a new topic, or revisit one of your previous sessions.'
                                : latest.displayTopic,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (latest != null) ...[
                            const SizedBox(height: 12),
                            _SessionMetaRow(session: latest),
                          ],
                          if (error?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 14),
                            _InlineError(message: error!, onRetry: onRetry),
                          ],
                          const SizedBox(height: 20),
                          if (horizontal)
                            Row(
                              children: [
                                if (latest != null) ...[
                                  Expanded(
                                    child: _HistoryActionButton(
                                      key: const ValueKey(
                                        'continue-solo-session',
                                      ),
                                      label: 'Continue',
                                      icon: CupertinoIcons.play_fill,
                                      primary: true,
                                      busy: isBusy,
                                      onPressed: onContinue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: _HistoryActionButton(
                                    key: const ValueKey(
                                      'start-fresh-solo-session',
                                    ),
                                    label: 'Start fresh',
                                    icon: CupertinoIcons.add,
                                    busy: isBusy,
                                    onPressed: onStartFresh,
                                  ),
                                ),
                                if (hasHistory) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _HistoryActionButton(
                                      key: const ValueKey('view-solo-history'),
                                      label: 'History',
                                      icon: CupertinoIcons.clock,
                                      busy: isBusy,
                                      onPressed: onViewHistory,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (latest != null) ...[
                                  _HistoryActionButton(
                                    key: const ValueKey(
                                      'continue-solo-session',
                                    ),
                                    label: 'Continue last session',
                                    icon: CupertinoIcons.play_fill,
                                    primary: true,
                                    busy: isBusy,
                                    onPressed: onContinue,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                _HistoryActionButton(
                                  key: const ValueKey(
                                    'start-fresh-solo-session',
                                  ),
                                  label: 'Start a new session',
                                  icon: CupertinoIcons.add,
                                  busy: isBusy,
                                  onPressed: onStartFresh,
                                ),
                                if (hasHistory) ...[
                                  const SizedBox(height: 10),
                                  _HistoryActionButton(
                                    key: const ValueKey('view-solo-history'),
                                    label: 'View session history',
                                    icon: CupertinoIcons.clock,
                                    busy: isBusy,
                                    onPressed: onViewHistory,
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SoloInteractiveSessionHistoryView extends StatelessWidget {
  const SoloInteractiveSessionHistoryView({
    super.key,
    required this.sessions,
    required this.isBusy,
    required this.onBack,
    required this.onSelect,
    required this.onStartFresh,
    required this.onRetry,
    this.error,
  });

  final List<SoloInteractiveSessionSummary> sessions;
  final bool isBusy;
  final VoidCallback onBack;
  final ValueChanged<SoloInteractiveSessionSummary> onSelect;
  final VoidCallback onStartFresh;
  final VoidCallback onRetry;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 380 ? 14.0 : 22.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  14,
                ),
                child: CustomScrollView(
                  key: const ValueKey('solo-history-list'),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HistoryHeader(
                        isBusy: isBusy,
                        onBack: onBack,
                        onStartFresh: onStartFresh,
                      ),
                    ),
                    if (error?.trim().isNotEmpty == true) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverToBoxAdapter(
                        child: _InlineError(message: error!, onRetry: onRetry),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (sessions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyHistory(onStartFresh: onStartFresh),
                      )
                    else
                      SliverList.separated(
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return _HistorySessionCard(
                            session: session,
                            enabled: !isBusy,
                            onTap: () => onSelect(session),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.isBusy,
    required this.onBack,
    required this.onStartFresh,
  });

  final bool isBusy;
  final VoidCallback onBack;
  final VoidCallback onStartFresh;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _historySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('close-solo-history'),
              onPressed: isBusy ? null : onBack,
              tooltip: 'Back',
              color: Colors.white,
              icon: const Icon(CupertinoIcons.back),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solo session history',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Continue a session or open its recent transcript.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('history-start-fresh-session'),
              onPressed: isBusy ? null : onStartFresh,
              tooltip: 'Start a new session',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(CupertinoIcons.add),
            ),
          ],
        ),
      ),
    );
  }
}

class SoloHistoryReadOnlyBanner extends StatelessWidget {
  const SoloHistoryReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            key: const ValueKey('solo-history-read-only-banner'),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: _historySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.lock_fill, size: 15, color: Colors.white70),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Recent transcript · Read only',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({
    required this.session,
    required this.enabled,
    required this.onTap,
  });

  final SoloInteractiveSessionSummary session;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = session.isCompleted
        ? 'Completed'
        : session.isPaused
        ? 'Paused'
        : 'Active';
    final statusColor = session.isCompleted
        ? Colors.white54
        : const Color(0xFF22C55E);
    final mode = _historyModeLabel(session);

    return Semantics(
      button: true,
      label: '${session.displayTopic}, $status',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('solo-history-session-${session.sessionId}'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: _historyMutedSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    session.isCompleted
                        ? CupertinoIcons.book_fill
                        : CupertinoIcons.play_fill,
                    color: statusColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayTopic,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (session.preview?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 5),
                        Text(
                          session.preview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          _MetaPill(label: status, color: statusColor),
                          _MetaPill(label: mode),
                          if (_showHistoryRound(session))
                            _MetaPill(label: 'Round ${session.currentRound}'),
                          _MetaPill(
                            label: _friendlyActivityDate(
                              session.lastActivityAt,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  session.isCompleted
                      ? CupertinoIcons.eye_fill
                      : CupertinoIcons.chevron_right,
                  color: Colors.white54,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionMetaRow extends StatelessWidget {
  const _SessionMetaRow({required this.session});

  final SoloInteractiveSessionSummary session;

  @override
  Widget build(BuildContext context) {
    final mode = _historyModeLabel(session);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _MetaPill(
          label: session.isPaused ? 'Paused' : 'Ready to continue',
          color: const Color(0xFF22C55E),
        ),
        _MetaPill(label: mode),
        if (_showHistoryRound(session))
          _MetaPill(label: 'Round ${session.currentRound}'),
        _MetaPill(label: _friendlyActivityDate(session.lastActivityAt)),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.color = Colors.white60});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryActionButton extends StatelessWidget {
  const _HistoryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: primary ? Colors.white : _historyMutedSurface,
        foregroundColor: primary ? Colors.black : Colors.white,
        disabledBackgroundColor: Colors.white12,
        disabledForegroundColor: Colors.white38,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: primary ? Colors.transparent : Colors.white12,
          ),
        ),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 17),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFFCA5A5).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFFCA5A5),
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onStartFresh});

  final VoidCallback onStartFresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _historySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.clock,
                  color: Colors.white60,
                  size: 30,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No solo sessions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your paused and completed sessions will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, height: 1.35),
                ),
                const SizedBox(height: 18),
                _HistoryActionButton(
                  label: 'Start a new session',
                  icon: CupertinoIcons.add,
                  primary: true,
                  busy: false,
                  onPressed: onStartFresh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyActivityDate(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final days = today.difference(date).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days > 1 && days < 7) return '$days days ago';
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String _historyModeLabel(SoloInteractiveSessionSummary session) {
  return switch (session.viewMode?.trim().toLowerCase()) {
    'chat' => 'Chat',
    'quiz' => 'Quiz',
    _ => 'Choosing topic',
  };
}

bool _showHistoryRound(SoloInteractiveSessionSummary session) {
  return session.viewMode?.trim().toLowerCase() == 'quiz' &&
      session.currentRound > 0;
}
