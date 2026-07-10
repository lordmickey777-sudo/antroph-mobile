import 'rive_element_model.dart';

class CommunityStoryDto {
  const CommunityStoryDto({
    required this.id,
    this.categoryId,
    required this.title,
    this.description,
    this.author,
    this.ageRating = 0,
    this.tags = const [],
    this.durationMinutes = 0,
    this.difficulty = 'medium',
    this.coverImageUrl,
    this.coverImageFileId,
    this.context,
    this.themes = const [],
    this.characters = const [],
    this.tone,
    this.targetLength,
    this.interactionMode = 'narrative',
    this.aiRole = 'narrator',
    this.interactiveConfig = const <String, dynamic>{},
    this.isPremium = false,
    this.isPublished = false,
    this.publishedAt,
    this.storyType = 'community',
    this.createdByUserId,
    this.creatorName,
    this.creatorAvatarUrl,
    required this.moderationStatus,
    this.moderationNote,
    this.moderatedByAdminId,
    this.moderatedAt,
    this.riveElementId,
    this.riveElement,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? categoryId;
  final String title;
  final String? description;
  final String? author;
  final int ageRating;
  final List<String> tags;
  final int durationMinutes;
  final String difficulty;
  final String? coverImageUrl;
  final String? coverImageFileId;
  final String? context;
  final List<String> themes;
  final List<String> characters;
  final String? tone;
  final int? targetLength;
  final String interactionMode;
  final String aiRole;
  final Map<String, dynamic> interactiveConfig;
  final bool isPremium;
  final bool isPublished;
  final DateTime? publishedAt;
  final String storyType;
  final String? createdByUserId;
  final String? creatorName;
  final String? creatorAvatarUrl;
  final String moderationStatus;
  final String? moderationNote;
  final String? moderatedByAdminId;
  final DateTime? moderatedAt;
  final String? riveElementId;
  final RiveElementDto? riveElement;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isApprovedAndPublished =>
      isPublished && moderationStatus.trim().toLowerCase() == 'approved';

  factory CommunityStoryDto.fromJson(Map<String, dynamic> json) {
    return CommunityStoryDto(
      id: (json['id'] as String?)?.trim() ?? '',
      categoryId: (json['category_id'] as String?)?.trim(),
      title: (json['title'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim(),
      author: (json['author'] as String?)?.trim(),
      ageRating: (json['age_rating'] as num?)?.toInt() ?? 0,
      tags: _parseStringList(json['tags']),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      difficulty: (json['difficulty'] as String?)?.trim() ?? 'medium',
      coverImageUrl: (json['cover_image_url'] as String?)?.trim(),
      coverImageFileId: (json['cover_image_file_id'] as String?)?.trim(),
      context: (json['context'] as String?)?.trim(),
      themes: _parseStringList(json['themes']),
      characters: _parseStringList(json['characters']),
      tone: (json['tone'] as String?)?.trim(),
      targetLength: (json['target_length'] as num?)?.toInt(),
      interactionMode:
          (json['interaction_mode'] as String?)?.trim() ?? 'narrative',
      aiRole: (json['ai_role'] as String?)?.trim() ?? 'narrator',
      interactiveConfig:
          (json['interactive_config'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      isPremium: json['is_premium'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? false,
      publishedAt: _parseDateTime(json['published_at']),
      storyType: (json['story_type'] as String?)?.trim() ?? 'community',
      createdByUserId: (json['created_by_user_id'] as String?)?.trim(),
      creatorName: (json['creator_name'] as String?)?.trim(),
      creatorAvatarUrl: (json['creator_avatar_url'] as String?)?.trim(),
      moderationStatus:
          (json['moderation_status'] as String?)?.trim() ?? 'pending',
      moderationNote: (json['moderation_note'] as String?)?.trim(),
      moderatedByAdminId: (json['moderated_by_admin_id'] as String?)?.trim(),
      moderatedAt: _parseDateTime(json['moderated_at']),
      riveElementId: (json['rive_element_id'] as String?)?.trim(),
      riveElement: json['rive_element'] is Map<String, dynamic>
          ? RiveElementDto.fromJson(
              json['rive_element'] as Map<String, dynamic>,
            )
          : null,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (categoryId != null) 'category_id': categoryId,
    'title': title,
    if (description != null) 'description': description,
    if (author != null) 'author': author,
    'age_rating': ageRating,
    'tags': tags,
    'duration_minutes': durationMinutes,
    'difficulty': difficulty,
    if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
    if (coverImageFileId != null) 'cover_image_file_id': coverImageFileId,
    if (context != null) 'context': context,
    'themes': themes,
    'characters': characters,
    if (tone != null) 'tone': tone,
    if (targetLength != null) 'target_length': targetLength,
    'interaction_mode': interactionMode,
    'ai_role': aiRole,
    'interactive_config': interactiveConfig,
    'is_premium': isPremium,
    'is_published': isPublished,
    if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
    'story_type': storyType,
    if (createdByUserId != null) 'created_by_user_id': createdByUserId,
    if (creatorName != null) 'creator_name': creatorName,
    if (creatorAvatarUrl != null) 'creator_avatar_url': creatorAvatarUrl,
    'moderation_status': moderationStatus,
    if (moderationNote != null) 'moderation_note': moderationNote,
    if (moderatedByAdminId != null) 'moderated_by_admin_id': moderatedByAdminId,
    if (moderatedAt != null) 'moderated_at': moderatedAt!.toIso8601String(),
    if (riveElementId != null) 'rive_element_id': riveElementId,
    if (riveElement != null) 'rive_element': riveElement!.toJson(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}

class CommunityStoryCreateDto {
  const CommunityStoryCreateDto({
    required this.title,
    this.description,
    required this.context,
    this.themes = const [],
    this.characters = const [],
    this.tone = 'neutral',
    this.targetLength = 10,
    this.tags = const [],
    this.interactionMode = 'narrative',
    this.aiRole = 'narrator',
    this.interactiveConfig = const <String, dynamic>{},
    this.riveElementId,
  });

  final String title;
  final String? description;
  final String context;
  final List<String> themes;
  final List<String> characters;
  final String tone;
  final int targetLength;
  final List<String> tags;
  final String interactionMode;
  final String aiRole;
  final Map<String, dynamic> interactiveConfig;
  final String? riveElementId;

  Map<String, dynamic> toJson() => {
    'title': title,
    if (description != null && description!.isNotEmpty)
      'description': description,
    'context': context,
    'themes': themes,
    'characters': characters,
    'tone': tone,
    'target_length': targetLength,
    'tags': tags,
    'interaction_mode': interactionMode,
    'ai_role': aiRole,
    'interactive_config': interactiveConfig,
    if (riveElementId != null) 'rive_element_id': riveElementId,
  };
}

class CommunityStoryUpdateDto {
  const CommunityStoryUpdateDto({
    this.title,
    this.description,
    this.context,
    this.themes,
    this.characters,
    this.tone,
    this.targetLength,
    this.tags,
    this.interactionMode,
    this.aiRole,
    this.interactiveConfig,
    this.riveElementId,
  });

  final String? title;
  final String? description;
  final String? context;
  final List<String>? themes;
  final List<String>? characters;
  final String? tone;
  final int? targetLength;
  final List<String>? tags;
  final String? interactionMode;
  final String? aiRole;
  final Map<String, dynamic>? interactiveConfig;
  final String? riveElementId;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (title != null) map['title'] = title;
    if (description != null) map['description'] = description;
    if (context != null) map['context'] = context;
    if (themes != null) map['themes'] = themes;
    if (characters != null) map['characters'] = characters;
    if (tone != null) map['tone'] = tone;
    if (targetLength != null) map['target_length'] = targetLength;
    if (tags != null) map['tags'] = tags;
    if (interactionMode != null) map['interaction_mode'] = interactionMode;
    if (aiRole != null) map['ai_role'] = aiRole;
    if (interactiveConfig != null) {
      map['interactive_config'] = interactiveConfig;
    }
    if (riveElementId != null) map['rive_element_id'] = riveElementId;
    return map;
  }
}
