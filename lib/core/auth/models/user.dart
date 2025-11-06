class AuthUser {
  final String id;
  final String email;
  final bool emailVerificationRequired;
  final String? displayName;
  final String? username;

  const AuthUser({
    required this.id,
    required this.email,
    required this.emailVerificationRequired,
    this.displayName,
    this.username,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['user_id'] as String? ?? json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    emailVerificationRequired: json['email_verification_required'] as bool? ?? false,
    displayName: json['display_name'] as String?,
    username: json['username'] as String?,
  );
}
