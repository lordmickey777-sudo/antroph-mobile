import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/auth/state/auth_state.dart';
import '../../../core/env/env.dart';
import '../../../core/services/device_id_service.dart';
import '../models/expression_models.dart';
import '../models/realtime_voice_bridge_models.dart';
import '../services/pcm_audio_player.dart';
import '../services/realtime_voice_client.dart';

/// State for voice chat interaction
enum PermissionDialogType { none, education, settings }

class VoiceChatState {
  final RobotExpression currentExpression;
  final bool isRecording;
  final bool isPlaying;
  final bool isConnecting;
  final bool isProcessing;
  final String? userTranscription;
  final String? aiResponse;
  final Uint8List? aiAudioBytes;
  final String? errorMessage;
  final double playbackProgress;
  final PermissionDialogType permissionDialog;
  final List<String> audioFormats;
  final Uint8List? currentFaceBitmap;
  final int? faceTimestampMs;

  // Story-specific state
  final RealtimeVoicePhase phase;
  final StorySessionInfo? storySession;
  final RoomState? roomState;
  final bool isStoryMode;
  final List<ConversationItem> conversationHistory;

  const VoiceChatState({
    this.currentExpression = RobotExpression.neutral,
    this.isRecording = false,
    this.isPlaying = false,
    this.isConnecting = false,
    this.isProcessing = false,
    this.userTranscription,
    this.aiResponse,
    this.aiAudioBytes,
    this.errorMessage,
    this.playbackProgress = 0.0,
    this.permissionDialog = PermissionDialogType.none,
    this.audioFormats = const [],
    this.currentFaceBitmap,
    this.faceTimestampMs,
    this.phase = RealtimeVoicePhase.idle,
    this.storySession,
    this.roomState,
    this.isStoryMode = false,
    this.conversationHistory = const [],
  });

  VoiceChatState copyWith({
    RobotExpression? currentExpression,
    bool? isRecording,
    bool? isPlaying,
    bool? isConnecting,
    bool? isProcessing,
    String? userTranscription,
    String? aiResponse,
    Uint8List? aiAudioBytes,
    String? errorMessage,
    double? playbackProgress,
    PermissionDialogType? permissionDialog,
    List<String>? audioFormats,
    Uint8List? currentFaceBitmap,
    int? faceTimestampMs,
    bool clearFace = false,
    bool clearAiAudio = false,
    RealtimeVoicePhase? phase,
    StorySessionInfo? storySession,
    RoomState? roomState,
    bool? isStoryMode,
    List<ConversationItem>? conversationHistory,
    bool clearStorySession = false,
  }) {
    return VoiceChatState(
      currentExpression: currentExpression ?? this.currentExpression,
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      isConnecting: isConnecting ?? this.isConnecting,
      isProcessing: isProcessing ?? this.isProcessing,
      userTranscription: userTranscription ?? this.userTranscription,
      aiResponse: aiResponse ?? this.aiResponse,
      aiAudioBytes: clearAiAudio ? null : (aiAudioBytes ?? this.aiAudioBytes),
      errorMessage: errorMessage,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      permissionDialog: permissionDialog ?? this.permissionDialog,
      audioFormats: audioFormats ?? this.audioFormats,
      currentFaceBitmap:
          clearFace ? null : (currentFaceBitmap ?? this.currentFaceBitmap),
      faceTimestampMs:
          clearFace ? null : (faceTimestampMs ?? this.faceTimestampMs),
      phase: phase ?? this.phase,
      storySession:
          clearStorySession ? null : (storySession ?? this.storySession),
      roomState: roomState ?? this.roomState,
      isStoryMode: isStoryMode ?? this.isStoryMode,
      conversationHistory: conversationHistory ?? this.conversationHistory,
    );
  }

  bool get isBusy => isRecording || isProcessing || isPlaying || isConnecting;

  bool get isSessionReady =>
      phase == RealtimeVoicePhase.ready ||
      phase == RealtimeVoicePhase.recording ||
      phase == RealtimeVoicePhase.processing ||
      phase == RealtimeVoicePhase.playing;

  bool get canRecord =>
      phase == RealtimeVoicePhase.ready && !isRecording && !isProcessing;
}

/// Controller for voice chat interactions with story support
class VoiceChatController extends Notifier<VoiceChatState> {
  final Logger _log = Logger();
  final RealtimeVoiceClient _client;
  final AudioChunkPlayer _player;
  final Uri? _voiceUriOverride;
  FlutterSoundRecorder? _recorder;
  StreamSubscription<RealtimeIncomingMessage>? _socketSub;
  StreamController<Uint8List>? _micStreamController;
  StreamSubscription<Uint8List>? _micStreamSubscription;
  StreamController<double>? _micLevelController;
  StreamController<double>? _aiAudioLevelController;
  Timer? _aiAudioLevelTimer;
  Timer? _silenceTimer;
  final List<double> _pendingAiRmsValues = [];
  final StringBuffer _aiTextBuffer = StringBuffer();
  BytesBuilder _audioBuffer = BytesBuilder(copy: false);
  Completer<bool>? _permissionDialogCompleter;
  bool _iosPermissionDeniedOnce = false;
  bool _commitSent = false;
  bool _socketOpen = false;
  bool _audioEnabled = true;
  String? _pendingStorySessionId;

