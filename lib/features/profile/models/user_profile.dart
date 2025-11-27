class UserProfile {
  final String id;
  final String email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final DateTime? dateOfBirth;
  final String? timezone;
  final String? language;
  final bool isCompleted;

  const UserProfile({
    required this.id,
    required this.email,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.dateOfBirth,
    this.timezone,
    this.language,
    this.isCompleted = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      timezone: json['timezone'] as String?,
      language: json['language'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class UsernameAvailability {
  final String username;
  final bool available;
  const UsernameAvailability({required this.username, required this.available});

  factory UsernameAvailability.fromJson(Map<String, dynamic> json) => UsernameAvailability(
    username: (json['username'] ?? '').toString(),
    available: json['available'] as bool? ?? false,
  );
}
