import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:antroph_mobile/core/auth/repository/auth_repository.dart';

/// A simple fake adapter to intercept requests and return canned responses.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions)> handlers = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final handler = handlers[options.path];
    if (handler != null) {
      return handler(options);
    }
    return ResponseBody.fromString(
      '{"message":"not found"}',
      404,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}

void main() {
  late Dio dio;
  late AuthRepository repo;
  late _FakeAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    repo = AuthRepository(dio: dio);
  });

  test('requestPasswordReset returns message', () async {
    adapter.handlers['/auth/forgot-password'] = (req) => ResponseBody.fromString(
      '{"message":"reset sent"}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
    final msg = await repo.requestPasswordReset(email: 'user@example.com');
    expect(msg, 'reset sent');
  });

  test('resetPassword returns message', () async {
    adapter.handlers['/auth/reset-password'] = (req) => ResponseBody.fromString(
      '{"message":"password updated"}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
    final msg = await repo.resetPassword(
      email: 'user@example.com',
      token: '123456',
      newPassword: 'Abcdef12',
    );
    expect(msg, 'password updated');
  });
}
