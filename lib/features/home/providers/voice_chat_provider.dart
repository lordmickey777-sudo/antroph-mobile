import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/env/env.dart';
import '../../story/providers/story_session_provider.dart';
import '../models/expression_models.dart';
import '../services/voice_chat_service.dart';
import '../services/audio_playback_service.dart';

/// State for voice chat interaction
enum PermissionDialogType { none, education, settings }

class VoiceChatState {
  final RobotExpression currentExpression;
  final bool isRecording;
  final bool isPlaying;
  final bool isProcessing;
  final String? userTranscription;
  final String? aiResponse;
  final String? errorMessage;
  final double playbackProgress;
  final PermissionDialogType permissionDialog;

  const VoiceChatState({
    this.currentExpression = RobotExpression.neutral,
    this.isRecording = false,
    this.isPlaying = false,
    this.isProcessing = false,
    this.userTranscription,
    this.aiResponse,
    this.errorMessage,
    this.playbackProgress = 0.0,
    this.permissionDialog = PermissionDialogType.none,
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
    PermissionDialogType? permissionDialog,
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
      permissionDialog: permissionDialog ?? this.permissionDialog,
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
  bool _iosPermissionDeniedOnce = false;
  Completer<bool>? _permissionDialogCompleter;
  static const String _permissionError = 'Microphone permission is required for voice chat';

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

      final hasPermission = await _ensureMicrophonePermission();
      if (!hasPermission) {
        _log.w('Microphone permission not granted. Recording aborted.');
        return;
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
      final filePath = '${tempDir.path}/voice_input_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _audioRecorder!.startRecorder(
        toFile: filePath,
        codec: Codec.aacMP4,
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

  Future<bool> _ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    _log.i('Current microphone permission status: $status');

    if (status.isGranted) {
      _resetPermissionDialogState();
      _iosPermissionDeniedOnce = false;
      state = state.copyWith(errorMessage: null);
      return true;
    }

    if (_shouldOpenMicrophoneSettings(status)) {
      await _showSettingsDialog();
      _setPermissionError();
      return false;
    }

    final proceed = await _showEducationDialogAndWait();
    if (!proceed) {
      _setPermissionError();
      return false;
    }

    final requestedStatus = await Permission.microphone.request();
    status = requestedStatus;
    _log.i('Microphone permission request result: $status');

    if (requestedStatus.isGranted) {
      _resetPermissionDialogState();
      _iosPermissionDeniedOnce = false;
      state = state.copyWith(errorMessage: null);
      return true;
    }

    if (_isIOS && requestedStatus.isDenied) {
      _iosPermissionDeniedOnce = true;
    }

    if (_shouldOpenMicrophoneSettings(requestedStatus)) {
      await _showSettingsDialog();
    } else {
      _setPermissionError();
    }
    return false;
  }

  Future<bool> _showEducationDialogAndWait() async {
    if (_permissionDialogCompleter != null && !_permissionDialogCompleter!.isCompleted) {
      return _permissionDialogCompleter!.future;
    }
    final completer = Completer<bool>();
    _permissionDialogCompleter = completer;
    state = state.copyWith(permissionDialog: PermissionDialogType.education);
    return completer.future;
  }

  Future<void> _showSettingsDialog() async {
    _permissionDialogCompleter?.complete(false);
    _permissionDialogCompleter = null;
    state = state.copyWith(permissionDialog: PermissionDialogType.settings);
  }

  bool _shouldOpenMicrophoneSettings(PermissionStatus status) {
    if (status.isPermanentlyDenied || status.isRestricted) {
      return true;
    }
    if (_isIOS && _iosPermissionDeniedOnce && status.isDenied) {
      return true;
    }
    return false;
  }

  bool get _isIOS => Platform.isIOS;

  void handleEducationDialogResult(bool accepted) {
    if (_permissionDialogCompleter != null && !_permissionDialogCompleter!.isCompleted) {
      _permissionDialogCompleter!.complete(accepted);
    }
    _permissionDialogCompleter = null;
    _resetPermissionDialogState();
  }

  void dismissPermissionDialog() {
    if (_permissionDialogCompleter != null && !_permissionDialogCompleter!.isCompleted) {
      _permissionDialogCompleter!.complete(false);
    }
    _permissionDialogCompleter = null;
    _resetPermissionDialogState();
  }

  void _resetPermissionDialogState() {
    state = state.copyWith(permissionDialog: PermissionDialogType.none);
  }

  void _setPermissionError() {
    state = state.copyWith(errorMessage: _permissionError);
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

      final storySessionId = _activeStorySessionId();
      final robotSerial = _resolveRobotSerial();

      // Send to backend
      final response = await _voiceChatService.sendVoiceMessage(
        audioFile: audioFile,
        conversationType: 'general',
        language: 'en',
        voice: 'nova',
        storySessionId: storySessionId,
        robotSerial: robotSerial,
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

  String? _activeStorySessionId() {
    return ref.read(storySessionProvider).session?.id;
  }

  String _resolveRobotSerial() {
    final envSerial = AppEnv.robotSerial.trim();
    if (envSerial.isNotEmpty) {
      return envSerial;
    }
    final os = Platform.operatingSystem;
    return '$os-mobile-app';
  }
}

/// Provider for voice chat controller
final voiceChatControllerProvider =
    NotifierProvider.autoDispose<VoiceChatController, VoiceChatState>(VoiceChatController.new);
