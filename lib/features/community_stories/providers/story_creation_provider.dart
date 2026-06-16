import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_story_model.dart';
import '../models/rive_element_model.dart';
import 'community_stories_providers.dart';

class StoryCreationState {
  const StoryCreationState({
    this.title = '',
    this.description = '',
    this.context = '',
    this.themes = const [],
    this.characters = const [],
    this.tone = 'neutral',
    this.targetLength = 10,
    this.tags = const [],
    this.interactionMode = 'narrative',
    this.aiRole = 'narrator',
    this.interactiveTemplate = 'open_story',
    this.maxPlayers = 4,
    this.timerEnabled = false,
    this.scoringEnabled = false,
    this.interactionRules = '',
    this.selectedRiveElement,
    this.coverImage,
    this.isSubmitting = false,
    this.error,
    this.createdStory,
  });

  final String title;
  final String description;
  final String context;
  final List<String> themes;
  final List<String> characters;
  final String tone;
  final int targetLength;
  final List<String> tags;
  final String interactionMode;
  final String aiRole;
  final String interactiveTemplate;
  final int maxPlayers;
  final bool timerEnabled;
  final bool scoringEnabled;
  final String interactionRules;
  final RiveElementDto? selectedRiveElement;
  final File? coverImage;
  final bool isSubmitting;
  final String? error;
  final CommunityStoryDto? createdStory;

  bool get isValid => title.trim().isNotEmpty && context.trim().isNotEmpty;

  StoryCreationState copyWith({
    String? title,
    String? description,
    String? context,
    List<String>? themes,
    List<String>? characters,
    String? tone,
    int? targetLength,
    List<String>? tags,
    String? interactionMode,
    String? aiRole,
    String? interactiveTemplate,
    int? maxPlayers,
    bool? timerEnabled,
    bool? scoringEnabled,
    String? interactionRules,
    Object? selectedRiveElement = _unset,
    Object? coverImage = _unset,
    bool? isSubmitting,
    Object? error = _unset,
    Object? createdStory = _unset,
  }) {
    return StoryCreationState(
      title: title ?? this.title,
      description: description ?? this.description,
      context: context ?? this.context,
      themes: themes ?? this.themes,
      characters: characters ?? this.characters,
      tone: tone ?? this.tone,
      targetLength: targetLength ?? this.targetLength,
      tags: tags ?? this.tags,
      interactionMode: interactionMode ?? this.interactionMode,
      aiRole: aiRole ?? this.aiRole,
      interactiveTemplate: interactiveTemplate ?? this.interactiveTemplate,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      scoringEnabled: scoringEnabled ?? this.scoringEnabled,
      interactionRules: interactionRules ?? this.interactionRules,
      selectedRiveElement: selectedRiveElement == _unset
          ? this.selectedRiveElement
          : selectedRiveElement as RiveElementDto?,
      coverImage: coverImage == _unset ? this.coverImage : coverImage as File?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error == _unset ? this.error : error as String?,
      createdStory: createdStory == _unset
          ? this.createdStory
          : createdStory as CommunityStoryDto?,
    );
  }

  static const initial = StoryCreationState();
}

const _unset = Object();

class StoryCreationNotifier extends Notifier<StoryCreationState> {
  @override
  StoryCreationState build() => StoryCreationState.initial;

  void updateTitle(String v) => state = state.copyWith(title: v);
  void updateDescription(String v) => state = state.copyWith(description: v);
  void updateContext(String v) => state = state.copyWith(context: v);
  void updateThemes(List<String> v) => state = state.copyWith(themes: v);
  void updateCharacters(List<String> v) =>
      state = state.copyWith(characters: v);
  void updateTone(String v) => state = state.copyWith(tone: v);
  void updateTargetLength(int v) => state = state.copyWith(targetLength: v);
  void updateTags(List<String> v) => state = state.copyWith(tags: v);
  void updateInteractionMode(String v) =>
      state = state.copyWith(interactionMode: v);
  void updateAiRole(String v) => state = state.copyWith(aiRole: v);
  void updateInteractiveTemplate(String v) =>
      state = state.copyWith(interactiveTemplate: v);
  void updateMaxPlayers(int v) => state = state.copyWith(maxPlayers: v);
  void updateTimerEnabled(bool v) => state = state.copyWith(timerEnabled: v);
  void updateScoringEnabled(bool v) =>
      state = state.copyWith(scoringEnabled: v);
  void updateInteractionRules(String v) =>
      state = state.copyWith(interactionRules: v);

  void selectRiveElement(RiveElementDto? v) =>
      state = state.copyWith(selectedRiveElement: v);

  void setCoverImage(File? v) => state = state.copyWith(coverImage: v);

  void clearError() => state = state.copyWith(error: null);

  Future<void> submit() async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Title and context are required');
      return;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final repo = ref.read(communityStoriesRepositoryProvider);
      final created = await repo.createStory(
        CommunityStoryCreateDto(
          title: state.title.trim(),
          description: state.description.trim().isEmpty
              ? null
              : state.description.trim(),
          context: state.context.trim(),
          themes: state.themes,
          characters: state.characters,
          tone: state.tone,
          targetLength: state.targetLength,
          tags: state.tags,
          interactionMode: state.interactionMode,
          aiRole: state.aiRole,
          interactiveConfig: _buildInteractiveConfig(state),
          riveElementId: state.selectedRiveElement?.id,
        ),
      );

      // Upload cover image if selected
      if (state.coverImage != null) {
        await repo.uploadCoverImage(created.id, state.coverImage!);
      }

      state = state.copyWith(isSubmitting: false, createdStory: created);

      // Invalidate my stories list so it refreshes
      ref.invalidate(myStoriesProvider);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  void reset() => state = StoryCreationState.initial;

  Map<String, dynamic> _buildInteractiveConfig(StoryCreationState state) {
    if (state.interactionMode == 'narrative') {
      return const <String, dynamic>{};
    }
    return {
      'template': state.interactiveTemplate,
      'max_players': state.interactionMode == 'group' ? state.maxPlayers : 1,
      'timer_enabled': state.timerEnabled,
      'scoring_enabled': state.scoringEnabled,
      if (state.timerEnabled) 'time_limit_ms': 30000,
      if (state.interactionRules.trim().isNotEmpty)
        'rules': state.interactionRules.trim(),
    };
  }
}

final storyCreationProvider =
    NotifierProvider<StoryCreationNotifier, StoryCreationState>(
      StoryCreationNotifier.new,
    );
