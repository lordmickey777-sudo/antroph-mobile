import 'mascot_model.dart';
import '../../community_stories/models/rive_element_model.dart';

class StoryDetailDto {
  StoryDetailDto({
    required this.id,
    required this.categoryId,
    this.riveElementId,
    required this.title,
    required this.description,
    required this.author,
    required this.ageRating,
    required this.tags,
    required this.durationMinutes,
    required this.difficulty,
    this.context = '',
    required this.isPremium,
    required this.price,
    required this.isPublished,
    required this.publishedAt,
    required this.createdByAdminId,
    required this.createdAt,
    required this.updatedAt,
    required this.tree,
    required this.previewNodeIds,
    this.interactionMode = 'narrative',
    this.aiRole = 'narrator',
    this.interactiveConfig = const <String, dynamic>{},
    this.riveElement,
    this.resolvedMascotConfig,
  });

  final String id;
  final String categoryId;
  final String? riveElementId;
  final RiveElementDto? riveElement;
  final String title;
  final String description;
  final String author;
  final int ageRating;
  final List<String> tags;
  final int durationMinutes;
  final String difficulty;
  final String context;
  final bool isPremium;
  final num price;
  final bool isPublished;
  final DateTime? publishedAt;
  final String createdByAdminId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> tree;
  final List<String> previewNodeIds;
  final String interactionMode;
  final String aiRole;
  final Map<String, dynamic> interactiveConfig;
  final MascotConfig? resolvedMascotConfig;

  factory StoryDetailDto.fromJson(Map<String, dynamic> json) => StoryDetailDto(
    id: (json['id'] as String?)?.trim() ?? '',
    categoryId: (json['category_id'] as String?)?.trim() ?? '',
    riveElementId: (json['rive_element_id'] as String?)?.trim(),
    riveElement: _parseRiveElement(json['rive_element']),
    title: (json['title'] as String?)?.trim() ?? '',
    description: (json['description'] as String?)?.trim() ?? '',
    author: (json['author'] as String?)?.trim() ?? '',
    ageRating: (json['age_rating'] as num?)?.toInt() ?? 0,
    tags: ((json['tags'] as List?) ?? const []).whereType<String>().toList(),
    durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
    difficulty: (json['difficulty'] as String?)?.trim() ?? '',
    context: (json['context'] as String?)?.trim() ?? '',
    isPremium: (json['is_premium'] as bool?) ?? false,
    price: (json['price'] as num?) ?? 0,
    isPublished: (json['is_published'] as bool?) ?? false,
    publishedAt: _parseDate(json['published_at']),
    createdByAdminId: (json['created_by_admin_id'] as String?)?.trim() ?? '',
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
    tree:
        (json['tree'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    previewNodeIds: ((json['preview_node_ids'] as List?) ?? const [])
        .whereType<String>()
        .toList(),
    interactionMode:
        (json['interaction_mode'] as String?)?.trim() ?? 'narrative',
    aiRole: (json['ai_role'] as String?)?.trim() ?? 'narrator',
    interactiveConfig:
        (json['interactive_config'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{},
  );

  static RiveElementDto? _parseRiveElement(dynamic value) {
    if (value is Map<String, dynamic>) return RiveElementDto.fromJson(value);
    if (value is Map) {
      return RiveElementDto.fromJson(value.cast<String, dynamic>());
    }
    return null;
  }

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
    'category_id': categoryId,
    if (riveElementId != null) 'rive_element_id': riveElementId,
    if (riveElement != null) 'rive_element': riveElement!.toJson(),
    'title': title,
    'description': description,
    'author': author,
    'age_rating': ageRating,
    'tags': tags,
    'duration_minutes': durationMinutes,
    'difficulty': difficulty,
    'context': context,
    'is_premium': isPremium,
    'price': price,
    'is_published': isPublished,
    'published_at': publishedAt?.toIso8601String(),
    'created_by_admin_id': createdByAdminId,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'tree': tree,
    'preview_node_ids': previewNodeIds,
    'interaction_mode': interactionMode,
    'ai_role': aiRole,
    'interactive_config': interactiveConfig,
  };

  StoryDetailDto copyWith({
    String? id,
    String? categoryId,
    Object? riveElementId = _copyUnset,
    Object? riveElement = _copyUnset,
    String? title,
    String? description,
    String? author,
    int? ageRating,
    List<String>? tags,
    int? durationMinutes,
    String? difficulty,
    String? context,
    bool? isPremium,
    num? price,
    bool? isPublished,
    Object? publishedAt = _copyUnset,
    String? createdByAdminId,
    Object? createdAt = _copyUnset,
    Object? updatedAt = _copyUnset,
    Map<String, dynamic>? tree,
    List<String>? previewNodeIds,
    String? interactionMode,
    String? aiRole,
    Map<String, dynamic>? interactiveConfig,
    Object? resolvedMascotConfig = _copyUnset,
  }) {
    return StoryDetailDto(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      riveElementId: riveElementId == _copyUnset
          ? this.riveElementId
          : riveElementId as String?,
      riveElement: riveElement == _copyUnset
          ? this.riveElement
          : riveElement as RiveElementDto?,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      ageRating: ageRating ?? this.ageRating,
      tags: tags ?? this.tags,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      difficulty: difficulty ?? this.difficulty,
      context: context ?? this.context,
      isPremium: isPremium ?? this.isPremium,
      price: price ?? this.price,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt == _copyUnset
          ? this.publishedAt
          : publishedAt as DateTime?,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      createdAt: createdAt == _copyUnset
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _copyUnset
          ? this.updatedAt
          : updatedAt as DateTime?,
      tree: tree ?? this.tree,
      previewNodeIds: previewNodeIds ?? this.previewNodeIds,
      interactionMode: interactionMode ?? this.interactionMode,
      aiRole: aiRole ?? this.aiRole,
      interactiveConfig: interactiveConfig ?? this.interactiveConfig,
      resolvedMascotConfig: resolvedMascotConfig == _copyUnset
          ? this.resolvedMascotConfig
          : resolvedMascotConfig as MascotConfig?,
    );
  }

  MascotConfig get effectiveMascot =>
      resolvedMascotConfig ??
      riveElement?.toMascotConfig() ??
      MascotConfig.defaultAnthroph();
}

const _copyUnset = Object();
