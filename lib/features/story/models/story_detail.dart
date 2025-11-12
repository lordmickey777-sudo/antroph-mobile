class StoryDetailDto {
  StoryDetailDto({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.author,
    required this.ageRating,
    required this.tags,
    required this.durationMinutes,
    required this.difficulty,
    required this.isPremium,
    required this.price,
    required this.isPublished,
    required this.publishedAt,
    required this.createdByAdminId,
    required this.createdAt,
    required this.updatedAt,
    required this.tree,
    required this.previewNodeIds,
  });

  final String id;
  final String categoryId;
  final String title;
  final String description;
  final String author;
  final int ageRating;
  final List<String> tags;
  final int durationMinutes;
  final String difficulty;
  final bool isPremium;
  final num price;
  final bool isPublished;
  final DateTime? publishedAt;
  final String createdByAdminId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> tree;
  final List<String> previewNodeIds;

  factory StoryDetailDto.fromJson(Map<String, dynamic> json) => StoryDetailDto(
    id: (json['id'] as String?)?.trim() ?? '',
    categoryId: (json['category_id'] as String?)?.trim() ?? '',
    title: (json['title'] as String?)?.trim() ?? '',
    description: (json['description'] as String?)?.trim() ?? '',
    author: (json['author'] as String?)?.trim() ?? '',
    ageRating: (json['age_rating'] as num?)?.toInt() ?? 0,
    tags: ((json['tags'] as List?) ?? const []).whereType<String>().toList(),
    durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
    difficulty: (json['difficulty'] as String?)?.trim() ?? '',
    isPremium: (json['is_premium'] as bool?) ?? false,
    price: (json['price'] as num?) ?? 0,
    isPublished: (json['is_published'] as bool?) ?? false,
    publishedAt: _parseDate(json['published_at']),
    createdByAdminId: (json['created_by_admin_id'] as String?)?.trim() ?? '',
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
    tree: (json['tree'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    previewNodeIds: ((json['preview_node_ids'] as List?) ?? const []).whereType<String>().toList(),
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
    'category_id': categoryId,
    'title': title,
    'description': description,
    'author': author,
    'age_rating': ageRating,
    'tags': tags,
    'duration_minutes': durationMinutes,
    'difficulty': difficulty,
    'is_premium': isPremium,
    'price': price,
    'is_published': isPublished,
    'published_at': publishedAt?.toIso8601String(),
    'created_by_admin_id': createdByAdminId,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'tree': tree,
    'preview_node_ids': previewNodeIds,
  };
}
