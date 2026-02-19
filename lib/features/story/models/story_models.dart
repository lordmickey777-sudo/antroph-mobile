import 'mascot_model.dart';
import '../../community_stories/models/rive_element_model.dart';

class StorySectionDto {
  StorySectionDto({required this.title, required this.items});
  final String title;
  final List<StoryCardDto> items;

  factory StorySectionDto.fromJson(Map<String, dynamic> json) =>
      StorySectionDto(
        title: (json['title'] as String?)?.trim() ?? '',
        items: ((json['items'] as List?) ?? const [])
            .map((e) => StoryCardDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'title': title,
    'items': items.map((e) => e.toJson()).toList(),
  };
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
    this.riveElementId,
    this.riveElement,
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
  final String? riveElementId;
  final RiveElementDto? riveElement;

  MascotConfig? get mascotConfig => riveElement?.toMascotConfig();

  factory StoryCardDto.fromJson(Map<String, dynamic> json) => StoryCardDto(
    id: (json['id'] as String?)?.trim() ?? '',
    storyId:
        (json['story_id'] as String?)?.trim() ??
        (json['id'] as String?)?.trim() ??
        '',
    title: (json['title'] as String?)?.trim() ?? '',
    subtitle: (json['subtitle'] as String?)?.trim() ?? '',
    image: (json['image'] as String?)?.trim() ?? '',
    users: (json['users'] as num?)?.toInt() ?? 0,
    views: (json['views'] as num?)?.toInt() ?? 0,
    isAdded: json['is_added'] as bool? ?? false,
    riveElementId: (json['rive_element_id'] as String?)?.trim(),
    riveElement: _parseRiveElement(json['rive_element']),
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
    if (riveElementId != null) 'rive_element_id': riveElementId,
    if (riveElement != null) 'rive_element': riveElement!.toJson(),
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
    this.riveElementId,
    this.riveElement,
  });

  final String id;
  final String title;
  final String description;
  final String coverImageUrl;
  final String author;
  final bool isAdded;
  final String? riveElementId;
  final RiveElementDto? riveElement;

  MascotConfig? get mascotConfig => riveElement?.toMascotConfig();

  factory FeaturedStoryDto.fromJson(Map<String, dynamic> json) =>
      FeaturedStoryDto(
        id: (json['id'] as String?)?.trim() ?? '',
        title: (json['title'] as String?)?.trim() ?? '',
        description: (json['description'] as String?)?.trim() ?? '',
        coverImageUrl: (json['cover_image_url'] as String?)?.trim() ?? '',
        author: (json['author'] as String?)?.trim() ?? '',
        isAdded: json['is_added'] as bool? ?? false,
        riveElementId: (json['rive_element_id'] as String?)?.trim(),
        riveElement: _parseRiveElement(json['rive_element']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'cover_image_url': coverImageUrl,
    'author': author,
    'is_added': isAdded,
    if (riveElementId != null) 'rive_element_id': riveElementId,
    if (riveElement != null) 'rive_element': riveElement!.toJson(),
  };
}

class StoriesHomeResponse {
  StoriesHomeResponse({
    required this.sections,
    this.featuredStories = const [],
  });
  final List<StorySectionDto> sections;
  final List<FeaturedStoryDto> featuredStories;

  factory StoriesHomeResponse.fromJson(Map<String, dynamic> json) =>
      StoriesHomeResponse(
        sections: ((json['sections'] as List?) ?? const [])
            .map((e) => StorySectionDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        featuredStories: ((json['featured_stories'] as List?) ?? const [])
            .map((e) => FeaturedStoryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'sections': sections.map((e) => e.toJson()).toList(),
    'featured_stories': featuredStories.map((e) => e.toJson()).toList(),
  };
}

RiveElementDto? _parseRiveElement(dynamic value) {
  if (value is Map<String, dynamic>) return RiveElementDto.fromJson(value);
  if (value is Map) return RiveElementDto.fromJson(value.cast<String, dynamic>());
  return null;
}
