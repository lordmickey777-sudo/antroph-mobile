import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import '../models/ai_settings.dart';

class AiSettingsRepository {
  AiSettingsRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  static const _endpoint = '/ai/settings';

  Future<AiSettings> fetchSettings() async {
    try {
      final response = await _dio.get(_endpoint);
      return AiSettings.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<AiSettings> updateSettings(AiSettings settings) async {
    try {
      final response = await _dio.put(_endpoint, data: settings.toJson());
      return AiSettings.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<AiSettings> resetSettings() async {
    try {
      final response = await _dio.post('$_endpoint/reset');
      return AiSettings.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }
}
