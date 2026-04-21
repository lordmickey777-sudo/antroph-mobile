class UserPersonalization {
  const UserPersonalization({
    required this.id,
    required this.userId,
    required this.vibe,
    required this.quizVersion,
    required this.isCompleted,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String vibe;
  final int quizVersion;
  final bool isCompleted;
  final DateTime? completedAt;

  factory UserPersonalization.fromJson(Map<String, dynamic> json) {
    return UserPersonalization(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      vibe: (json['vibe'] ?? '').toString(),
      quizVersion: (json['quiz_version'] as num?)?.toInt() ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: _parseDateTime(json['completed_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
