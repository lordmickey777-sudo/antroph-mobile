import 'mascot_model.dart';
import '../../community_stories/models/rive_element_model.dart';

class PlaylistDto {
  PlaylistDto({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.storyIds,
    required this.storyCount,
    required this.isPublic,
    required this.coverImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.riveElementId,
    this.riveElement,
  });

  final String id;
  final String userId;
  final String name;
  final String description;
  final String coverImageUrl;
  final List<String> storyIds;
  final int storyCount;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? riveElementId;
  final RiveElementDto? riveElement;

  MascotConfig? get mascot => riveElement?.toMascotConfig();

  factory PlaylistDto.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse((json['created_at'] as String?) ?? '');
    final updatedAt = DateTime.tryParse((json['updated_at'] as String?) ?? '');
    final storyIds = ((json['story_ids'] as List?) ?? const [])
        .map((e) => (e as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final computedStoryCount =
        (json['story_count'] as num?)?.toInt() ??
        (json['stories_count'] as num?)?.toInt() ??
        storyIds.length;
    final name =
        (json['name'] as String?)?.trim() ??
        (json['title'] as String?)?.trim() ??
        '';
    final description =
        (json['description'] as String?)?.trim() ??
        (json['subtitle'] as String?)?.trim() ??
        '';
    final coverImage =
        (json['cover_image_url'] as String?) ??
        (json['image_url'] as String?) ??
        (json['image'] as String?) ??
        (json['thumbnail_url'] as String?) ??
        '';
    return PlaylistDto(
      id: (json['id'] as String?)?.trim() ?? '',
      userId: (json['user_id'] as String?)?.trim() ?? '',
      name: name,
      description: description,
      coverImageUrl: coverImage.trim(),
      storyIds: storyIds,
      storyCount: computedStoryCount > 0
          ? computedStoryCount
          : (name.isNotEmpty ? 1 : 0),
      isPublic: (json['is_public'] as bool?) ?? false,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      riveElementId: (json['rive_element_id'] as String?)?.trim(),
      riveElement: _parseRiveElement(json['rive_element']),
    );
  }
}

class PlaylistDetailDto {
  PlaylistDetailDto({required this.stories});

  final List<PlaylistStoryDto> stories;

  factory PlaylistDetailDto.fromJson(Map<String, dynamic> json) =>
      PlaylistDetailDto(
        stories: ((json['stories'] as List?) ?? const [])
            .map((e) => PlaylistStoryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PlaylistStoryDto {
  PlaylistStoryDto({
    required this.id,
    required this.storyId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.users,
    required this.views,
    this.riveElementId,
    this.riveElement,
  });

  final String id;
  final String storyId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int users;
  final int views;
  final String? riveElementId;
  final RiveElementDto? riveElement;

  MascotConfig? get mascot => riveElement?.toMascotConfig();

  factory PlaylistStoryDto.fromJson(Map<String, dynamic> json) {
    final rawImage =
        (json['cover_image_url'] as String?) ??
        (json['image_url'] as String?) ??
        (json['image'] as String?) ??
        (json['thumbnail_url'] as String?) ??
        '';
    return PlaylistStoryDto(
      id: (json['id'] as String?)?.trim() ?? '',
      storyId:
          (json['story_id'] as String?)?.trim() ??
          (json['id'] as String?)?.trim() ??
          '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
      imageUrl: rawImage.trim(),
      users: (json['users'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,
      riveElementId: (json['rive_element_id'] as String?)?.trim(),
      riveElement: _parseRiveElement(json['rive_element']),
    );
  }
}

RiveElementDto? _parseRiveElement(dynamic value) {
  if (value is Map<String, dynamic>) return RiveElementDto.fromJson(value);
  if (value is Map) return RiveElementDto.fromJson(value.cast<String, dynamic>());
  return null;
}
