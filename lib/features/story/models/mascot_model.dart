class ExpressionParams {
  const ExpressionParams({
    this.eyeExpression,
    this.mouthOpen,
    this.headTilt,
    this.eyeOpen,
    this.headBob,
    this.blink,
  });

  final int? eyeExpression;
  final double? mouthOpen;
  final double? headTilt;
  final double? eyeOpen;
  final double? headBob;
  final bool? blink;

  factory ExpressionParams.fromJson(Map<String, dynamic> json) {
    return ExpressionParams(
      eyeExpression: (json['eyeExpression'] as num?)?.toInt(),
      mouthOpen: (json['mouthOpen'] as num?)?.toDouble(),
      headTilt: (json['headTilt'] as num?)?.toDouble(),
      eyeOpen: (json['eyeOpen'] as num?)?.toDouble(),
      headBob: (json['headBob'] as num?)?.toDouble(),
      blink: json['blink'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (eyeExpression != null) 'eyeExpression': eyeExpression,
    if (mouthOpen != null) 'mouthOpen': mouthOpen,
    if (headTilt != null) 'headTilt': headTilt,
    if (eyeOpen != null) 'eyeOpen': eyeOpen,
    if (headBob != null) 'headBob': headBob,
    if (blink != null) 'blink': blink,
  };
}

class MascotConfig {
  const MascotConfig({
    required this.id,
    required this.name,
    required this.riveAssetUrl,
    this.stateMachine = defaultStateMachine,
    this.artboard,
    this.fallbackAsset,
    this.expressions = const {},
    this.localAssetPath,
  });

  static const String defaultStateMachine = 'FaceSm';
  static const String defaultFallbackAsset = 'assets/mascots/aura_face.riv';

  final String id;
  final String name;
  final String riveAssetUrl;
  final String stateMachine;
  final String? artboard;
  final String? fallbackAsset;
  final Map<String, ExpressionParams> expressions;
  final String? localAssetPath;

  bool get isRemote =>
      riveAssetUrl.startsWith('http://') || riveAssetUrl.startsWith('https://');
  bool get isCached => (localAssetPath ?? '').trim().isNotEmpty;

  String get effectiveStateMachine {
    final value = stateMachine.trim();
    return value.isEmpty ? defaultStateMachine : value;
  }

  String get effectiveFallbackAsset => normalizeFallbackAsset(fallbackAsset);

  MascotConfig copyWith({
    String? id,
    String? name,
    String? riveAssetUrl,
    String? stateMachine,
    String? artboard,
    Object? fallbackAsset = _copyUnset,
    Map<String, ExpressionParams>? expressions,
    Object? localAssetPath = _copyUnset,
  }) {
    return MascotConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      riveAssetUrl: riveAssetUrl ?? this.riveAssetUrl,
      stateMachine: stateMachine ?? this.stateMachine,
      artboard: artboard ?? this.artboard,
      fallbackAsset: fallbackAsset == _copyUnset
          ? this.fallbackAsset
          : fallbackAsset as String?,
      expressions: expressions ?? this.expressions,
      localAssetPath: localAssetPath == _copyUnset
          ? this.localAssetPath
          : localAssetPath as String?,
    );
  }

  factory MascotConfig.fromJson(Map<String, dynamic> json) {
    final rawExpressions =
        (json['expressions'] as Map?) ?? (json['expression_config'] as Map?);
    final expressions = <String, ExpressionParams>{};
    if (rawExpressions != null) {
      for (final entry in rawExpressions.entries) {
        final key = entry.key?.toString() ?? '';
        if (key.isEmpty) continue;
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          expressions[key] = ExpressionParams.fromJson(value);
        } else if (value is Map) {
          expressions[key] = ExpressionParams.fromJson(
            value.cast<String, dynamic>(),
          );
        }
      }
    }

    return MascotConfig(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      riveAssetUrl: (json['rive_asset_url'] as String?)?.trim() ?? '',
      stateMachine:
          (json['state_machine'] as String?)?.trim() ?? defaultStateMachine,
      artboard: (json['artboard'] as String?)?.trim(),
      fallbackAsset: (json['fallback_asset'] as String?)?.trim(),
      expressions: expressions,
      localAssetPath: (json['local_asset_path'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rive_asset_url': riveAssetUrl,
    'state_machine': stateMachine,
    'artboard': artboard,
    'fallback_asset': fallbackAsset,
    'expressions': expressions.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    if (localAssetPath != null) 'local_asset_path': localAssetPath,
  };

  static MascotConfig defaultAnthroph() {
    return const MascotConfig(
      id: 'anthroph_default',
      name: 'Aura',
      riveAssetUrl: defaultFallbackAsset,
      stateMachine: defaultStateMachine,
      fallbackAsset: defaultFallbackAsset,
    );
  }

  static MascotConfig? maybeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MascotConfig.fromJson(value);
    }
    if (value is Map) {
      return MascotConfig.fromJson(value.cast<String, dynamic>());
    }
    return null;
  }

  static String normalizeFallbackAsset(String? rawValue) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) return defaultFallbackAsset;
    if (value.startsWith('assets/')) return value;

    switch (value) {
      case 'default_face':
      case 'anthroph_default':
      case 'anthroph_face':
      case 'aura_face':
      case 'aura':
        return defaultFallbackAsset;
      default:
        return defaultFallbackAsset;
    }
  }
}

const _copyUnset = Object();
