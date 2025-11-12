import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import '../models/story_models.dart';
import '../models/story_detail.dart';

class StoriesRepository {
  StoriesRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  /// Fetch home sections for stories page.
  /// Public endpoint; no auth required.
  Future<StoriesHomeResponse> fetchHomeSections({
    int limitPerSection = 6,
    int collectionsPage = 1,
    int collectionsPageSize = 10,
  }) async {
    try {
      final res = await _dio.get(
        '/stories/home',
        queryParameters: {
          'limit_per_section': limitPerSection,
          'collections_page': collectionsPage,
          'collections_page_size': collectionsPageSize,
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      final data = res.data as Map<String, dynamic>;
      return StoriesHomeResponse.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  /// Fetch detailed story information by ID.
  /// Public endpoint; no auth required.
  Future<StoryDetailDto> fetchStoryDetail(String storyId) async {
    try {
      final res = await _dio.get(
        '/stories/$storyId',
        options: Options(extra: const {'skipAuth': true}),
      );
      final data = res.data as Map<String, dynamic>;
      return StoryDetailDto.fromJson(data);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }
}
