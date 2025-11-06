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
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    final map = res.data as Map<String, dynamic>;
    return {
      'access_token': map['access_token'] as String? ?? '',
      'refresh_token': map['refresh_token'] as String? ?? '',
      'token_type': map['token_type'] as String? ?? '',
    };
  }
}
