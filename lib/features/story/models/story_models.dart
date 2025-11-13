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
    required this.title,
    required this.subtitle,
    required this.image,
    required this.users,
    required this.views,
  });
  final String title;
  final String subtitle;

  /// Can be an asset path or a remote URL.
  final String image;
  final int users;
  final int views;

  factory StoryCardDto.fromJson(Map<String, dynamic> json) => StoryCardDto(
    title: (json['title'] as String?)?.trim() ?? '',
    subtitle: (json['subtitle'] as String?)?.trim() ?? '',
    image: (json['image'] as String?)?.trim() ?? '',
    users: (json['users'] as num?)?.toInt() ?? 0,
    views: (json['views'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'image': image,
    'users': users,
    'views': views,
  };
}

class StoriesHomeResponse {
  StoriesHomeResponse({required this.sections});
  final List<StorySectionDto> sections;

  factory StoriesHomeResponse.fromJson(Map<String, dynamic> json) => StoriesHomeResponse(
    sections: ((json['sections'] as List?) ?? const [])
        .map((e) => StorySectionDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {'sections': sections.map((e) => e.toJson()).toList()};
}
