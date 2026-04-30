import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import '../models/ai_settings.dart';

class AiSettingsRepository {
  AiSettingsRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  static const _endpoint = '/ai/settings';
  static const _autoListenKey = 'auto_listen_after_response';

  Future<AiSettings> fetchSettings() async {
    try {
      final response = await _dio.get(_endpoint);
      final settings = AiSettings.fromJson(response.data as Map<String, dynamic>);
      
      final prefs = await SharedPreferences.getInstance();
      final autoListen = prefs.getBool(_autoListenKey) ?? true;
      
      return settings.copyWith(autoListenAfterResponse: autoListen);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<AiSettings> updateSettings(AiSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoListenKey, settings.autoListenAfterResponse);

      final response = await _dio.put(_endpoint, data: settings.toJson());
      final updated = AiSettings.fromJson(response.data as Map<String, dynamic>);
      
      return updated.copyWith(autoListenAfterResponse: settings.autoListenAfterResponse);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }

  Future<AiSettings> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_autoListenKey);

      final response = await _dio.post('$_endpoint/reset');
      final defaults = AiSettings.fromJson(response.data as Map<String, dynamic>);
      
      return defaults.copyWith(autoListenAfterResponse: true);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }
}
