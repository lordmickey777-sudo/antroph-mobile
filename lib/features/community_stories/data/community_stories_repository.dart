import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import '../models/community_story_model.dart';
import '../models/rive_element_model.dart';

class CommunityStoriesRepository {
  CommunityStoriesRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  /// Fetch active Rive elements from the public catalog.
  Future<List<RiveElementDto>> fetchRiveElements({String? category}) async {
    try {
      final res = await _dio.get(
        '/rive-elements',
        queryParameters: {if (category != null) 'category': category},
        options: Options(extra: const {'skipAuth': true}),
      );
      final list = (res.data is List) ? res.data as List : [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => RiveElementDto.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Create a new community story.
  Future<CommunityStoryDto> createStory(CommunityStoryCreateDto data) async {
    try {
      final res = await _dio.post('/stories/community', data: data.toJson());
      return CommunityStoryDto.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Fetch the current user's community stories.
  Future<List<CommunityStoryDto>> fetchMyStories({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await _dio.get(
        '/stories/community/me',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      final list = _extractList(res.data);
      return list.map((e) => CommunityStoryDto.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Fetch a single community story owned by the current user.
  Future<CommunityStoryDto> fetchStory(String storyId) async {
    try {
      final res = await _dio.get('/stories/community/$storyId');
      return CommunityStoryDto.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Update a community story (only if pending or rejected).
  Future<CommunityStoryDto> updateStory(
    String storyId,
    CommunityStoryUpdateDto data,
  ) async {
    try {
      final res = await _dio.put(
        '/stories/community/$storyId',
        data: data.toJson(),
      );
      return CommunityStoryDto.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Delete a community story owned by the current user.
  Future<void> deleteStory(String storyId) async {
    try {
      await _dio.delete('/stories/community/$storyId');
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Upload a cover image for a community story.
  Future<Map<String, dynamic>> uploadCoverImage(
    String storyId,
    File imageFile,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path),
      });
      final res = await _dio.post(
        '/stories/community/$storyId/cover-image',
        data: formData,
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Browse approved and published community stories.
  Future<List<CommunityStoryDto>> browseCommunityStories({
    int page = 1,
    int pageSize = 20,
    String? categoryId,
  }) => _browsePublishedCommunityStories(
    page: page,
    pageSize: pageSize,
    categoryId: categoryId,
  );

  Future<List<CommunityStoryDto>> _browsePublishedCommunityStories({
    required int page,
    required int pageSize,
    String? categoryId,
  }) async {
    try {
      final res = await _dio.get(
        '/stories/community/browse/all',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (categoryId != null) 'category_id': categoryId,
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      final list = _extractList(res.data);
      return list
          .map(CommunityStoryDto.fromJson)
          .where((story) => story.isApprovedAndPublished)
          .toList();
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map<String, dynamic>) {
      final nested =
          (payload['stories'] as List?) ??
          (payload['items'] as List?) ??
          (payload['data'] as List?) ??
          (payload['results'] as List?);
      if (nested != null) {
        return nested.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }
}
