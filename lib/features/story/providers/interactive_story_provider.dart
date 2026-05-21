import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_formatter.dart';
import '../models/interactive_story_models.dart';
import 'story_providers.dart';

class InteractiveStoryState {
  const InteractiveStoryState({
    this.session,
    this.isLoading = false,
    this.pendingInputKeys = const <String>{},
    this.error,
  });

  final InteractiveSessionState? session;
  final bool isLoading;
  final Set<String> pendingInputKeys;
  final String? error;

  InteractiveStoryState copyWith({
    InteractiveSessionState? session,
    bool? isLoading,
    Set<String>? pendingInputKeys,
    Object? error = _unset,
  }) {
    return InteractiveStoryState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      pendingInputKeys: pendingInputKeys ?? this.pendingInputKeys,
      error: error == _unset ? this.error : error as String?,
    );
  }
}

const _unset = Object();

class InteractiveStoryNotifier extends Notifier<InteractiveStoryState> {
  @override
  InteractiveStoryState build() => const InteractiveStoryState();

  String get _deviceType => Platform.isIOS ? 'ios' : 'android';
  String get _deviceId => 'mobile-app';

  Future<void> start({
    required String storyId,
    required String interactionMode,
    String? sessionType,
  }) async {
    if (state.isLoading) return;
    final existing = state.session;
    if (existing != null && existing.storyId == storyId) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.startInteractiveSession(
        storyId: storyId,
        deviceType: _deviceType,
        deviceId: _deviceId,
        sessionType:
            sessionType ?? (interactionMode == 'group' ? 'group' : 'solo'),
      );
      state = InteractiveStoryState(session: session);
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> joinByCode(String joinCode, {String? displayName}) async {
    final code = joinCode.trim();
    if (code.isEmpty || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.joinInteractiveSessionByCode(
        joinCode: code,
        deviceType: _deviceType,
        deviceId: _deviceId,
        displayName: displayName,
      );
      state = InteractiveStoryState(session: session);
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> refresh() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(storiesRepositoryProvider);
      final session = await repo.fetchInteractiveSession(sessionId);
      state = InteractiveStoryState(session: session);
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> submitOption({
    required String optionId,
    required String inputType,
  }) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final key =
        '${state.session?.currentTurn?.turnId ?? state.session?.lastSeq}-$inputType-$optionId';
    if (state.pendingInputKeys.contains(key)) return;

    state = state.copyWith(
      pendingInputKeys: {...state.pendingInputKeys, key},
      error: null,
    );

    try {
      final repo = ref.read(storiesRepositoryProvider);
      final response = await repo.submitInteractiveInput(
        sessionId: sessionId,
        input: InteractiveInput(
          inputType: inputType,
          optionId: optionId,
          idempotencyKey: key,
        ),
      );
      final current = state.session;
      if (current == null) return;
      final nextEvents = [...current.events, response.event];
      if (response.turn != null) {
        nextEvents.add(
          StorySessionEvent(
            id: response.turn!.turnId,
            sessionId: sessionId,
            seq: response.turn!.seq,
            actorType: 'ai',
            eventType: 'interactive_turn',
            payload: response.turn!.toJson(),
          ),
        );
      }
      state = state.copyWith(
        session: current.copyWith(
          interactiveState: response.state,
          events: nextEvents,
          currentTurn: response.turn ?? current.currentTurn,
          lastSeq: response.turn?.seq ?? response.event.seq,
        ),
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        error: '$e',
      );
    }
  }

  Future<void> submitText(String text) async {
    final sessionId = state.session?.sessionId;
    final trimmed = text.trim();
    if (sessionId == null || sessionId.isEmpty || trimmed.isEmpty) return;
    final key =
        '${state.session?.currentTurn?.turnId ?? state.session?.lastSeq}-text-${DateTime.now().millisecondsSinceEpoch}';

    state = state.copyWith(
      pendingInputKeys: {...state.pendingInputKeys, key},
      error: null,
    );

    try {
      final repo = ref.read(storiesRepositoryProvider);
      final response = await repo.submitInteractiveInput(
        sessionId: sessionId,
        input: InteractiveInput(
          inputType: 'text',
          text: trimmed,
          idempotencyKey: key,
        ),
      );
      final current = state.session;
      if (current == null) return;
      final nextEvents = [...current.events, response.event];
      if (response.turn != null) {
        nextEvents.add(
          StorySessionEvent(
            id: response.turn!.turnId,
            sessionId: sessionId,
            seq: response.turn!.seq,
            actorType: 'ai',
            eventType: 'interactive_turn',
            payload: response.turn!.toJson(),
          ),
        );
      }
      state = state.copyWith(
        session: current.copyWith(
          interactiveState: response.state,
          events: nextEvents,
          currentTurn: response.turn ?? current.currentTurn,
          lastSeq: response.turn?.seq ?? response.event.seq,
        ),
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        pendingInputKeys: {...state.pendingInputKeys}..remove(key),
        error: '$e',
      );
    }
  }

  void clear() {
    state = const InteractiveStoryState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final interactiveStoryProvider =
    NotifierProvider.autoDispose<
      InteractiveStoryNotifier,
      InteractiveStoryState
    >(InteractiveStoryNotifier.new);