  static const int _sampleRate = 24000;
  static const String _outputAudioFormat = 'pcm16';
  static const String _outputVoice = 'alloy';
  static const String _deviceType = 'mobile';
  static const String _permissionError =
      'Microphone permission is required for voice chat';
  static const double _silenceThreshold = 0.01;
  static const Duration _silenceDuration = Duration(seconds: 2);

  VoiceChatController({
    RealtimeVoiceClient? client,
    AudioChunkPlayer? player,
    Uri? voiceUriOverride,
  })  : _client = client ?? RealtimeVoiceClient(),
        _player = player ?? createAudioChunkPlayer(),
        _voiceUriOverride = voiceUriOverride;

  Stream<double> get micLevelStream =>
      _micLevelController?.stream ?? Stream<double>.empty();

  Stream<double> get aiAudioLevelStream =>
      _aiAudioLevelController?.stream ?? Stream<double>.empty();

  @override
  VoiceChatState build() {
    _recorder = FlutterSoundRecorder();
    _micLevelController ??= StreamController<double>.broadcast();
    _aiAudioLevelController ??= StreamController<double>.broadcast();

    ref.onDispose(() async {
      _disableAudio();
      _cancelSilenceTimer();
      _stopAiAudioLevelTimer();
      await _stopRecorder();
      await _teardownSocket();
      await _player.dispose();
      await _micLevelController?.close();
      _micLevelController = null;
      await _aiAudioLevelController?.close();
      _aiAudioLevelController = null;
    });

    return const VoiceChatState();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Story Session Management
  // ─────────────────────────────────────────────────────────────────────────────

  /// Start a new story session and begin voice interaction.
  ///
  /// [storyId] - The story to start
  /// Connects to the voice bridge, sends story_start, and waits for story_session_ready.
  Future<void> startStorySession(String storyId) async {
    try {
      if (state.isBusy) {
        _log.w('Cannot start story session: already busy');
        return;
      }

      _pendingStorySessionId = null;
      _aiTextBuffer.clear();
      _commitSent = false;
      _resetAudioBuffer();

      state = state.copyWith(
        isConnecting: true,
        isProcessing: false,
        isPlaying: false,
        isStoryMode: true,
        phase: RealtimeVoicePhase.connecting,
        aiResponse: null,
        userTranscription: null,
        clearAiAudio: true,
        errorMessage: null,
        clearFace: true,
        conversationHistory: [],
      );

      await _connectSocket();

      // Send story_start after connection
      final deviceId = await DeviceIdService.getDeviceId();
      _client.sendStoryStart(
        storyId: storyId,
        deviceType: _deviceType,
        deviceId: deviceId,
      );

      state = state.copyWith(
        phase: RealtimeVoicePhase.waitingForReady,
        isConnecting: true,
      );

      _log.i('Story session starting for story: $storyId');
    } catch (e, st) {
      _log.e('Failed to start story session', error: e, stackTrace: st);
      state = state.copyWith(
        isConnecting: false,
        isProcessing: false,
        isPlaying: false,
        phase: RealtimeVoicePhase.error,
        errorMessage: '$e',
      );
      await _teardownSocket();
    }
  }

  /// Resume an existing story session.
  ///
  /// [storySessionId] - The session ID to resume
  /// Connects with story_session_id in query params and waits for story_session_ready.
  Future<void> resumeStorySession(String storySessionId) async {
    try {
      if (state.isBusy) {
        _log.w('Cannot resume story session: already busy');
        return;
      }

      _pendingStorySessionId = storySessionId;
      _aiTextBuffer.clear();
      _commitSent = false;
      _resetAudioBuffer();

      state = state.copyWith(
        isConnecting: true,
        isProcessing: false,
        isPlaying: false,
        isStoryMode: true,
        phase: RealtimeVoicePhase.connecting,
        aiResponse: null,
        userTranscription: null,
        clearAiAudio: true,
        errorMessage: null,
        clearFace: true,
      );

      await _connectSocket(storySessionId: storySessionId);

      state = state.copyWith(
        phase: RealtimeVoicePhase.waitingForReady,
        isConnecting: true,
      );

      _log.i('Resuming story session: $storySessionId');
    } catch (e, st) {
      _log.e('Failed to resume story session', error: e, stackTrace: st);
      state = state.copyWith(
        isConnecting: false,
        isProcessing: false,
        isPlaying: false,
        phase: RealtimeVoicePhase.error,
        errorMessage: '$e',
      );
      await _teardownSocket();
    }
  }

  /// Pause the current story session.
  Future<void> pauseStorySession() async {
    if (!state.isStoryMode || state.storySession == null) {
      _log.w('Cannot pause: no active story session');
      return;
    }

    _client.sendStoryPause();
    state = state.copyWith(phase: RealtimeVoicePhase.paused);
    _log.i('Story session paused');
  }

  /// Resume a paused story session.
  Future<void> resumePausedSession() async {
    if (!state.isStoryMode || state.phase != RealtimeVoicePhase.paused) {
      _log.w('Cannot resume: session not paused');
      return;
    }

    _client.sendStoryResume();
    _log.i('Requesting story session resume');
  }

  /// Request device takeover for the current session.
  Future<void> requestDeviceTakeover() async {
    final session = state.storySession;
    if (session == null || !session.isValid) {
      _log.w('Cannot request takeover: no active session');
      return;
    }

    final deviceId = await DeviceIdService.getDeviceId();
    _client.sendDeviceTakeover(
      sessionId: session.sessionId,
      deviceType: _deviceType,
      deviceId: deviceId,
    );
    _log.i('Requesting device takeover');
  }

  /// Leave the current story room.
  void leaveRoom() {
    if (state.roomState == null) {
      _log.w('Cannot leave room: not in a room');
      return;
    }

    _client.sendLeaveRoom();
    _log.i('Leaving story room');
  }

  /// End the current story session and disconnect.
  Future<void> endStorySession() async {
    await cancelRecording();
    state = state.copyWith(
      isStoryMode: false,
      clearStorySession: true,
      phase: RealtimeVoicePhase.idle,
      conversationHistory: [],
    );
    _log.i('Story session ended');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Recording (works in both story and non-story modes)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Start recording user voice and streaming it to the realtime endpoint.
  Future<void> startRecording() async {
    try {
      if (state.isBusy) {
        _log.w('Cannot start recording: already busy');
        return;
      }

      // In story mode, ensure we have a ready session
      if (state.isStoryMode && !state.isSessionReady) {
        _log.w('Cannot start recording: story session not ready');
        state = state.copyWith(
          errorMessage: 'Story session not ready. Please wait.',
        );
        return;
      }

      final hasPermission = await _ensureMicrophonePermission();
      if (!hasPermission) return;

      _enableAudio();
      _aiTextBuffer.clear();
      _commitSent = false;
      _resetAudioBuffer();

      state = state.copyWith(
        isRecording: false,
        isConnecting: !state.isStoryMode,
        isProcessing: false,
        isPlaying: false,
        aiResponse: null,
        userTranscription: null,
        clearAiAudio: true,
        errorMessage: null,
        clearFace: true,
        phase: state.isStoryMode ? RealtimeVoicePhase.recording : state.phase,
      );

      // Only connect if not in story mode (story mode already connected)
      if (!state.isStoryMode) {
        await _connectSocket();
      }

      await _startRecorder();
      _log.i('Voice recording started');
    } catch (e, st) {
      _log.e('Failed to start recording', error: e, stackTrace: st);
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        phase: state.isStoryMode ? RealtimeVoicePhase.error : state.phase,
        errorMessage: '$e',
      );
      if (!state.isStoryMode) {
        await _teardownSocket();
      }
    }
  }

  Future<void> _connectSocket({String? storySessionId}) async {
    final uri = await _voiceUri();
    if (uri == null) {
      throw VoiceChatException('Voice websocket URL is missing or invalid');
    }

    await _teardownSocket();

    // Get auth token for story sessions
    String? token;
    if (state.isStoryMode || storySessionId != null) {
      final authState = ref.read(authControllerProvider);
      token = authState.value != null
          ? ref.read(authControllerProvider.notifier).tokens?.accessToken
          : null;
    }

    final config = RealtimeVoiceConfig(
      token: token,
      storySessionId: storySessionId ?? _pendingStorySessionId,
    );

    _log.i('Connecting to realtime voice socket $uri');
    await _client.connect(uri, config: config);
    _socketOpen = true;
    _socketSub = _client.messages.listen(
      _handleIncomingMessage,
      onError: (err, st) => unawaited(
        _handleSocketError(err, st is StackTrace ? st : null),
      ),
      onDone: _handleSocketClosed,
      cancelOnError: true,
    );
  }

  Future<Uri?> _voiceUri() async {
    if (_voiceUriOverride != null) return _voiceUriOverride;
    await AppEnv.load();
    final raw = AppEnv.voiceRealtimeWsUrl.trim();
    if (raw.isEmpty) return null;
    Uri? uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return null;
    }
    if (uri.scheme == 'https') uri = uri.replace(scheme: 'wss');
    if (uri.scheme == 'http') uri = uri.replace(scheme: 'ws');
    if (uri.hasFragment) uri = uri.replace(fragment: '');
    return uri;
  }

