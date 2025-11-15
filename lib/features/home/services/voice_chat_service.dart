import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../../core/network/api_client.dart';
import '../models/expression_models.dart';

/// Service for voice chat API interactions
class VoiceChatService {
  VoiceChatService._();
  static final VoiceChatService instance = VoiceChatService._();

  final _log = Logger();
  static const String _voiceChatEndpoint = '/ai/voice/chat';

  /// Send voice message to backend and get AI response with expressions
  Future<VoiceChatResponse> sendVoiceMessage({
    required File audioFile,
    String conversationType = 'general',
    String language = 'en',
    String voice = 'nova',
    String? storySessionId,
    String? robotSerial,
  }) async {
    try {
      _log.d('Sending voice message: ${audioFile.path}');

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'audio.${_getFileExtension(audioFile.path)}',
        ),
        'conversation_type': conversationType,
        'language': language,
        'voice': voice,
        if (storySessionId != null && storySessionId.isNotEmpty) 'story_session_id': storySessionId,
        if (robotSerial != null && robotSerial.isNotEmpty) 'robot_serial': robotSerial,
      });

      final response = await ApiClient.I.dio.post(
        _voiceChatEndpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60), // Longer timeout for AI processing
        ),
      );

      if (response.statusCode == 200) {
        _log.i('Voice chat response received');
        return VoiceChatResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw VoiceChatException(
          'Voice chat failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      _log.e('Voice chat API error', error: e);
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw VoiceChatException('Request timed out. Please try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw VoiceChatException('No internet connection');
      } else if (e.response != null) {
        throw VoiceChatException(
          'Voice chat failed: ${e.response?.statusMessage ?? "Unknown error"}',
          statusCode: e.response?.statusCode,
        );
      } else {
        throw VoiceChatException('Network error: ${e.message}');
      }
    } catch (e, stackTrace) {
      _log.e('Unexpected voice chat error', error: e, stackTrace: stackTrace);
      throw VoiceChatException('Unexpected error: $e');
    }
  }

  String _getFileExtension(String path) {
    final parts = path.split('.');
    return parts.isNotEmpty ? parts.last : 'mp3';
  }
}

/// Custom exception for voice chat errors
class VoiceChatException implements Exception {
  final String message;
  final int? statusCode;

  VoiceChatException(this.message, {this.statusCode});

  @override
  String toString() =>
      'VoiceChatException: $message${statusCode != null ? " (Status: $statusCode)" : ""}';
}
