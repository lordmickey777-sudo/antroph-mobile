import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import 'voice_option.dart';

class VoicesRepository {
  VoicesRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  static const _endpoint = '/ai/voices';

  Future<VoiceListResult> fetchVoices() async {
    try {
      final response = await _dio.get(_endpoint);
      return VoiceListResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }
}