  Future<void> _startRecorder() async {
    try {
      await _stopRecorder();
      _recorder ??= FlutterSoundRecorder();
      if (!_recorder!.isRecording) {
        await _recorder!.openRecorder();
      }

      await _micStreamSubscription?.cancel();
      await _micStreamController?.close();
      _micStreamController = StreamController<Uint8List>();
      _micStreamSubscription = _micStreamController!.stream.listen(
        _handleMicChunk,
        onError: (err, st) => unawaited(
          _handleSocketError(err, st is StackTrace ? st : null),
        ),
      );

      await _recorder!.startRecorder(
        toStream: _micStreamController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: _sampleRate,
        bitRate: _sampleRate * 16,
      );

      state = state.copyWith(
        isRecording: true,
        isConnecting: false,
        isProcessing: false,
        isPlaying: false,
        errorMessage: null,
        phase: state.isStoryMode ? RealtimeVoicePhase.recording : state.phase,
      );
    } catch (e, st) {
      _log.e('Failed to start streaming recorder', error: e, stackTrace: st);
      await _stopRecorder();
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        clearFace: true,
        phase: state.isStoryMode ? RealtimeVoicePhase.error : state.phase,
        errorMessage: 'Failed to start recording: $e',
      );
      if (!state.isStoryMode) {
        await _teardownSocket();
      }
    }
  }

  void _handleMicChunk(Uint8List bytes) {
    if (bytes.isEmpty) return;
    final rms = _computeRms(bytes);
    _emitMicLevelValue(rms);

    // Silence detection: if audio level is below threshold, start/continue silence timer
    if (rms < _silenceThreshold) {
      _startSilenceTimer();
    } else {
      _cancelSilenceTimer();
    }

    if (!_socketOpen) return;
    _audioBuffer.add(bytes);

    // Use the new audio append method for story mode
    if (state.isStoryMode) {
      final encoded = base64Encode(bytes);
      _client.sendAudioAppend(encoded, sampleRate: _sampleRate);
    } else {
      final encoded = base64Encode(bytes);
      _client.send({
        'type': 'input_audio_buffer.append',
        'audio': encoded,
      });
    }
  }

  void _startSilenceTimer() {
    // Only start if not already running
    if (_silenceTimer != null && _silenceTimer!.isActive) return;
    _silenceTimer = Timer(_silenceDuration, () {
      if (state.isRecording) {
        _log.i(
            'Silence detected for $_silenceDuration, auto-stopping recording');
        stopRecordingAndSend();
      }
    });
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// Stop recording and tell backend the input is finished.
  Future<void> stopRecordingAndSend() async {
    try {
      if (!ref.mounted) return;
      if (!state.isRecording) {
        _log.w('Cannot stop recording: not recording');
        return;
      }

      await _stopRecorder();
      _commitInput();

      // In story mode, just commit - server handles response
      // In non-story mode, create response from audio
      if (!state.isStoryMode) {
        await _createResponseFromAudio();
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        isRecording: false,
        isProcessing: true,
        isPlaying: false,
        isConnecting: false,
        errorMessage: null,
        phase: state.isStoryMode ? RealtimeVoicePhase.processing : state.phase,
      );
    } catch (e, st) {
      _log.e('Failed to stop recording', error: e, stackTrace: st);
      if (!ref.mounted) return;
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        clearAiAudio: true,
        clearFace: true,
        phase: state.isStoryMode ? RealtimeVoicePhase.error : state.phase,
        errorMessage: 'Failed to process voice: $e',
      );
      if (!state.isStoryMode) {
        await _teardownSocket();
      }
    }
  }

  Future<void> _stopRecorder() async {
    _cancelSilenceTimer();
    try {
      await _recorder?.stopRecorder();
    } catch (_) {}
    await _micStreamSubscription?.cancel();
    _micStreamSubscription = null;
    await _micStreamController?.close();
    _micStreamController = null;
    _emitMicLevelValue(0.0);
  }

  void _emitMicLevelValue(double value) {
    final controller = _micLevelController;
    if (controller == null || controller.isClosed) return;
    controller.add(value);
  }

  /// Queue RMS values from audio chunks for synchronized playback animation.
  void _queueAiAudioLevel(Uint8List bytes) {
    if (bytes.isEmpty) return;

    const segmentBytes = 2400;

    for (var offset = 0; offset < bytes.length; offset += segmentBytes) {
      final end = (offset + segmentBytes).clamp(0, bytes.length);
      final segment = Uint8List.sublistView(bytes, offset, end);
      final rms = _computeRms(segment);
      _pendingAiRmsValues.add(rms);
    }

    _startAiAudioLevelTimer();
  }

  void _startAiAudioLevelTimer() {
    if (_aiAudioLevelTimer != null && _aiAudioLevelTimer!.isActive) return;

    _aiAudioLevelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_pendingAiRmsValues.isEmpty) {
        _stopAiAudioLevelTimer();
        _emitAiAudioLevelValue(0.0);
        return;
      }

      final rms = _pendingAiRmsValues.removeAt(0);
      _emitAiAudioLevelValue(rms);
    });
  }

  void _stopAiAudioLevelTimer() {
    _aiAudioLevelTimer?.cancel();
    _aiAudioLevelTimer = null;
    _pendingAiRmsValues.clear();
  }

  void _emitAiAudioLevelValue(double value) {
    final controller = _aiAudioLevelController;
    if (controller == null || controller.isClosed) return;
    controller.add(value);
  }

  double _computeRms(Uint8List buffer) {
    final sampleCount = buffer.lengthInBytes ~/ 2;
    if (sampleCount == 0) return 0.0;

    // Ensure buffer is properly aligned for Int16 access
    // On some Android devices, the buffer offset may not be 2-byte aligned
    final Int16List samples;
    if (buffer.offsetInBytes % 2 == 0) {
      // Buffer is aligned, use directly
      samples = buffer.buffer.asInt16List(
        buffer.offsetInBytes,
        sampleCount,
      );
    } else {
      // Buffer is not aligned, copy to aligned buffer
      final alignedBuffer = Uint8List(buffer.length);
      alignedBuffer.setAll(0, buffer);
      samples = alignedBuffer.buffer.asInt16List(0, sampleCount);
    }

    double sumSquares = 0.0;
    for (final sample in samples) {
      final normalized = sample / 32768.0;
      sumSquares += normalized * normalized;
    }
    return math.sqrt(sumSquares / samples.length);
  }

  void _commitInput() {
    if (_commitSent || !_socketOpen) return;

    // Backend requires at least 100ms of audio before commit
    // At 24kHz, 16-bit mono: 100ms = 2400 samples * 2 bytes = 4800 bytes
    const minAudioBytes = 4800;
    final bufferLength = _audioBuffer.length;
    if (bufferLength < minAudioBytes) {
      _log.w('[CommitInput] Audio buffer too small: $bufferLength bytes (min: $minAudioBytes). Skipping commit.');
      return;
    }

    _log.i('[CommitInput] Committing audio buffer: $bufferLength bytes');
    if (state.isStoryMode) {
      _client.sendAudioCommit();
    } else {
      _client.send({'type': 'input_audio_buffer.commit'});
    }
    _commitSent = true;
  }

  Future<void> _createResponseFromAudio() async {
    if (!_socketOpen) return;
    final recordedBytes = _audioBuffer.takeBytes();
    if (recordedBytes.isEmpty) return;
    final encoded = base64Encode(recordedBytes);
    try {
      _log.i(
        'Sending response.create with ${recordedBytes.length} bytes of audio',
      );
      _client.send({
        'type': 'response.create',
        'response': {
          'modalities': ['text', 'audio'],
          'output_audio_format': _outputAudioFormat,
          'voice': _outputVoice,
          'input': [
            {
              'type': 'message',
              'role': 'user',
              'content': [
                {
                  'type': 'input_audio',
                  'audio': encoded,
                },
              ],
            },
          ],
        },
      });
      _resetAudioBuffer();
    } catch (e, st) {
      _log.e('Failed to send audio response.create', error: e, stackTrace: st);
      state = state.copyWith(errorMessage: 'Failed to send audio: $e');
    }
  }

  void _handleIncomingMessage(RealtimeIncomingMessage message) {
    if (!ref.mounted) return;
    if (message.isBinary && message.bytes != null) {
      unawaited(_handleAudioBytes(message.bytes!));
      return;
    }

    final payload = message.json;
    if (payload == null) return;
    final type = message.type;
    final typeStr = (payload['type'] as String?) ?? '';
    _log.t('Voice socket message type=$typeStr');

    switch (type) {
      // Story-specific messages
      case RealtimeServerMessageType.storySessionReady:
        _log.i('[IncomingMessage] >>> story_session_ready received! <<<');
        _handleStorySessionReady(payload);
        break;
      case RealtimeServerMessageType.storyStarted:
        _handleStoryStarted(payload);
        break;
      case RealtimeServerMessageType.storyResponse:
        _handleStoryResponse(payload);
        break;
      case RealtimeServerMessageType.takeoverGranted:
        _handleTakeoverResult(payload, true);
        break;
      case RealtimeServerMessageType.takeoverDenied:
        _handleTakeoverResult(payload, false);
        break;
      case RealtimeServerMessageType.roomJoined:
        _handleRoomJoined(payload);
        break;
      case RealtimeServerMessageType.storyResumed:
        _log.i('[IncomingMessage] story_resumed received');
        _handleStoryStarted(payload); // Same handling as story_started
        break;
      case RealtimeServerMessageType.storyAck:
        _log.i('[IncomingMessage] story_ack received: $payload');
        break;

      // OpenAI session messages - use session.updated as fallback for ready state
      case RealtimeServerMessageType.sessionCreated:
        _log.i('[IncomingMessage] session.created received');
        break;
      case RealtimeServerMessageType.sessionUpdated:
        _log.i('[IncomingMessage] session.updated received - transitioning to ready');
        // If we're waiting for ready and receive session.updated, treat it as ready
        // This is a fallback in case story_session_ready is not sent by the backend
        if (state.isStoryMode && state.phase == RealtimeVoicePhase.waitingForReady) {
          _log.i('[IncomingMessage] Using session.updated as ready signal');
          state = state.copyWith(
            phase: RealtimeVoicePhase.ready,
            isConnecting: false,
            isProcessing: false,
            errorMessage: null,
          );
        }
        break;

      case RealtimeServerMessageType.conversationItemCreate:
        _handleConversationItem(payload);
        break;
      case RealtimeServerMessageType.inputAudioTranscriptionCompleted:
        _handleUserTranscription(payload);
        break;

      // Audio/transcript messages
      case RealtimeServerMessageType.responseCreated:
        state = state.copyWith(isProcessing: true, isConnecting: false);
        break;
      case RealtimeServerMessageType.responseAudio:
      case RealtimeServerMessageType.responseAudioDelta:
      case RealtimeServerMessageType.responseOutputAudio:
      case RealtimeServerMessageType.responseOutputAudioDelta:
      case RealtimeServerMessageType.outputAudioDelta:
        final audio = _firstString([payload['audio'], payload['delta']]);
        if (audio != null && audio.isNotEmpty) {
          _log.t('Voice audio payload length=${audio.length}');
          unawaited(_handleAudioDelta(audio));
        } else {
          _log.w('Audio event without audio field: $payload');
        }
        final extras = _extractAudioStrings(payload);
        for (final extra in extras) {
          unawaited(_handleAudioDelta(extra));
        }
        break;
      case RealtimeServerMessageType.responseAudioTranscriptDelta:
        final text = (payload['delta'] ?? payload['text'] ?? '') as String;
        if (text.isNotEmpty) {
          _aiTextBuffer.write(text);
          state = state.copyWith(aiResponse: _aiTextBuffer.toString());
        }
        state = state.copyWith(
          isProcessing: false,
          isConnecting: false,
          phase: state.isStoryMode ? RealtimeVoicePhase.playing : state.phase,
        );
        break;
      case RealtimeServerMessageType.responseAudioTranscriptDone:
      case RealtimeServerMessageType.responseTextDone:
        final text = (payload['text'] ?? payload['transcript'] ?? '') as String;
        if (text.isNotEmpty) {
          _aiTextBuffer.clear();
          _aiTextBuffer.write(text);
          state = state.copyWith(aiResponse: text);
        }
        break;
      case RealtimeServerMessageType.responseTextDelta:
        final text = payload['text'] as String? ?? '';
        if (text.isNotEmpty) {
          _aiTextBuffer.write(text);
          state = state.copyWith(aiResponse: _aiTextBuffer.toString());
        }
        state = state.copyWith(isProcessing: false, isConnecting: false);
        break;
      case RealtimeServerMessageType.responseDone:
        state = state.copyWith(
          isProcessing: false,
          isConnecting: false,
          phase: state.isStoryMode ? RealtimeVoicePhase.ready : state.phase,
        );
        _commitSent = false;
        break;
      case RealtimeServerMessageType.responseError:
      case RealtimeServerMessageType.error:
        _handleErrorMessage(payload);
        break;
      case RealtimeServerMessageType.unknown:
        // Handle backward compatibility and extract any audio
        final extras = _extractAudioStrings(payload);
        if (extras.isNotEmpty) {
          for (final extra in extras) {
            unawaited(_handleAudioDelta(extra));
          }
        }
        // Also check for output_text.delta backward compatibility
        if (typeStr == 'response.output_text.delta') {
          final text = payload['text'] as String? ?? '';
          if (text.isNotEmpty) {
            _aiTextBuffer.write(text);
            state = state.copyWith(aiResponse: _aiTextBuffer.toString());
          }
          state = state.copyWith(isProcessing: false, isConnecting: false);
        }
        break;
    }
  }

  void _handleStorySessionReady(Map<String, dynamic> payload) {
    _log.i('Story session ready');
    final sessionInfo = StorySessionInfo.fromJson(payload);
    state = state.copyWith(
      phase: RealtimeVoicePhase.ready,
      isConnecting: false,
      isProcessing: false,
      storySession: sessionInfo.isValid ? sessionInfo : state.storySession,
      errorMessage: null,
    );
  }

  void _handleStoryStarted(Map<String, dynamic> payload) {
    _log.i('Story started: $payload');
    final sessionInfo = StorySessionInfo.fromJson(payload);
    final roomData = payload['room'] as Map<String, dynamic>?;
    RoomState? roomState;
    if (roomData != null) {
      roomState = RoomState.fromJson(roomData);
    }
    state = state.copyWith(
      storySession: sessionInfo,
      roomState: roomState,
      // Don't set ready yet - wait for story_session_ready
    );
  }

  void _handleStoryResponse(Map<String, dynamic> payload) {
    _log.i('Story response: $payload');
    final action = payload['action'] as String?;
    if (action == 'paused') {
      state = state.copyWith(phase: RealtimeVoicePhase.paused);
    } else if (action == 'resumed') {
      state = state.copyWith(phase: RealtimeVoicePhase.ready);
    }
  }

  void _handleTakeoverResult(Map<String, dynamic> payload, bool granted) {
    _log.i('Device takeover ${granted ? 'granted' : 'denied'}: $payload');
    if (granted) {
      state = state.copyWith(
        phase: RealtimeVoicePhase.ready,
        errorMessage: null,
      );
    } else {
      final reason = payload['reason'] as String? ?? 'Takeover denied';
      state = state.copyWith(errorMessage: reason);
    }
  }

  void _handleRoomJoined(Map<String, dynamic> payload) {
    _log.i('Room joined: $payload');
    final roomState = RoomState.fromJson(payload);
    state = state.copyWith(roomState: roomState);
  }

  void _handleConversationItem(Map<String, dynamic> payload) {
    _log.i('Conversation item: $payload');
    final item = ConversationItem.fromJson(payload);
    final history = [...state.conversationHistory, item];
    state = state.copyWith(conversationHistory: history);
  }

  void _handleUserTranscription(Map<String, dynamic> payload) {
    // Handle conversation.item.input_audio_transcription.completed
    // This contains the user's transcribed speech
    final transcript = payload['transcript'] as String? ?? '';
    _log.i('[UserTranscription] User said: $transcript');
    if (transcript.isNotEmpty) {
      state = state.copyWith(userTranscription: transcript);
    }
  }

  void _handleErrorMessage(Map<String, dynamic> payload) {
    final error = RealtimeVoiceError.fromJson(payload);
    _log.w('Voice socket error: ${error.code} - ${error.message}');

    // Check for story-specific errors
    if (error.isStoryContextRequired || error.isStorySessionRequired) {
      state = state.copyWith(
        isProcessing: false,
        isConnecting: false,
        isPlaying: false,
        isRecording: false,
        clearFace: true,
        phase: RealtimeVoicePhase.error,
        errorMessage: 'Story session required. Please start a story first.',
      );
      return;
    }

    state = state.copyWith(
      isProcessing: false,
      isConnecting: false,
      isPlaying: false,
      isRecording: false,
      clearFace: true,
      phase: state.isStoryMode ? RealtimeVoicePhase.error : state.phase,
      errorMessage: error.message,
    );
  }

  Future<void> _handleAudioDelta(String base64Audio) async {
    if (!ref.mounted) return;
    if (!_audioEnabled) return;
    try {
      final normalized = base64.normalize(base64Audio);
      final bytes = base64Decode(normalized);
      if (bytes.isEmpty) return;
      _log.t('Decoded audio delta ${bytes.length} bytes');

      _queueAiAudioLevel(bytes);

      await _player.addChunk(
        bytes,
        sampleRate: _sampleRate,
        onFinished: _handlePlaybackComplete,
      );
      state = state.copyWith(
        isPlaying: true,
        isProcessing: false,
        isConnecting: false,
        errorMessage: null,
        phase: state.isStoryMode ? RealtimeVoicePhase.playing : state.phase,
      );
    } catch (e, st) {
      _log.e('Playback error', error: e, stackTrace: st);
      _stopAiAudioLevelTimer();
      _emitAiAudioLevelValue(0.0);
      state = state.copyWith(
        isPlaying: false,
        isProcessing: false,
        isConnecting: false,
        currentExpression: RobotExpression.neutral,
        clearFace: true,
        errorMessage: 'Failed to play audio: $e',
      );
    }
  }

  Future<void> _handleAudioBytes(Uint8List bytes) async {
    if (!ref.mounted) return;
    if (!_audioEnabled) return;
    try {
      if (bytes.isEmpty) return;
      _log.t('Received binary audio ${bytes.length} bytes');

      _queueAiAudioLevel(bytes);

      await _player.addChunk(
        bytes,
        sampleRate: _sampleRate,
        onFinished: _handlePlaybackComplete,
      );
      state = state.copyWith(
        isPlaying: true,
        isProcessing: false,
        isConnecting: false,
        errorMessage: null,
        phase: state.isStoryMode ? RealtimeVoicePhase.playing : state.phase,
      );
    } catch (e, st) {
      _log.e('Playback error', error: e, stackTrace: st);
      _stopAiAudioLevelTimer();
      _emitAiAudioLevelValue(0.0);
      state = state.copyWith(
        isPlaying: false,
        isProcessing: false,
        isConnecting: false,
        currentExpression: RobotExpression.neutral,
        clearFace: true,
        errorMessage: 'Failed to play audio: $e',
      );
    }
  }

  void _handlePlaybackComplete() {
    unawaited(_player.stop());
    if (!ref.mounted) return;
    _disableAudio();
    _stopAiAudioLevelTimer();
    _emitAiAudioLevelValue(0.0);
    state = state.copyWith(
      isPlaying: false,
      isProcessing: false,
      currentExpression: RobotExpression.neutral,
      clearFace: true,
      phase: state.isStoryMode ? RealtimeVoicePhase.ready : state.phase,
    );
  }

  List<String> _extractAudioStrings(Map<String, dynamic> payload) {
    final results = <String>[];
    void take(dynamic value) {
      if (value is String && value.isNotEmpty) {
        results.add(value);
      }
    }

    take(payload['audio']);
    final output = payload['output'];
    if (output is List) {
      for (final item in output) {
        if (item is Map<String, dynamic>) {
          take(item['audio']);
          final content = item['content'];
          if (content is List) {
            for (final part in content) {
              if (part is Map<String, dynamic>) take(part['audio']);
            }
          }
        }
      }
    }
    final content = payload['content'];
    if (content is List) {
      for (final part in content) {
        if (part is Map<String, dynamic>) take(part['audio']);
      }
    }
    return results;
  }

  String? _firstString(Iterable<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Send a text prompt over the realtime socket using response.create.
  Future<void> sendTextPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    try {
      if (!_client.isOpen || !_socketOpen) {
        await _connectSocket();
      }

      _enableAudio();
      _aiTextBuffer.clear();
      state = state.copyWith(
        isProcessing: true,
        isConnecting: false,
        isRecording: false,
        isPlaying: false,
        aiResponse: null,
        errorMessage: null,
        clearFace: true,
        phase: state.isStoryMode ? RealtimeVoicePhase.processing : state.phase,
      );

      _client.send({
        'type': 'response.create',
        'response': {
          'modalities': ['text', 'audio'],
          'output_audio_format': _outputAudioFormat,
          'voice': _outputVoice,
          'input': [
            {
              'type': 'message',
              'role': 'user',
              'content': [
                {
                  'type': 'input_text',
                  'text': trimmed,
                }
              ],
            }
          ],
        },
      });
    } catch (e, st) {
      _log.e('Failed to send text prompt', error: e, stackTrace: st);
      state = state.copyWith(
        isProcessing: false,
        isConnecting: false,
        phase: state.isStoryMode ? RealtimeVoicePhase.error : state.phase,
        errorMessage: 'Failed to send prompt: $e',
      );
      if (!state.isStoryMode) {
        await _teardownSocket();
      }
    }
  }

  Future<void> _handleSocketError(Object err, [StackTrace? st]) async {
    if (!ref.mounted) return;
    _log.e('Voice websocket error', error: err, stackTrace: st);
    _disableAudio();
    _stopAiAudioLevelTimer();
    _emitAiAudioLevelValue(0.0);
    state = state.copyWith(
      isProcessing: false,
      isConnecting: false,
      isPlaying: false,
      isRecording: false,
      clearFace: true,
      phase: RealtimeVoicePhase.error,
      errorMessage: '$err',
    );
    _commitSent = false;
    _resetAudioBuffer();
    await _teardownSocket();
  }

  void _handleSocketClosed() {
    if (!ref.mounted) return;
    _log.i('Voice websocket closed');
    _socketOpen = false;
    unawaited(_player.stop());
    _disableAudio();
    _stopAiAudioLevelTimer();
    _emitAiAudioLevelValue(0.0);
    _socketSub = null;
    state = state.copyWith(
      isConnecting: false,
      isProcessing: false,
      isPlaying: false,
      isRecording: false,
      phase: RealtimeVoicePhase.closed,
    );
    _commitSent = false;
  }

  /// Cancel current recording and tear down the current session.
  Future<void> cancelRecording() async {
    _disableAudio();
    _stopAiAudioLevelTimer();
    _emitAiAudioLevelValue(0.0);
    await _stopRecorder();
    await _player.stop();
    await _teardownSocket();
    _aiTextBuffer.clear();
    _commitSent = false;
    _resetAudioBuffer();
    _pendingStorySessionId = null;
    state = state.copyWith(
      isRecording: false,
      isProcessing: false,
      isConnecting: false,
      isPlaying: false,
      aiResponse: null,
      userTranscription: null,
      clearAiAudio: true,
      clearFace: true,
      errorMessage: null,
      phase: RealtimeVoicePhase.idle,
      isStoryMode: false,
      clearStorySession: true,
    );
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    _disableAudio();
    _stopAiAudioLevelTimer();
    _emitAiAudioLevelValue(0.0);
    await _player.stop();

    // In story mode, don't tear down socket
    if (!state.isStoryMode) {
      await _teardownSocket();
    }

    _resetAudioBuffer();
    state = state.copyWith(
      isPlaying: false,
      isProcessing: false,
      isConnecting: false,
      currentExpression: RobotExpression.neutral,
      clearFace: true,
      phase: state.isStoryMode ? RealtimeVoicePhase.ready : state.phase,
    );
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<bool> _ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    _log.i('Current microphone permission status: $status');

    if (_isMicrophonePermissionUsable(status)) {
      _handleMicrophonePermissionGranted();
      return true;
    }

    if (_shouldOpenMicrophoneSettings(status)) {
      await _showSettingsDialog();
      _setPermissionError();
      return false;
    }

    if (status.isDenied) {
      final proceed = await _showEducationDialogAndWait();
      if (!proceed) {
        _setPermissionError();
        return false;
      }
    }

    status = await Permission.microphone.request();
    _log.i('Microphone permission request result: $status');

    if (_isMicrophonePermissionUsable(status)) {
      _handleMicrophonePermissionGranted();
      return true;
    }

    if (_isIOS && status.isDenied) {
      _iosPermissionDeniedOnce = true;
    }

    await _showSettingsDialog();
    _setPermissionError();
    return false;
  }

  Future<bool> _showEducationDialogAndWait() async {
    if (_permissionDialogCompleter != null &&
        !_permissionDialogCompleter!.isCompleted) {
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

  bool _isMicrophonePermissionUsable(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  bool get _isIOS => Platform.isIOS;

  void _handleMicrophonePermissionGranted() {
    _resetPermissionDialogState();
    _iosPermissionDeniedOnce = false;
    state = state.copyWith(errorMessage: null);
  }

  void handleEducationDialogResult(bool accepted) {
    if (_permissionDialogCompleter != null &&
        !_permissionDialogCompleter!.isCompleted) {
      _permissionDialogCompleter!.complete(accepted);
    }
    _permissionDialogCompleter = null;
    _resetPermissionDialogState();
  }

  void dismissPermissionDialog() {
    if (_permissionDialogCompleter != null &&
        !_permissionDialogCompleter!.isCompleted) {
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

  Future<void> _teardownSocket() async {
    _socketOpen = false;
    await _socketSub?.cancel();
    _socketSub = null;
    await _client.close();
    _resetAudioBuffer();
  }

  void _resetAudioBuffer() {
    _audioBuffer = BytesBuilder(copy: false);
  }

  void _enableAudio() {
    _audioEnabled = true;
  }

  void _disableAudio() {
    _audioEnabled = false;
    unawaited(_player.stop());
  }
}

class VoiceChatException implements Exception {
  VoiceChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Provider for voice chat controller
final voiceChatControllerProvider =
    NotifierProvider.autoDispose<VoiceChatController, VoiceChatState>(
  VoiceChatController.new,
);
