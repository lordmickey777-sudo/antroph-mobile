import 'package:dio/dio.dart';

class ApiError {
  final String message;
  final int? statusCode;
  final DioException? raw;
  const ApiError({required this.message, this.statusCode, this.raw});
}

class ErrorFormatter {
  static ApiError fromDio(DioException e) {
    final status = e.response?.statusCode;
    // Attempt to parse common validation error structure { detail: [ { msg: ... } ] }
    String? extracted;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) extracted = first['msg'] as String;
      } else if (detail is String) {
        extracted = detail;
      } else if (data['message'] is String) {
        extracted = data['message'] as String;
      }
    } else if (data is String && data.isNotEmpty) {
      extracted = data;
    }

    final fallback = _defaultMessage(e, status);
    return ApiError(
      message: extracted?.trim().isNotEmpty == true ? extracted!.trim() : fallback,
      statusCode: status,
      raw: e,
    );
  }

  static String _defaultMessage(DioException e, int? status) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network timeout. Please retry.';
      case DioExceptionType.badResponse:
        if (status == 401) return 'Unauthorized. Please login again.';
        if (status == 422) return 'Invalid input. Please review the form.';
        if (status == 404) return 'Not found.';
        if (status != null && status >= 500) return 'Server error. Try later.';
        return 'Request failed (${status ?? 'error'}).';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'Bad SSL certificate.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.unknown:
        return 'Unexpected error occurred.';
    }
  }
}
