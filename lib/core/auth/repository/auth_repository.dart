import 'package:dio/dio.dart';
import '../../network/api_client.dart';
import '../models/user.dart';

class AuthRepository {
  final Dio _dio = ApiClient.I.dio;

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
}
