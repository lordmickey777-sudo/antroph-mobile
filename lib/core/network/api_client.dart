import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../env/env.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  final _log = Logger();
  Dio? _dio;
  // Auth state (in-memory).
  String? _accessToken;
  String? _refreshToken;
  String _tokenType = 'Bearer';

  // External refresh handler configured by auth layer.
  Future<bool> Function(String refreshToken)? _onRefresh;
  Future<bool>? _refreshing;

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
          // Skip auth header for explicit non-auth requests
          final skipAuth = options.extra['skipAuth'] == true;
          if (!skipAuth && _accessToken != null && _accessToken!.isNotEmpty) {
            options.headers['Authorization'] =
                '${_tokenType.isNotEmpty ? _tokenType : 'Bearer'} ${_accessToken!}';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          _log.e('HTTP ${e.response?.statusCode} ${e.requestOptions.uri}', error: e);
          final status = e.response?.statusCode;
          final req = e.requestOptions;
          final skipAuth = req.extra['skipAuth'] == true;
          final alreadyRetried = req.extra['retried'] == true;
          final hasRefresh = _refreshToken != null && _refreshToken!.isNotEmpty;

          if (!skipAuth && status == 401 && !alreadyRetried && hasRefresh && _onRefresh != null) {
            try {
              // Ensure a single refresh runs at a time
              _refreshing ??= _onRefresh!.call(_refreshToken!);
              final ok = await _refreshing!;
              _refreshing = null;
              if (ok && _accessToken != null && _accessToken!.isNotEmpty) {
                // Retry original request with updated token
                final opts = Options(
                  method: req.method,
                  headers: Map<String, dynamic>.from(req.headers)
                    ..['Authorization'] =
                        '${_tokenType.isNotEmpty ? _tokenType : 'Bearer'} ${_accessToken!}',
                  responseType: req.responseType,
                  contentType: req.contentType,
                  followRedirects: req.followRedirects,
                  listFormat: req.listFormat,
                  receiveDataWhenStatusError: req.receiveDataWhenStatusError,
                  validateStatus: req.validateStatus,
                );
                final newReq = RequestOptions(
                  path: req.path,
                  method: req.method,
                  headers: opts.headers,
                  baseUrl: req.baseUrl,
                  data: req.data,
                  queryParameters: req.queryParameters,
                  sendTimeout: req.sendTimeout,
                  receiveTimeout: req.receiveTimeout,
                  extra: Map<String, dynamic>.from(req.extra)..['retried'] = true,
                );
                final response = await d.fetch(newReq);
                return handler.resolve(response);
              }
            } catch (refreshErr) {
              // Fallthrough to original error
            } finally {
              _refreshing = null;
            }
          }
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

extension ApiClientAuth on ApiClient {
  /// Configure the in-memory tokens used for auth header.
  void setAuthTokens({String? accessToken, String? refreshToken, String? tokenType}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (tokenType != null && tokenType.isNotEmpty) {
      _tokenType = tokenType;
    }
  }

  /// Clear auth tokens (e.g., on logout).
  void clearAuthTokens() {
    _accessToken = null;
    _refreshToken = null;
    _tokenType = 'Bearer';
  }

  /// Set a callback that attempts to refresh tokens using the current refresh token.
  /// The callback should update tokens via [setAuthTokens] and return true on success.
  void setTokenRefresher(Future<bool> Function(String refreshToken) onRefresh) {
    _onRefresh = onRefresh;
  }
}
