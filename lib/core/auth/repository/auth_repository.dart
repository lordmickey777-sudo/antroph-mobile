import 'package:dio/dio.dart';
import '../../network/api_client.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
    String? username,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
        if (username != null && username.isNotEmpty) 'username': username,
      },
      options: Options(extra: const {'skipAuth': true}),
    );
    return AuthUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<bool> checkEmail(String email) async {
    final res = await _dio.get('/auth/check-email', queryParameters: {'email': email});
    // If API returns the email string when available we treat existing as true.
    final data = res.data;
    return data is String && data.isNotEmpty;
  }

  Future<Map<String, String>> login({required String email, required String password}) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: Options(extra: const {'skipAuth': true}),
    );
    final map = res.data as Map<String, dynamic>;
    return {
      'access_token': map['access_token'] as String? ?? '',
      'refresh_token': map['refresh_token'] as String? ?? '',
      'token_type': map['token_type'] as String? ?? '',
    };
  }

  /// Refresh tokens using the provided refresh token.
  ///
  /// API contract (per backend docs):
  /// POST /auth/refresh
  /// { "refresh_token": "string" }
  /// -> { "access_token": "string", "refresh_token": "string", "token_type": "bearer" }
  Future<Map<String, String>> refreshToken({required String refreshToken}) async {
    final res = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(extra: const {'skipAuth': true}),
    );
    final map = res.data as Map<String, dynamic>;
    return {
      'access_token': map['access_token'] as String? ?? '',
      'refresh_token': map['refresh_token'] as String? ?? '',
      'token_type': map['token_type'] as String? ?? 'bearer',
    };
  }

  /// Calls the logout endpoint to invalidate the refresh token.
  ///
  /// API contract:
  /// POST /auth/logout
  /// { "refresh_token": "string" }
  /// 204 No Content on success, 422 on validation error
  Future<void> logout({required String refreshToken}) async {
    await _dio.post(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
      options: Options(
        extra: const {'skipAuth': true},
        // Some backends return no JSON body; accept 204 without parsing
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300 || status == 204,
      ),
    );
  }

  /// Request a 6-digit reset code to be sent to the user's email.
  ///
  /// API: POST /auth/forgot-password
  /// Body: { "email": "string" }
  /// Response: { "message": "string" }
  /// Always returns 200 with a generic success message to prevent email enumeration.
  Future<String> requestPasswordReset({required String email}) async {
    final res = await _dio.post(
      '/auth/forgot-password',
      data: {'email': email},
      options: Options(extra: const {'skipAuth': true}),
    );
    final data = res.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'If an account exists for this email, a reset code has been sent.';
  }

  /// Reset password using a 6-digit code sent to the user's email.
  ///
  /// API: POST /auth/reset-password
  /// Body: { "email": "string", "token": "string", "new_password": "string" }
  /// Response: { "message": "string" }
  /// Validations (server-side):
  /// - Code must be exactly 6 digits, single-use, not expired
  /// - Password must meet security requirements
  Future<String> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final res = await _dio.post(
      '/auth/reset-password',
      data: {'email': email, 'token': token, 'new_password': newPassword},
      options: Options(extra: const {'skipAuth': true}),
    );
    final data = res.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Password has been reset successfully.';
  }
}
