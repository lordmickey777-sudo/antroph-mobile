import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'User-Agent':
            'Antroph-Mobile/${const String.fromEnvironment('APP_RELEASE', defaultValue: 'dev')}',
      },
    ),
  );

  dio.interceptors.add(_LogInterceptor());
  dio.interceptors.add(_SentryInterceptor());
  return dio;
});

class _LogInterceptor extends Interceptor {
  final _logger = Logger();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.i('--> ${options.method} ${options.uri}');
      _logger.d('Headers: ${options.headers}');
      if (options.data != null) _logger.d('Body: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.i('<-- ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e('Dio error', error: err, stackTrace: err.stackTrace);
    handler.next(err);
  }
}

class _SentryInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Sentry.captureException(err, stackTrace: err.stackTrace);
    handler.next(err);
  }
}
