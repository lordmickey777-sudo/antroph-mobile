import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import '../models/expression_models.dart';

/// Service for synchronized audio playback with facial expressions
class AudioPlaybackService {
  AudioPlayer? _audioPlayer;
  final List<Timer> _expressionTimers = [];
  final _log = Logger();

  bool get isPlaying => _audioPlayer?.playing ?? false;

  /// Play audio with synchronized facial expressions
  Future<void> playSynchronizedAudio({
    required String audioBase64,
    required List<ExpressionTiming> expressions,
    required Function(RobotExpression) onExpressionChange,
    VoidCallback? onComplete,
  }) async {
    try {
      _log.d('Starting synchronized audio playback with ${expressions.length} expressions');

      // Clean up any existing playback
      await stop();

      // Decode base64 audio from data URL
      final base64Data = _extractBase64Data(audioBase64);
      if (base64Data.isEmpty) {
        throw AudioPlaybackException('Invalid audio data URL');
      }

      final audioBytes = base64.decode(base64Data);
      _log.d('Decoded ${audioBytes.length} bytes of audio data');

      // Create temporary file for audio
      final tempDir = await getTemporaryDirectory();
      final audioFile = File(
        '${tempDir.path}/voice_response_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await audioFile.writeAsBytes(audioBytes);
      _log.d('Audio file created: ${audioFile.path}');

      // Initialize audio player
      _audioPlayer = AudioPlayer();

      // Schedule expressions
      _scheduleExpressions(expressions, onExpressionChange);

      // Set up completion handler
      _audioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _log.d('Audio playback completed');
          _cancelExpressionTimers();
          onExpressionChange(RobotExpression.neutral);
          audioFile.delete().catchError((e) {
            _log.w('Failed to delete temp audio file: $e');
            return audioFile;
          });
          onComplete?.call();
        }
      });

      // Play audio
      await _audioPlayer!.setFilePath(audioFile.path);
      await _audioPlayer!.play();
      _log.i('Audio playback started');
    } catch (e, stackTrace) {
      _log.e('Audio playback error', error: e, stackTrace: stackTrace);
      _cancelExpressionTimers();
      throw AudioPlaybackException('Failed to play audio: $e');
    }
  }

  /// Schedule expression changes based on timing data
  void _scheduleExpressions(
    List<ExpressionTiming> expressions,
    Function(RobotExpression) onExpressionChange,
  ) {
    _cancelExpressionTimers(); // Clear any existing timers

    for (final expression in expressions) {
      final delay = Duration(milliseconds: (expression.startTime * 1000).round());

      final timer = Timer(delay, () {
        _log.d('Triggering expression: ${expression.action.value} at ${expression.startTime}s');
        onExpressionChange(expression.action);

        // Reset to neutral after duration (if specified)
        if (expression.duration != null) {
          final resetDelay = Duration(milliseconds: (expression.duration! * 1000).round());
          final resetTimer = Timer(resetDelay, () {
            _log.d('Resetting expression to neutral after ${expression.duration}s');
            onExpressionChange(RobotExpression.neutral);
          });
          _expressionTimers.add(resetTimer);
        }
      });

      _expressionTimers.add(timer);
    }

    _log.d('Scheduled ${_expressionTimers.length} expression timers');
  }

  /// Extract base64 data from data URL (e.g., "data:audio/mpeg;base64,<data>")
  String _extractBase64Data(String dataUrl) {
    if (!dataUrl.startsWith('data:')) return dataUrl; // Already base64
    final parts = dataUrl.split(',');
    return parts.length > 1 ? parts[1] : '';
  }

  /// Cancel all scheduled expression timers
  void _cancelExpressionTimers() {
    for (final timer in _expressionTimers) {
      timer.cancel();
    }
    _expressionTimers.clear();
    _log.d('Cancelled all expression timers');
  }

  /// Stop audio playback and clean up
  Future<void> stop() async {
    _cancelExpressionTimers();
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
      await _audioPlayer!.dispose();
      _audioPlayer = null;
      _log.d('Audio player stopped and disposed');
    }
  }

  /// Pause audio playback
  Future<void> pause() async {
    if (_audioPlayer?.playing ?? false) {
      await _audioPlayer!.pause();
      _log.d('Audio playback paused');
    }
  }

  /// Resume audio playback
  Future<void> resume() async {
    if (_audioPlayer != null && !(_audioPlayer!.playing)) {
      await _audioPlayer!.play();
      _log.d('Audio playback resumed');
    }
  }

  /// Get current playback position in seconds
  double get currentPosition {
    final position = _audioPlayer?.position.inMilliseconds ?? 0;
    return position / 1000.0;
  }

  /// Get total duration in seconds
  double get duration {
    final dur = _audioPlayer?.duration?.inMilliseconds ?? 0;
    return dur / 1000.0;
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}

/// Custom exception for audio playback errors
class AudioPlaybackException implements Exception {
  final String message;

  AudioPlaybackException(this.message);

  @override
  String toString() => 'AudioPlaybackException: $message';
}
