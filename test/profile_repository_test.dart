import 'package:antroph_mobile/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockRegistry {
  final Map<String, Map<String, dynamic>> _responses = {};
  void when({required String method, required String path, required Map<String, dynamic> json}) {
    _responses['${method.toUpperCase()} $path'] = json;
  }

  Map<String, dynamic>? match(String method, String path) =>
      _responses['${method.toUpperCase()} $path'];
}

void main() {
  group('ProfileRepository', () {
    late Dio dio;
    late _MockRegistry reg;
    late ProfileRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      reg = _MockRegistry();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final json = reg.match(options.method, options.path);
            if (json != null) {
              handler.resolve(Response(requestOptions: options, data: json, statusCode: 200));
              return;
            }
            handler.next(options);
          },
        ),
      );
      repo = ProfileRepository(dio: dio);
    });

    test('updateProfile parses response into UserProfile', () async {
      reg.when(
        method: 'PUT',
        path: '/users/me',
        json: {
          'id': '123',
          'email': 'test@example.com',
          'username': 'tester',
          'display_name': 'Test User',
          'avatar_url': 'https://cdn/avatar.png',
          'bio': 'Hi',
          'date_of_birth': '2000-01-02T00:00:00Z',
          'timezone': 'UTC',
          'language': 'en',
        },
      );

      final result = await repo.updateProfile(username: 'tester');
      expect(result.id, '123');
      expect(result.username, 'tester');
      expect(result.displayName, 'Test User');
    });

    test('checkUsernameAvailability returns availability object', () async {
      reg.when(
        method: 'GET',
        path: '/users/username/newname/available',
        json: {'username': 'newname', 'available': true},
      );

      final availability = await repo.checkUsernameAvailability('newname');
      expect(availability.username, 'newname');
      expect(availability.available, true);
    });
  });
}
