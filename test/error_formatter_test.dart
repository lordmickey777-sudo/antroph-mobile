import 'package:antroph_mobile/core/network/error_formatter.dart' as app;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorFormatter.fromDio', () {
    test('prefers nested validation details message', () {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 422,
          data: const <String, dynamic>{
            'success': false,
            'error': 'Request validation failed',
            'details': <String, dynamic>{
              'error_type': 'Validation Error',
              'field': 'username',
              'message': 'Username must be 3-50 characters',
              'validation_type': 'value_error',
              'suggestions': <String>[
                "Check the field 'username' in your request",
                'Refer to the API documentation for the correct format',
              ],
            },
            'tip':
                'One or more fields in your request are invalid. Please check the error details and API documentation.',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final error = app.ErrorFormatter.fromDio(exception);

      expect(error.message, 'Username must be 3-50 characters');
    });

    test('prefixes field when validation message omits it', () {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 422,
          data: const <String, dynamic>{
            'details': <String, dynamic>{
              'field': 'username',
              'message': 'Must be 3-50 characters',
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final error = app.ErrorFormatter.fromDio(exception);

      expect(error.message, 'Username: Must be 3-50 characters');
    });
  });
}
