import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expression_models.dart';
import '../services/voice_chat_service.dart';
import '../services/audio_playback_service.dart';

/// State for voice chat interaction
class VoiceChatState {
  final RobotExpression currentExpression;
  final bool isRecording;
  final bool isPlaying;
  final bool isProcessing;
  final String? userTranscription;
  final String? aiResponse;
  final String? errorMessage;
  final double playbackProgress;
  final bool showPermissionModal;

  const VoiceChatState({
    this.currentExpression = RobotExpression.neutral,
    this.isRecording = false,
    this.isPlaying = false,
    this.isProcessing = false,
    this.userTranscription,
    this.aiResponse,
    this.errorMessage,
    this.playbackProgress = 0.0,
    this.showPermissionModal = false,
  });

  VoiceChatState copyWith({
    RobotExpression? currentExpression,
    bool? isRecording,
    bool? isPlaying,
    bool? isProcessing,
    String? userTranscription,
    String? aiResponse,
    String? errorMessage,
    double? playbackProgress,
    bool? showPermissionModal,
  }) {
    return VoiceChatState(
      currentExpression: currentExpression ?? this.currentExpression,
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      isProcessing: isProcessing ?? this.isProcessing,
      userTranscription: userTranscription ?? this.userTranscription,
      aiResponse: aiResponse ?? this.aiResponse,
      errorMessage: errorMessage,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      showPermissionModal: showPermissionModal ?? this.showPermissionModal,
    );
  }

  bool get isBusy => isRecording || isProcessing || isPlaying;
}

/// Controller for voice chat interactions
class VoiceChatController extends Notifier<VoiceChatState> {
  final VoiceChatService _voiceChatService = VoiceChatService.instance;
  final AudioPlaybackService _audioService = AudioPlaybackService();
  FlutterSoundRecorder? _audioRecorder;
  final Logger _log = Logger();

  @override
  VoiceChatState build() {
    // Initialize recorder
    _audioRecorder = FlutterSoundRecorder();

    // Clean up on disposal
    ref.onDispose(() {
      _audioRecorder?.closeRecorder();
      _audioService.dispose();
    });
    return const VoiceChatState();
  }

  /// Start recording user voice
  Future<void> startRecording() async {
    try {
      if (state.isBusy) {
        _log.w('Cannot start recording: already busy');
        return;
      }

      // Check current permission status
      var status = await Permission.microphone.status;

      // If permission is denied, show custom modal
      if (status.isDenied || status.isPermanentlyDenied) {
        _log.w('Microphone permission denied - showing modal');
        state = state.copyWith(showPermissionModal: true);

        // Request permission
        status = await Permission.microphone.request();

        // If still denied after request, return
        if (!status.isGranted) {
          _log.e('Microphone permission denied after request');
          state = state.copyWith(
            showPermissionModal: false,
            errorMessage: 'Microphone permission is required for voice chat',
          );
          return;
        }

        // Permission granted, hide modal
        state = state.copyWith(showPermissionModal: false);
      } else if (!status.isGranted) {
        // Request permission for first time
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          _log.e('Microphone permission denied');
          state = state.copyWith(
            showPermissionModal: true,
            errorMessage: 'Microphone permission is required for voice chat',
          );
          return;
        }
      }

      // Initialize recorder if needed
      if (_audioRecorder == null) {
        _audioRecorder = FlutterSoundRecorder();
      }

      if (!_audioRecorder!.isRecording) {
        await _audioRecorder!.openRecorder();
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_input_${DateTime.now().millisecondsSinceEpoch}.aac';

      // Start recording
      await _audioRecorder!.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
        bitRate: 128000,
        sampleRate: 44100,
      );

      state = state.copyWith(isRecording: true, errorMessage: null);
      _log.i('Recording started: $filePath');
    } catch (e, stackTrace) {
      _log.e('Failed to start recording', error: e, stackTrace: stackTrace);
      state = state.copyWith(isRecording: false, errorMessage: 'Failed to start recording: $e');
    }
  }

  /// Stop recording and send to backend
  Future<void> stopRecordingAndSend() async {
    try {
      if (!state.isRecording) {
        _log.w('Cannot stop recording: not recording');
        return;
      }

      // Stop recording
      final path = await _audioRecorder?.stopRecorder();
      state = state.copyWith(isRecording: false, isProcessing: true);

      if (path == null || path.isEmpty) {
        throw Exception('Recording failed: no file path returned');
      }

      _log.i('Recording stopped: $path');

      final audioFile = File(path);
      if (!await audioFile.exists()) {
        throw Exception('Recording file not found');
      }

      // Send to backend
      final response = await _voiceChatService.sendVoiceMessage(
        audioFile: audioFile,
        conversationType: 'general',
        language: 'en',
        voice: 'nova',
      );

      _log.i('Voice chat response received: ${response.text}');

      // Update state with response
      state = state.copyWith(
        isProcessing: false,
        userTranscription: response.transcription,
        aiResponse: response.text,
        errorMessage: null,
      );

      // Play audio with synchronized expressions
      await _playResponseAudio(response);

      // Clean up recording file
      audioFile.delete().catchError((e) {
        _log.w('Failed to delete recording file: $e');
        return audioFile;
      });
    } catch (e, stackTrace) {
      _log.e('Failed to process voice message', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        errorMessage: e is VoiceChatException ? e.message : 'Failed to process voice: $e',
      );
    }
  }

  /// Play AI response audio with expression synchronization
  Future<void> _playResponseAudio(VoiceChatResponse response) async {
    try {
      state = state.copyWith(isPlaying: true);

      await _audioService.playSynchronizedAudio(
        audioBase64: response.audioUrl,
        expressions: response.expressions,
        onExpressionChange: (expression) {
          state = state.copyWith(currentExpression: expression);
        },
        onComplete: () {
          state = state.copyWith(isPlaying: false, currentExpression: RobotExpression.neutral);
        },
      );
    } catch (e, stackTrace) {
      _log.e('Failed to play audio', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isPlaying: false,
        currentExpression: RobotExpression.neutral,
        errorMessage: 'Failed to play audio: $e',
      );
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    try {
      if (state.isRecording) {
        final path = await _audioRecorder?.stopRecorder();
        if (path != null && path.isNotEmpty) {
          File(path).delete().catchError((e) {
            _log.w('Failed to delete cancelled recording: $e');
            return File(path);
          });
        }
        state = state.copyWith(isRecording: false, errorMessage: null);
        _log.i('Recording cancelled');
      }
    } catch (e, stackTrace) {
      _log.e('Failed to cancel recording', error: e, stackTrace: stackTrace);
      state = state.copyWith(isRecording: false);
    }
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    await _audioService.stop();
    state = state.copyWith(isPlaying: false, currentExpression: RobotExpression.neutral);
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Dismiss permission modal
  void dismissPermissionModal() {
    state = state.copyWith(showPermissionModal: false);
  }
}

/// Provider for voice chat controller
final voiceChatControllerProvider =
    NotifierProvider.autoDispose<VoiceChatController, VoiceChatState>(VoiceChatController.new);
