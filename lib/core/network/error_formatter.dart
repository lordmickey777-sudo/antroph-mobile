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
    // Prefer specific validation details over generic envelope messages.
    // Supported examples:
    // - { details: { message: "Username must be 3-50 characters" } }
    // - { detail: [ { msg: "..." } ] }
    // - { message: "..." } / { error: "..." }
    final data = e.response?.data;
    final extracted = _extractMessage(data);

    final fallback = _defaultMessage(e, status);
    return ApiError(
      message: extracted?.trim().isNotEmpty == true
          ? extracted!.trim()
          : fallback,
      statusCode: status,
      raw: e,
    );
  }

  static String? _extractMessage(Object? data) {
    if (data is String && data.trim().isNotEmpty) return data.trim();
    if (data is! Map<String, dynamic>) return null;

    final details = data['details'];
    final detailsMessage = _messageFromDetails(details);
    if (detailsMessage != null) return detailsMessage;

    final detail = data['detail'];
    final detailMessage = _messageFromDetail(detail);
    if (detailMessage != null) return detailMessage;

    return _firstString(data, const ['message', 'error', 'tip']);
  }

  static String? _messageFromDetails(Object? details) {
    if (details is String && details.trim().isNotEmpty) return details.trim();
    if (details is List) return _messageFromDetail(details);
    if (details is! Map) return null;

    final message = _firstString(details, const ['message', 'msg', 'detail']);
    if (message != null) {
      final field = _firstString(details, const ['field']);
      if (field != null && field.isNotEmpty) {
        return _prefixField(message, field);
      }
      return message;
    }

    final errors = details['errors'];
    return _messageFromDetail(errors);
  }

  static String? _messageFromDetail(Object? detail) {
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List) {
      for (final item in detail) {
        final message = _messageFromDetail(item);
        if (message != null) return message;
      }
      return null;
    }
    if (detail is! Map) return null;

    final message = _firstString(detail, const ['message', 'msg', 'detail']);
    if (message == null) return null;
    final field = _fieldFromDetail(detail);
    return field == null ? message : _prefixField(message, field);
  }

  static String? _firstString(Map<dynamic, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _fieldFromDetail(Map<dynamic, dynamic> detail) {
    final field = _firstString(detail, const ['field']);
    if (field != null) return field;

    final loc = detail['loc'];
    if (loc is List && loc.isNotEmpty) {
      final last = loc.last.toString().trim();
      if (last.isNotEmpty) return last;
    }
    return null;
  }

  static String _prefixField(String message, String field) {
    final normalizedField = field.trim();
    if (normalizedField.isEmpty) return message;
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains(normalizedField.toLowerCase())) return message;
    return '${_humanizeField(normalizedField)}: $message';
  }

  static String _humanizeField(String field) {
    final spaced = field.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (spaced.isEmpty) return field;
    return spaced[0].toUpperCase() + spaced.substring(1);
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
