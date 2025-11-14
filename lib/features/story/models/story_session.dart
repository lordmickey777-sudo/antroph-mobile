/// Request model for starting a story session
class StartSessionRequest {
  StartSessionRequest({required this.deviceType, required this.deviceId});

  final String deviceType;
  final String deviceId;

  Map<String, dynamic> toJson() => {'device_type': deviceType, 'device_id': deviceId};
}

/// Milestone data earned when reaching story milestones
class MilestoneData {
  MilestoneData({required this.name, required this.badgeId, required this.points});

  final String name;
  final String badgeId;
  final int points;

  factory MilestoneData.fromJson(Map<String, dynamic> json) => MilestoneData(
    name: (json['name'] as String?)?.trim() ?? '',
    badgeId: (json['badge_id'] as String?)?.trim() ?? '',
    points: (json['points'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {'name': name, 'badge_id': badgeId, 'points': points};
}

/// Choice available at a story node
class StoryChoice {
  StoryChoice({
    required this.index,
    required this.text,
    this.audioPrompt,
    required this.nextNode,
    required this.type,
    this.randomWeights,
    this.voiceTriggers,
  });

  final int index;
  final String text;
  final String? audioPrompt;
  final String nextNode;
  final String type; // 'deterministic', 'random', etc.
  final Map<String, num>? randomWeights;
  final List<String>? voiceTriggers;

  factory StoryChoice.fromJson(Map<String, dynamic> json) => StoryChoice(
    index: (json['index'] as num?)?.toInt() ?? 0,
    text: (json['text'] as String?)?.trim() ?? '',
    audioPrompt: (json['audio_prompt'] as String?)?.trim(),
    nextNode: (json['next_node'] as String?)?.trim() ?? '',
    type: (json['type'] as String?)?.trim() ?? 'deterministic',
    randomWeights: (json['random_weights'] as Map?)?.cast<String, num>(),
    voiceTriggers: ((json['voice_triggers'] as List?) ?? const []).whereType<String>().toList(),
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    if (audioPrompt != null) 'audio_prompt': audioPrompt,
    'next_node': nextNode,
    'type': type,
    if (randomWeights != null) 'random_weights': randomWeights,
    if (voiceTriggers != null) 'voice_triggers': voiceTriggers,
  };
}

/// Content for a story node (text, media)
class StoryNodeContent {
  StoryNodeContent({required this.text, this.audioUrl, this.imageUrl, this.videoUrl});

  final String text;
  final String? audioUrl;
  final String? imageUrl;
  final String? videoUrl;

  factory StoryNodeContent.fromJson(Map<String, dynamic> json) => StoryNodeContent(
    text: (json['text'] as String?)?.trim() ?? '',
    audioUrl: (json['audio_url'] as String?)?.trim(),
    imageUrl: (json['image_url'] as String?)?.trim(),
    videoUrl: (json['video_url'] as String?)?.trim(),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    if (audioUrl != null) 'audio_url': audioUrl,
    if (imageUrl != null) 'image_url': imageUrl,
    if (videoUrl != null) 'video_url': videoUrl,
  };
}

/// A node in the story tree
class StoryNode {
  StoryNode({
    required this.id,
    required this.content,
    required this.isMilestone,
    this.milestoneData,
    required this.isEnding,
    this.endingType,
    required this.choices,
  });

  final String id;
  final StoryNodeContent content;
  final bool isMilestone;
  final MilestoneData? milestoneData;
  final bool isEnding;
  final String? endingType;
  final List<StoryChoice> choices;

  factory StoryNode.fromJson(Map<String, dynamic> json) => StoryNode(
    id: (json['id'] as String?)?.trim() ?? '',
    content: StoryNodeContent.fromJson(
      (json['content'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    ),
    isMilestone: (json['is_milestone'] as bool?) ?? false,
    milestoneData: json['milestone_data'] != null
        ? MilestoneData.fromJson((json['milestone_data'] as Map).cast<String, dynamic>())
        : null,
    isEnding: (json['is_ending'] as bool?) ?? false,
    endingType: (json['ending_type'] as String?)?.trim(),
    choices: ((json['choices'] as List?) ?? const [])
        .map((e) => StoryChoice.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content.toJson(),
    'is_milestone': isMilestone,
    if (milestoneData != null) 'milestone_data': milestoneData!.toJson(),
    'is_ending': isEnding,
    if (endingType != null) 'ending_type': endingType,
    'choices': choices.map((e) => e.toJson()).toList(),
  };
}

/// Story session state
class StorySession {
  StorySession({
    required this.id,
    required this.storyId,
    required this.currentNodeId,
    this.currentNode,
    required this.pathHistory,
    required this.milestonesReached,
    required this.isPaused,
    required this.isCompleted,
    required this.lastActivityAt,
    required this.version,
  });

  final String id;
  final String storyId;
  final String currentNodeId;
  final StoryNode? currentNode;
  final List<String> pathHistory;
  final List<String> milestonesReached;
  final bool isPaused;
  final bool isCompleted;
  final DateTime lastActivityAt;
  final int version;

  factory StorySession.fromJson(Map<String, dynamic> json) => StorySession(
    id: (json['id'] as String?)?.trim() ?? '',
    storyId: (json['story_id'] as String?)?.trim() ?? '',
    currentNodeId: (json['current_node_id'] as String?)?.trim() ?? '',
    currentNode: json['current_node'] != null
        ? StoryNode.fromJson((json['current_node'] as Map).cast<String, dynamic>())
        : null,
    pathHistory: ((json['path_history'] as List?) ?? const []).whereType<String>().toList(),
    milestonesReached: ((json['milestones_reached'] as List?) ?? const [])
        .whereType<String>()
        .toList(),
    isPaused: (json['is_paused'] as bool?) ?? false,
    isCompleted: (json['is_completed'] as bool?) ?? false,
    lastActivityAt: _parseDate(json['last_activity_at']) ?? DateTime.now(),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v).toUtc();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'story_id': storyId,
    'current_node_id': currentNodeId,
    if (currentNode != null) 'current_node': currentNode!.toJson(),
    'path_history': pathHistory,
    'milestones_reached': milestonesReached,
    'is_paused': isPaused,
    'is_completed': isCompleted,
    'last_activity_at': lastActivityAt.toIso8601String(),
    'version': version,
  };

  /// Create a copy with updated fields
  StorySession copyWith({
    String? id,
    String? storyId,
    String? currentNodeId,
    StoryNode? currentNode,
    List<String>? pathHistory,
    List<String>? milestonesReached,
    bool? isPaused,
    bool? isCompleted,
    DateTime? lastActivityAt,
    int? version,
  }) {
    return StorySession(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      currentNodeId: currentNodeId ?? this.currentNodeId,
      currentNode: currentNode ?? this.currentNode,
      pathHistory: pathHistory ?? this.pathHistory,
      milestonesReached: milestonesReached ?? this.milestonesReached,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      version: version ?? this.version,
    );
  }
}
