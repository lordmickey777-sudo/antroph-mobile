import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../env/env.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  final _log = Logger();
  Dio? _dio;

  Dio get dio {
    final existing = _dio;
    if (existing != null) return existing;
    final rawBase = AppEnv.apiBaseUrl.trim();
    if (rawBase.isEmpty) {
      throw ArgumentError(
        'API_BASE_URL is not set. Configure it in .env (and include it in pubspec assets) or via --dart-define=API_BASE_URL=...',
      );
    }
    final baseUrl = _normalizeBaseUrl(rawBase);
    final d = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ),
    );
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _log.t('${options.method} ${options.uri}');
          handler.next(options);
        },
        onError: (e, handler) {
          _log.e('HTTP ${e.response?.statusCode} ${e.requestOptions.uri}', error: e);
          handler.next(e);
        },
      ),
    );
    _dio = d;
    return d;
  }

  String _normalizeBaseUrl(String input) {
    String url = input;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }
}
