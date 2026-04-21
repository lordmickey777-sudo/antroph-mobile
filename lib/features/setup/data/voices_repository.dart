import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import 'voice_option.dart';

class VoicesRepository {
  VoicesRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  static const _endpoint = '/ai/voices';

  // Process-wide cache so the voice selection page loads instantly when the
  // user has already passed through an earlier step (e.g. interest selection)
  // that kicked off a prefetch. Voices are a global catalog, so caching across
  // sessions on the same process is safe.
  static VoiceListResult? _cache;
  static Future<VoiceListResult>? _inFlight;

  Future<VoiceListResult> fetchVoices({bool forceRefresh = false}) {
    if (!forceRefresh) {
      final cached = _cache;
      if (cached != null) return Future.value(cached);
      final inFlight = _inFlight;
      if (inFlight != null) return inFlight;
    }
    final future = _fetch();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  /// Fire-and-forget warm-up; safe to call multiple times. Errors are swallowed
  /// so the caller never has to handle them — the selection page will surface
  /// any failure the next time it calls [fetchVoices].
  void prefetch() {
    if (_cache != null || _inFlight != null) return;
    fetchVoices().ignore();
  }

  static void clearCache() {
    _cache = null;
    _inFlight = null;
  }

  Future<VoiceListResult> _fetch() async {
    try {
      final response = await _dio.get(_endpoint);
      final result =
          VoiceListResult.fromJson(response.data as Map<String, dynamic>);
      _cache = result;
      return result;
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }
}
