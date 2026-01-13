class StorySectionDto {
  StorySectionDto({required this.title, required this.items});
  final String title;
  final List<StoryCardDto> items;

  factory StorySectionDto.fromJson(Map<String, dynamic> json) => StorySectionDto(
    title: (json['title'] as String?)?.trim() ?? '',
    items: ((json['items'] as List?) ?? const [])
        .map((e) => StoryCardDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {'title': title, 'items': items.map((e) => e.toJson()).toList()};
}

class StoryCardDto {
  StoryCardDto({
    required this.id,
    required this.storyId,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.users,
    required this.views,
    required this.isAdded,
  });
  final String id;
  final String storyId;
  final String title;
  final String subtitle;

  /// Can be an asset path or a remote URL.
  final String image;
  final int users;
  final int views;
  final bool isAdded;

  factory StoryCardDto.fromJson(Map<String, dynamic> json) => StoryCardDto(
    id: (json['id'] as String?)?.trim() ?? '',
    storyId: (json['story_id'] as String?)?.trim() ??
        (json['id'] as String?)?.trim() ??
        '',
    title: (json['title'] as String?)?.trim() ?? '',
    subtitle: (json['subtitle'] as String?)?.trim() ?? '',
    image: (json['image'] as String?)?.trim() ?? '',
    users: (json['users'] as num?)?.toInt() ?? 0,
    views: (json['views'] as num?)?.toInt() ?? 0,
    isAdded: json['is_added'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'story_id': storyId,
    'title': title,
    'subtitle': subtitle,
    'image': image,
    'users': users,
    'views': views,
    'is_added': isAdded,
  };
}

class FeaturedStoryDto {
  FeaturedStoryDto({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.author,
    required this.isAdded,
  });

  final String id;
  final String title;
  final String description;
  final String coverImageUrl;
  final String author;
  final bool isAdded;

  factory FeaturedStoryDto.fromJson(Map<String, dynamic> json) => FeaturedStoryDto(
    id: (json['id'] as String?)?.trim() ?? '',
    title: (json['title'] as String?)?.trim() ?? '',
    description: (json['description'] as String?)?.trim() ?? '',
    coverImageUrl: (json['cover_image_url'] as String?)?.trim() ?? '',
    author: (json['author'] as String?)?.trim() ?? '',
    isAdded: json['is_added'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'cover_image_url': coverImageUrl,
    'author': author,
    'is_added': isAdded,
  };
}

class StoriesHomeResponse {
  StoriesHomeResponse({required this.sections, this.featuredStory});
  final List<StorySectionDto> sections;
  final FeaturedStoryDto? featuredStory;

  factory StoriesHomeResponse.fromJson(Map<String, dynamic> json) => StoriesHomeResponse(
    sections: ((json['sections'] as List?) ?? const [])
        .map((e) => StorySectionDto.fromJson(e as Map<String, dynamic>))
        .toList(),
    featuredStory: json['featured_story'] != null
        ? FeaturedStoryDto.fromJson(json['featured_story'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'sections': sections.map((e) => e.toJson()).toList(),
    if (featuredStory != null) 'featured_story': featuredStory!.toJson(),
  };
}
