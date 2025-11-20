class StoryCollectionDto {
  StoryCollectionDto({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.iconUrl,
    required this.storyIds,
    required this.storyCount,
    required this.categoryId,
    required this.tags,
    required this.isPublished,
    required this.isFeatured,
    required this.displayOrder,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String coverImageUrl;
  final String iconUrl;
  final List<String> storyIds;
  final int storyCount;
  final String categoryId;
  final List<String> tags;
  final bool isPublished;
  final bool isFeatured;
  final int displayOrder;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StoryCollectionDto.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse((json['created_at'] as String?) ?? '');
    final updatedAt = DateTime.tryParse((json['updated_at'] as String?) ?? '');
    return StoryCollectionDto(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      coverImageUrl: (json['cover_image_url'] as String?)?.trim() ?? '',
      iconUrl: (json['icon_url'] as String?)?.trim() ?? '',
      storyIds: ((json['story_ids'] as List?) ?? const [])
          .map((e) => (e as String?)?.trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(),
      storyCount: (json['story_count'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as String?)?.trim() ?? '',
      tags: ((json['tags'] as List?) ?? const [])
          .map((e) => (e as String?)?.trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(),
      isPublished: (json['is_published'] as bool?) ?? false,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdBy: (json['created_by'] as String?)?.trim() ?? '',
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class StoryCollectionDetailDto {
  StoryCollectionDetailDto({required this.stories});

  final List<StoryCollectionStoryDto> stories;

  factory StoryCollectionDetailDto.fromJson(Map<String, dynamic> json) => StoryCollectionDetailDto(
        stories: ((json['stories'] as List?) ?? const [])
            .map((e) => StoryCollectionStoryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StoryCollectionStoryDto {
  StoryCollectionStoryDto({
    required this.id,
    required this.storyId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.users,
    required this.views,
  });

  final String id;
  final String storyId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int users;
  final int views;

  factory StoryCollectionStoryDto.fromJson(Map<String, dynamic> json) {
    final rawImage = (json['cover_image_url'] as String?) ??
        (json['image_url'] as String?) ??
        (json['image'] as String?) ??
        (json['thumbnail_url'] as String?) ??
        '';
    return StoryCollectionStoryDto(
      id: (json['id'] as String?)?.trim() ?? '',
      storyId: (json['story_id'] as String?)?.trim() ?? (json['id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
      imageUrl: rawImage.trim(),
      users: (json['users'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,
    );
  }
}
