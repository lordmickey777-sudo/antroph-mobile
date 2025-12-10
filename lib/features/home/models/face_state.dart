class FaceState {
  const FaceState({
    required this.eyeWidth,
    required this.eyeHeight,
    required this.eyeCornerRadius,
    required this.eyeAngle,
    required this.mouthType,
    required this.mouthWidth,
    required this.mouthHeight,
  });

  /// Default neutral DNA used by the backend.
  static const List<int> neutralDna = [35, 35, 10, 0, 0, 40, 0];

  final double eyeWidth;
  final double eyeHeight;
  final double eyeCornerRadius;
  final int eyeAngle; // 0 = Normal, 1 = Angry
  final int mouthType; // 0 = Arc, 1 = Open
  final double mouthWidth;
  final double mouthHeight;

  factory FaceState.fromArray(List<dynamic> dna) {
    if (dna.length < 7) return FaceState.neutral();
    return FaceState(
      eyeWidth: (dna[0] as num).toDouble(),
      eyeHeight: (dna[1] as num).toDouble(),
      eyeCornerRadius: (dna[2] as num).toDouble(),
      eyeAngle: (dna[3] as num).toInt(),
      mouthType: (dna[4] as num).toInt(),
      mouthWidth: (dna[5] as num).toDouble(),
      mouthHeight: (dna[6] as num).toDouble(),
    );
  }

  static FaceState? maybeFromDynamic(dynamic dna) {
    final parsed = _coerceDna(dna);
    if (parsed == null || parsed.length < 7) return null;
    return FaceState.fromArray(parsed);
  }

  static FaceState neutral() => FaceState.fromArray(neutralDna);

  static FaceState lerp(FaceState a, FaceState b, double t) {
    return FaceState(
      eyeWidth: _lerpDouble(a.eyeWidth, b.eyeWidth, t),
      eyeHeight: _lerpDouble(a.eyeHeight, b.eyeHeight, t),
      eyeCornerRadius: _lerpDouble(a.eyeCornerRadius, b.eyeCornerRadius, t),
      eyeAngle: t < 0.5 ? a.eyeAngle : b.eyeAngle, // Snap integer
      mouthType: t < 0.5 ? a.mouthType : b.mouthType, // Snap integer
      mouthWidth: _lerpDouble(a.mouthWidth, b.mouthWidth, t),
      mouthHeight: _lerpDouble(a.mouthHeight, b.mouthHeight, t),
    );
  }

  List<int> toArray() => [
    eyeWidth.round(),
    eyeHeight.round(),
    eyeCornerRadius.round(),
    eyeAngle,
    mouthType,
    mouthWidth.round(),
    mouthHeight.round(),
  ];

  static List<int>? _coerceDna(dynamic dna) {
    if (dna is FaceState) {
      return dna.toArray();
    }
    if (dna is List) {
      final values = dna.whereType<num>().map((e) => e.toInt()).toList();
      if (values.length >= 7) return values.take(7).toList();
      return null;
    }
    if (dna is Map) {
      final map = dna as Map<Object?, Object?>;
      final candidate =
          map['dna'] ?? map['face'] ?? map['state'] ?? map['values'];
      final coerced = _coerceDna(candidate);
      if (coerced != null) return coerced;
      final values = map.values.whereType<num>().map((e) => e.toInt()).toList();
      if (values.length >= 7) return values.take(7).toList();
    }
    return null;
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
