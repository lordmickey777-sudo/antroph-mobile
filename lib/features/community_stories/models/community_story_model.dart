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
          ? RiveElementDto.fromJson(json['rive_element'] as Map<String, dynamic>)
          : null,
      createdAt:
          _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt:
          _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'moderation_status': moderationStatus,
        'is_published': isPublished,
        'story_type': storyType,
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
    if (riveElementId != null) map['rive_element_id'] = riveElementId;
    return map;
  }
}
