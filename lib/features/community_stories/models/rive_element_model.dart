import '../../story/models/mascot_model.dart';

class RiveElementDto {
  const RiveElementDto({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.riveAssetFileId,
    this.thumbnailFileId,
    this.riveAssetUrl,
    this.thumbnailUrl,
    this.storageProvider,
    this.contentHash,
    this.stateMachine = 'FaceSm',
    this.artboard,
    this.fallbackAsset,
    this.expressionConfig = const {},
    this.tags = const [],
    this.isActive = true,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String category;
  final String? riveAssetFileId;
  final String? thumbnailFileId;
  final String? riveAssetUrl;
  final String? thumbnailUrl;
  final String? storageProvider;
  final String? contentHash;
  final String stateMachine;
  final String? artboard;
  final String? fallbackAsset;
  final Map<String, dynamic> expressionConfig;
  final List<String> tags;
  final bool isActive;
  final int displayOrder;

  String get effectiveThumbnail =>
      (thumbnailUrl ?? thumbnailFileId ?? '').trim();

  String get effectiveRiveAsset =>
      (riveAssetUrl ?? riveAssetFileId ?? '').trim();

  factory RiveElementDto.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is String && t.trim().isNotEmpty) tags.add(t.trim());
      }
    }

    final rawConfig = json['expression_config'];
    final expressionConfig = <String, dynamic>{};
    if (rawConfig is Map) {
      for (final entry in rawConfig.entries) {
        expressionConfig[entry.key.toString()] = entry.value;
      }
    }

    return RiveElementDto(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim(),
      category: (json['category'] as String?)?.trim() ?? 'character',
      riveAssetFileId: (json['rive_asset_file_id'] as String?)?.trim(),
      thumbnailFileId: (json['thumbnail_file_id'] as String?)?.trim(),
      riveAssetUrl: (json['rive_asset_url'] as String?)?.trim(),
      thumbnailUrl: (json['thumbnail_url'] as String?)?.trim(),
      storageProvider: (json['storage_provider'] as String?)?.trim(),
      contentHash: (json['content_hash'] as String?)?.trim(),
      stateMachine: (json['state_machine'] as String?)?.trim() ?? 'FaceSm',
      artboard: (json['artboard'] as String?)?.trim(),
      fallbackAsset: (json['fallback_asset'] as String?)?.trim(),
      expressionConfig: expressionConfig,
      tags: tags,
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'category': category,
    if (riveAssetFileId != null) 'rive_asset_file_id': riveAssetFileId,
    if (thumbnailFileId != null) 'thumbnail_file_id': thumbnailFileId,
    if (riveAssetUrl != null) 'rive_asset_url': riveAssetUrl,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    if (contentHash != null) 'content_hash': contentHash,
    'state_machine': stateMachine,
    if (artboard != null) 'artboard': artboard,
    if (fallbackAsset != null) 'fallback_asset': fallbackAsset,
    'expression_config': expressionConfig,
    'tags': tags,
    'is_active': isActive,
    'display_order': displayOrder,
  };

  /// Converts to MascotConfig for ChatPage voice preview compatibility.
  RiveElementDto copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    Object? riveAssetFileId = _copyUnset,
    Object? thumbnailFileId = _copyUnset,
    Object? riveAssetUrl = _copyUnset,
    Object? thumbnailUrl = _copyUnset,
    Object? storageProvider = _copyUnset,
    Object? contentHash = _copyUnset,
    String? stateMachine,
    Object? artboard = _copyUnset,
    Object? fallbackAsset = _copyUnset,
    Map<String, dynamic>? expressionConfig,
    List<String>? tags,
    bool? isActive,
    int? displayOrder,
  }) {
    return RiveElementDto(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      riveAssetFileId: riveAssetFileId == _copyUnset
          ? this.riveAssetFileId
          : riveAssetFileId as String?,
      thumbnailFileId: thumbnailFileId == _copyUnset
          ? this.thumbnailFileId
          : thumbnailFileId as String?,
      riveAssetUrl: riveAssetUrl == _copyUnset
          ? this.riveAssetUrl
          : riveAssetUrl as String?,
      thumbnailUrl: thumbnailUrl == _copyUnset
          ? this.thumbnailUrl
          : thumbnailUrl as String?,
      storageProvider: storageProvider == _copyUnset
          ? this.storageProvider
          : storageProvider as String?,
      contentHash: contentHash == _copyUnset
          ? this.contentHash
          : contentHash as String?,
      stateMachine: stateMachine ?? this.stateMachine,
      artboard: artboard == _copyUnset ? this.artboard : artboard as String?,
      fallbackAsset: fallbackAsset == _copyUnset
          ? this.fallbackAsset
          : fallbackAsset as String?,
      expressionConfig: expressionConfig ?? this.expressionConfig,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  MascotConfig toMascotConfig({String? localAssetPath}) {
    final expressions = <String, ExpressionParams>{};
    for (final entry in expressionConfig.entries) {
      if (entry.value is Map) {
        expressions[entry.key] = ExpressionParams.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
    }

    return MascotConfig(
      id: id,
      name: name,
      riveAssetUrl: effectiveRiveAsset,
      stateMachine: stateMachine,
      artboard: artboard,
      fallbackAsset: fallbackAsset,
      expressions: expressions,
      localAssetPath: localAssetPath,
    );
  }
}

const _copyUnset = Object();
