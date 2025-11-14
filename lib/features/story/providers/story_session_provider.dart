import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../data/stories_repository.dart';
import '../models/story_session.dart';
import '../../../core/network/error_formatter.dart';
import 'story_providers.dart';

/// State for story session management
class StorySessionState {
  const StorySessionState({this.session, this.isLoading = false, this.error});

  final StorySession? session;
  final bool isLoading;
  final String? error;

  StorySessionState copyWith({StorySession? session, bool? isLoading, String? error}) {
    return StorySessionState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  StorySessionState clearError() {
    return StorySessionState(session: session, isLoading: isLoading, error: null);
  }
}

/// Notifier for managing story session state
class StorySessionNotifier extends Notifier<StorySessionState> {
  late final StoriesRepository _repository;

  @override
  StorySessionState build() {
    _repository = ref.read(storiesRepositoryProvider);
    return const StorySessionState();
  }

  /// Get basic device information
  Map<String, String> _getDeviceInfo() {
    return {
      'deviceType': Platform.operatingSystem,
      'deviceId': 'mobile-app', // Simple identifier; can be enhanced later
    };
  }

  /// Start or resume a story session
  Future<void> startSession(String storyId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deviceInfo = _getDeviceInfo();
      final session = await _repository.startSession(
        storyId: storyId,
        deviceType: deviceInfo['deviceType']!,
        deviceId: deviceInfo['deviceId']!,
      );
      state = StorySessionState(session: session, isLoading: false);
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to start session: $e');
    }
  }

  /// Pause the current session
  Future<void> pauseSession(String storyId) async {
    if (state.session == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await _repository.pauseSession(storyId);
      state = StorySessionState(session: session, isLoading: false);
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to pause session: $e');
    }
  }

  /// Resume (play) the current session
  Future<void> playSession(String storyId) async {
    if (state.session == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await _repository.playSession(storyId);
      state = StorySessionState(session: session, isLoading: false);
    } on ApiError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to resume session: $e');
    }
  }

  /// Clear the current session
  void clearSession() {
    state = const StorySessionState();
  }

  /// Clear error message
  void clearError() {
    state = state.clearError();
  }
}

/// Provider for story session management
final storySessionProvider = NotifierProvider<StorySessionNotifier, StorySessionState>(
  StorySessionNotifier.new,
);
