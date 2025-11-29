import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  ProfileRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  /// GET /users/me to retrieve the current user's full profile
  Future<UserProfile> getMyProfile() async {
    try {
      final res = await _dio.get('/users/me');
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Upload avatar image as base64 string to /users/me/avatar
  /// Returns the avatar URL or opaque response string depending on backend.
  Future<String> uploadAvatar({required String avatarBase64}) async {
    try {
      final res = await _dio.post('/users/me/avatar', data: {'avatar_data': avatarBase64});
      final data = res.data;
      if (data is String) return data;
      if (data is Map && data['avatar_url'] is String) return data['avatar_url'] as String;
      return data?.toString() ?? '';
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// PUT /users/me to update profile fields; returns updated profile
  Future<UserProfile> updateProfile({
    String? username,
    String? displayName,
    String? bio,
    DateTime? dateOfBirth,
    String? timezone,
    String? language,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username;
      if (displayName != null) payload['display_name'] = displayName;
      if (bio != null) payload['bio'] = bio;
      if (dateOfBirth != null) payload['date_of_birth'] = dateOfBirth.toIso8601String();
      if (timezone != null) payload['timezone'] = timezone;
      if (language != null) payload['language'] = language;

      final res = await _dio.put('/users/me', data: payload);
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// GET /users/username/{username}/available to check username availability
  Future<UsernameAvailability> checkUsernameAvailability(
    String username, {
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/users/username/${Uri.encodeComponent(username)}/available',
        cancelToken: cancelToken,
      );
      return UsernameAvailability.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// DELETE /users/me/account to soft-delete the current user account.
  /// Returns the server message (if provided).
  Future<String> deleteAccount() async {
    try {
      final res = await _dio.delete('/users/me/account');
      final data = res.data;
      if (data is Map<String, dynamic> && data['message'] is String) {
        return data['message'] as String;
      }
      return 'Account deleted';
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }
}
