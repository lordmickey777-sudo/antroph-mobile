import 'dart:async';
import 'dart:collection';
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
import '../../story/data/stories_cache.dart';
import '../../story/providers/story_providers.dart';
import '../../profile/providers/customization_controller.dart';
import '../models/expression_models.dart';
import '../models/realtime_voice_bridge_models.dart';
import 'package:audio_session/audio_session.dart';

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

  // Mute state for continuous listening mode
  final bool isMuted;

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
    this.isMuted = false,
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
    bool clearUserTranscription = false,
    bool clearAiResponse = false,
    RealtimeVoicePhase? phase,
    StorySessionInfo? storySession,
    RoomState? roomState,
    bool? isStoryMode,
    List<ConversationItem>? conversationHistory,
    bool clearStorySession = false,
    bool? isMuted,
  }) {
    return VoiceChatState(
      currentExpression: currentExpression ?? this.currentExpression,
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      isConnecting: isConnecting ?? this.isConnecting,
      isProcessing: isProcessing ?? this.isProcessing,
      userTranscription: clearUserTranscription
          ? null
          : (userTranscription ?? this.userTranscription),
      aiResponse: clearAiResponse ? null : (aiResponse ?? this.aiResponse),
      aiAudioBytes: clearAiAudio ? null : (aiAudioBytes ?? this.aiAudioBytes),
      errorMessage: errorMessage,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      permissionDialog: permissionDialog ?? this.permissionDialog,
      audioFormats: audioFormats ?? this.audioFormats,
      currentFaceBitmap: clearFace
          ? null
          : (currentFaceBitmap ?? this.currentFaceBitmap),
      faceTimestampMs: clearFace
          ? null
          : (faceTimestampMs ?? this.faceTimestampMs),
      phase: phase ?? this.phase,
      storySession: clearStorySession
          ? null
          : (storySession ?? this.storySession),
      roomState: roomState ?? this.roomState,
      isStoryMode: isStoryMode ?? this.isStoryMode,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      isMuted: isMuted ?? this.isMuted,
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
  AudioSession? _audioSession;
  _VoiceAudioSessionMode? _audioSessionMode;
  FlutterSoundRecorder? _recorder;
  StreamSubscription<RealtimeIncomingMessage>? _socketSub;
  StreamController<Uint8List>? _micStreamController;
  StreamSubscription<Uint8List>? _micStreamSubscription;
  StreamController<double>? _micLevelController;
  StreamController<double>? _aiAudioLevelController;
  StreamController<MascotExpressionEvent>? _mascotExpressionController;
  Timer? _aiAudioLevelTimer;
  Timer? _silenceTimer;
  Timer? _autoListenTimer;
  Timer? _maxRecordingTimer;
  Timer? _playbackIdleTimer;
  DateTime? _playbackExpectedEndAt;
  DateTime? _lastAiAudioAt;
  DateTime? _lastSpeechAt;
  DateTime? _lastMicLogAt;
  bool _hasSpeech = false;
  double _noiseFloor = 0.0;
  bool _responseDoneForCurrentTurn = false;
  bool _receivedAiAudioForCurrentTurn = false;
  bool _ignoreIncomingAudioUntilNextResponse = false;
  final Queue<_TimedRmsSample> _pendingAiRmsSamples = Queue<_TimedRmsSample>();
  final StringBuffer _aiTextBuffer = StringBuffer();
  BytesBuilder _audioBuffer = BytesBuilder(copy: false);
  Completer<bool>? _permissionDialogCompleter;
  bool _iosPermissionDeniedOnce = false;
  bool _commitSent = false;
  bool _socketOpen = false;
  bool _audioEnabled = true;
  String? _pendingStorySessionId;
  final Set<String> _syncedStorySessionIds = <String>{};

  static const int _sampleRate = 24000;
  static const String _outputAudioFormat = 'pcm16';
  static const String _defaultVoice = 'alloy';
  static const String _deviceType = 'mobile';
  static const String _permissionError =
      'Microphone permission is required for voice chat';
  static const double _speechThreshold = 0.02;
  static const double _noiseFloorMargin = 0.015;
  static const Duration _silenceDuration = Duration(seconds: 2);
  static const Duration _maxRecordingDuration = Duration(seconds: 12);

  VoiceChatController({
    RealtimeVoiceClient? client,
    AudioChunkPlayer? player,
    Uri? voiceUriOverride,
  }) : _client = client ?? RealtimeVoiceClient(),
       _player = player ?? createAudioChunkPlayer(),
       _voiceUriOverride = voiceUriOverride;

  Stream<double> get micLevelStream =>
      _micLevelController?.stream ?? Stream<double>.empty();

  Stream<double> get aiAudioLevelStream =>
      _aiAudioLevelController?.stream ?? Stream<double>.empty();

  Stream<MascotExpressionEvent> get mascotExpressionStream =>
      _mascotExpressionController?.stream ??
      Stream<MascotExpressionEvent>.empty();

  /// Gets the TTS voice from user's AI settings, or falls back to default.
  String get _outputVoice {
    final settings = ref.read(customizationControllerProvider).asData?.value;
    final voice = settings?.ttsVoice;
    if (voice != null && voice.isNotEmpty) {
      return voice;
    }
    return _defaultVoice;
  }

  @override
  VoiceChatState build() {
    _recorder = FlutterSoundRecorder();
    _micLevelController ??= StreamController<double>.broadcast();
    _aiAudioLevelController ??= StreamController<double>.broadcast();
    _mascotExpressionController ??=
        StreamController<MascotExpressionEvent>.broadcast();

    ref.onDispose(() async {
      _disableAudio();
      _cancelSilenceTimer();
      _cancelMaxRecordingTimer();
      _cancelAutoListenTimer();
      _cancelPlaybackIdleTimer();
      _stopAiAudioLevelTimer();
      await _stopRecorder();
      await _teardownSocket();
      await _player.dispose();
      await _micLevelController?.close();
      _micLevelController = null;
      await _aiAudioLevelController?.close();
      _aiAudioLevelController = null;
      await _mascotExpressionController?.close();
      _mascotExpressionController = null;
    });

    return const VoiceChatState();
  }

  Future<void> _configureAudioSession(_VoiceAudioSessionMode mode) async {
    if (_audioSessionMode == mode) return;
    try {
      _audioSession ??= await AudioSession.instance;
      final AudioSessionConfiguration config;
      if (mode == _VoiceAudioSessionMode.recording) {
        config = AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        );
      } else {
        config = AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        );
      }
      await _audioSession!.configure(config);
      await _audioSession!.setActive(true);
      _audioSessionMode = mode;
    } catch (err, st) {
      _log.w('Audio session configure failed', error: err, stackTrace: st);
    }
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
        clearAiResponse: true,
        clearUserTranscription: true,
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
        clearAiResponse: true,
        clearUserTranscription: true,
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
    if (!ref.mounted) return;
    _cancelAutoListenTimer();
    await cancelRecording();
    if (!ref.mounted) return;
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
      _hasSpeech = false;
      _noiseFloor = 0.0;

      state = state.copyWith(
        isRecording: false,
        isConnecting: !state.isStoryMode,
        isProcessing: false,
        isPlaying: false,
        clearAiResponse: true,
        clearUserTranscription: true,
        clearAiAudio: true,
        errorMessage: null,
        clearFace: true,
        phase: state.isStoryMode ? RealtimeVoicePhase.recording : state.phase,
      );

      // Only connect if not in story mode and socket not already open
      // (story mode already connected, and for continuous listening we reuse the socket)
      if (!state.isStoryMode && !_socketOpen) {
        await _connectSocket();
      }

      await _startRecorder();
      _startMaxRecordingTimer();
      _log.i('Voice recording started (storyMode=${state.isStoryMode})');
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
      onError: (err, st) =>
          unawaited(_handleSocketError(err, st is StackTrace ? st : null)),
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
      await _configureAudioSession(_VoiceAudioSessionMode.recording);
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
        onError: (err, st) =>
            unawaited(_handleSocketError(err, st is StackTrace ? st : null)),
      );

      await _recorder!.startRecorder(
        toStream: _micStreamController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: _sampleRate,
        bitRate: _sampleRate * 16,
      );

      _log.i(
        'Recorder started: codec=pcm16 sampleRate=$_sampleRate channels=1',
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

    final now = DateTime.now();
    final lastLog = _lastMicLogAt;
    if (lastLog == null ||
        now.difference(lastLog) >= const Duration(milliseconds: 500)) {
      _lastMicLogAt = now;
      _log.i(
        'Mic chunk: bytes=${bytes.length} rms=$rms noiseFloor=$_noiseFloor hasSpeech=$_hasSpeech',
      );
    }

    // Adapt to ambient noise so silence detection still works on noisy devices.
    if (!_hasSpeech) {
      if (_noiseFloor == 0.0) {
        _noiseFloor = rms;
      } else {
        _noiseFloor = (_noiseFloor * 0.95) + (rms * 0.05);
      }
    }

    final dynamicThreshold = math.max(
      _speechThreshold,
      _noiseFloor + _noiseFloorMargin,
    );

    if (rms >= dynamicThreshold) {
      _hasSpeech = true;
      _lastSpeechAt = DateTime.now();
      _cancelSilenceTimer();
      _log.i('Speech detected: rms=$rms threshold=$dynamicThreshold');
    } else {
      _startSilenceTimer();
    }

    if (!_socketOpen) return;
    _audioBuffer.add(bytes);

    // Use the new audio append method for story mode
    if (state.isStoryMode) {
      final encoded = base64Encode(bytes);
      _client.sendAudioAppend(encoded, sampleRate: _sampleRate);
    } else {
      final encoded = base64Encode(bytes);
      _client.send({'type': 'input_audio_buffer.append', 'audio': encoded});
    }
  }

  void _startSilenceTimer() {
    // Only start if not already running
    if (_silenceTimer != null && _silenceTimer!.isActive) return;
    _silenceTimer = Timer(_silenceDuration, () {
      if (state.isRecording) {
        final lastSpeechAt = _lastSpeechAt;
        final silenceFor = lastSpeechAt == null
            ? _silenceDuration
            : DateTime.now().difference(lastSpeechAt);
        if (silenceFor >= _silenceDuration) {
          _log.i(
            'Silence detected for $_silenceDuration, auto-stopping recording',
          );
          stopRecordingAndSend();
        } else {
          _log.i('Silence timer tick: silenceFor=$silenceFor');
          _startSilenceTimer();
        }
      }
    });
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void _startMaxRecordingTimer() {
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = Timer(_maxRecordingDuration, () {
      if (state.isRecording) {
        _log.i('Max recording duration reached, auto-stopping');
        stopRecordingAndSend();
      }
    });
  }

  void _cancelMaxRecordingTimer() {
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
  }

  /// Stop recording and tell backend the input is finished.
  Future<void> stopRecordingAndSend() async {
    try {
      if (!ref.mounted) return;
      if (!state.isRecording) {
        _log.w('Cannot stop recording: not recording');
        return;
      }

      _log.i('Stopping recording: committing input');
      _cancelMaxRecordingTimer();
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
    _cancelMaxRecordingTimer();
    _lastSpeechAt = null;
    _hasSpeech = false;
    _noiseFloor = 0.0;
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

    // 20ms chunks at 24kHz mono pcm16 keep facial updates responsive while
    // matching actual audio duration.
    const segmentBytes = 960;
    final bytesPerSecond = _sampleRate * 2; // pcm16 mono

    for (var offset = 0; offset < bytes.length; offset += segmentBytes) {
      final end = (offset + segmentBytes).clamp(0, bytes.length);
      final segment = Uint8List.sublistView(bytes, offset, end);
      final rms = _computeRms(segment);
      final segmentDurationMs = ((segment.length / bytesPerSecond) * 1000.0)
          .round()
          .clamp(1, 250);
      _pendingAiRmsSamples.add(
        _TimedRmsSample(rms: rms, durationMs: segmentDurationMs),
      );
    }

    _startAiAudioLevelTimer();
  }

  void _startAiAudioLevelTimer() {
    if (_aiAudioLevelTimer != null && _aiAudioLevelTimer!.isActive) return;
    _emitNextAiAudioLevelSample();
  }

  void _emitNextAiAudioLevelSample() {
    if (_pendingAiRmsSamples.isEmpty) {
      _stopAiAudioLevelTimer();
      _emitAiAudioLevelValue(0.0);
      return;
    }

    final sample = _pendingAiRmsSamples.removeFirst();
    _emitAiAudioLevelValue(sample.rms);
    _aiAudioLevelTimer = Timer(
      Duration(milliseconds: sample.durationMs),
      _emitNextAiAudioLevelSample,
    );
  }

  void _stopAiAudioLevelTimer() {
    _aiAudioLevelTimer?.cancel();
    _aiAudioLevelTimer = null;
    _pendingAiRmsSamples.clear();
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
      samples = buffer.buffer.asInt16List(buffer.offsetInBytes, sampleCount);
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
      _log.w(
        '[CommitInput] Audio buffer too small: $bufferLength bytes (min: $minAudioBytes). Skipping commit.',
      );
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
                {'type': 'input_audio', 'audio': encoded},
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
        _log.i(
          '[IncomingMessage] session.updated received - transitioning to ready',
        );
        // If we're waiting for ready and receive session.updated, treat it as ready
        // This is a fallback in case story_session_ready is not sent by the backend
        if (state.isStoryMode &&
            state.phase == RealtimeVoicePhase.waitingForReady) {
          _log.i('[IncomingMessage] Using session.updated as ready signal');
          final sessionInfo = state.storySession;
          state = state.copyWith(
            phase: RealtimeVoicePhase.ready,
            isConnecting: false,
            isProcessing: false,
            errorMessage: null,
          );
          if (sessionInfo != null) {
            unawaited(_syncStartedStoryState(sessionInfo));
          }
          _scheduleAutoListen();
        }
        break;

      case RealtimeServerMessageType.conversationHistoryFull:
        _handleConversationHistoryFull(payload);
        break;
      case RealtimeServerMessageType.conversationItemCreate:
        _handleConversationItem(payload);
        break;
      case RealtimeServerMessageType.inputAudioTranscriptionCompleted:
        _handleUserTranscription(payload);
        break;
      case RealtimeServerMessageType.mascotExpression:
        _handleMascotExpression(payload);
        break;

      // Audio/transcript messages
      case RealtimeServerMessageType.responseCreated:
        _ignoreIncomingAudioUntilNextResponse = false;
        _responseDoneForCurrentTurn = false;
        _receivedAiAudioForCurrentTurn = false;
        _lastAiAudioAt = null;
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
          if (extra == audio) continue;
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
        // Save completed turn into conversation history for display
        _saveCompletedTurn();
        _responseDoneForCurrentTurn = true;
        state = state.copyWith(
          isProcessing: false,
          isConnecting: false,
          phase: state.isStoryMode ? RealtimeVoicePhase.ready : state.phase,
        );
        _commitSent = false;
        if (_ignoreIncomingAudioUntilNextResponse) {
          break;
        }
        if (!state.isPlaying && !_receivedAiAudioForCurrentTurn) {
          _scheduleAutoListen();
        }
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
    unawaited(_syncStartedStoryState(sessionInfo));
    _scheduleAutoListen();
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

  Future<void> _syncStartedStoryState(StorySessionInfo sessionInfo) async {
    final sessionId = sessionInfo.sessionId.trim();
    final storyId = sessionInfo.storyId.trim();
    if (sessionId.isEmpty || storyId.isEmpty) return;
    if (!_syncedStorySessionIds.add(sessionId)) return;

    final user = ref.read(authControllerProvider).asData?.value;
    if (user == null) return;

    await StoriesCacheService.clear();
    if (!ref.mounted) return;

    ref.invalidate(continuePlayingProvider);
    ref.invalidate(storiesHomeSectionsProvider);
  }

  void _handleRoomJoined(Map<String, dynamic> payload) {
    _log.i('Room joined: $payload');
    final roomState = RoomState.fromJson(payload);
    state = state.copyWith(roomState: roomState);
  }

  void _handleConversationItem(Map<String, dynamic> payload) {
    _log.i('Conversation item: $payload');
    final item = ConversationItem.fromJson(payload);
    if (item.content.isEmpty) return;
    final history = [...state.conversationHistory, item];
    state = state.copyWith(conversationHistory: history);
  }

  void _handleMascotExpression(Map<String, dynamic> payload) {
    final event = MascotExpressionEvent.fromJson(payload);
    _log.d(
      'Mascot expression received: ${event.expression} '
      '(intensity=${event.intensity}, durationMs=${event.durationMs}, '
      'riveElementId=${event.riveElementId})',
    );
    _mascotExpressionController?.add(event);
  }

  /// Handle conversation.history.full from server.
  ///
  /// The backend sends a bounded window (currently up to 50 turns). We merge it
  /// with local history so the UI does not appear to "replace" older turns when
  /// sync updates arrive.
  void _handleConversationHistoryFull(Map<String, dynamic> payload) {
    final historyList = payload['history'] as List<dynamic>? ?? [];
    _log.i('Received full conversation history: ${historyList.length} turns');
    final items = <ConversationItem>[];
    for (final entry in historyList) {
      if (entry is! Map<String, dynamic>) continue;
      final speaker = entry['speaker'] as String? ?? '';
      final message = entry['message'] as String? ?? '';
      if (message.isEmpty) continue;
      // Backend uses "ai" for assistant role
      final role = speaker == 'ai' ? 'assistant' : speaker;
      items.add(ConversationItem(role: role, content: message));
    }
    final merged = _mergeConversationHistory(state.conversationHistory, items);
    state = state.copyWith(conversationHistory: merged);
  }

  List<ConversationItem> _mergeConversationHistory(
    List<ConversationItem> local,
    List<ConversationItem> incoming,
  ) {
    if (incoming.isEmpty) return local;
    if (local.isEmpty) return incoming;

    // If local already ends with incoming, incoming is a strict window/snapshot.
    if (_endsWithSequence(local, incoming)) {
      return local;
    }

    // Append only new tail items when incoming overlaps local suffix.
    final overlap = _maxSuffixPrefixOverlap(local, incoming);
    if (overlap > 0) {
      return [...local, ...incoming.sublist(overlap)];
    }

    // Never shrink on sync updates; shrinking looks like conversation reset.
    if (incoming.length < local.length) {
      return local;
    }

    // If incoming extends local, trust it.
    if (_endsWithSequence(incoming, local)) {
      return incoming;
    }

    // Fallback to incoming snapshot when histories diverge.
    return incoming;
  }

  int _maxSuffixPrefixOverlap(
    List<ConversationItem> local,
    List<ConversationItem> incoming,
  ) {
    final max = math.min(local.length, incoming.length);
    for (var size = max; size > 0; size--) {
      var matches = true;
      for (var i = 0; i < size; i++) {
        if (!_sameConversationItem(
          local[local.length - size + i],
          incoming[i],
        )) {
          matches = false;
          break;
        }
      }
      if (matches) return size;
    }
    return 0;
  }

  bool _endsWithSequence(
    List<ConversationItem> items,
    List<ConversationItem> suffix,
  ) {
    if (suffix.length > items.length) return false;
    final offset = items.length - suffix.length;
    for (var i = 0; i < suffix.length; i++) {
      if (!_sameConversationItem(items[offset + i], suffix[i])) {
        return false;
      }
    }
    return true;
  }

  bool _sameConversationItem(ConversationItem a, ConversationItem b) {
    return a.role == b.role && a.content == b.content;
  }

  /// Save the current turn's userTranscription and aiResponse into
  /// conversationHistory so the full chat history is visible in the UI.
  void _saveCompletedTurn() {
    final userText = state.userTranscription;
    final aiText = state.aiResponse;
    if (userText == null && aiText == null) return;
    if ((userText?.isEmpty ?? true) && (aiText?.isEmpty ?? true)) return;

    final history = [...state.conversationHistory];
    if (userText != null && userText.isNotEmpty) {
      // Avoid duplicate if server already sent this via conversation.item.create
      final alreadyHasUser =
          history.isNotEmpty &&
          history.last.isUser &&
          history.last.content == userText;
      if (!alreadyHasUser) {
        history.add(ConversationItem(role: 'user', content: userText));
      }
    }
    if (aiText != null && aiText.isNotEmpty) {
      final alreadyHasAi =
          history.isNotEmpty &&
          history.last.isAssistant &&
          history.last.content == aiText;
      if (!alreadyHasAi) {
        history.add(ConversationItem(role: 'assistant', content: aiText));
      }
    }
    state = state.copyWith(
      conversationHistory: history,
      clearUserTranscription: true,
      clearAiResponse: true,
    );
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

    final normalizedMessage = error.message.toLowerCase();
    final isBenignCancellationRace =
        normalizedMessage.contains('no active response found') ||
        normalizedMessage.contains('cancellation failed');
    if (isBenignCancellationRace) {
      _log.i('Ignoring benign cancellation race: ${error.message}');
      return;
    }

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
    if (_ignoreIncomingAudioUntilNextResponse) return;
    _cancelAutoListenTimer();
    try {
      final normalized = base64.normalize(base64Audio);
      final bytes = base64Decode(normalized);
      if (bytes.isEmpty) return;
      _log.t('Decoded audio delta ${bytes.length} bytes');
      _receivedAiAudioForCurrentTurn = true;
      _lastAiAudioAt = DateTime.now();
      _schedulePlaybackIdleStop(bytes.length);

      _queueAiAudioLevel(bytes);

      await _configureAudioSession(_VoiceAudioSessionMode.playback);
      await _player.addChunk(
        bytes,
        sampleRate: _sampleRate,
        onFinished: _handlePlaybackComplete,
      );
      if (!ref.mounted) return;
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
      if (!ref.mounted) return;
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
    if (_ignoreIncomingAudioUntilNextResponse) return;
    _cancelAutoListenTimer();
    try {
      if (bytes.isEmpty) return;
      _log.t('Received binary audio ${bytes.length} bytes');
      _receivedAiAudioForCurrentTurn = true;
      _lastAiAudioAt = DateTime.now();
      _schedulePlaybackIdleStop(bytes.length);

      _queueAiAudioLevel(bytes);

      await _configureAudioSession(_VoiceAudioSessionMode.playback);
      await _player.addChunk(
        bytes,
        sampleRate: _sampleRate,
        onFinished: _handlePlaybackComplete,
      );
      if (!ref.mounted) return;
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
      if (!ref.mounted) return;
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
    _cancelPlaybackIdleTimer();
    if (!ref.mounted) return;
    _responseDoneForCurrentTurn = false;
    _receivedAiAudioForCurrentTurn = false;
    _lastAiAudioAt = null;
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

    // Auto-listen after AI finishes speaking (both modes)
    _scheduleAutoListen();
  }

  /// Schedules auto-listening after a brief delay if enabled in settings.
  void _scheduleAutoListen() {
    _cancelAutoListenTimer();

    // Don't auto-listen if muted
    if (state.isMuted) {
      _log.i('Auto-listen skipped: muted');
      return;
    }

    // Check if auto-listen is enabled in user settings
    final settings = ref.read(customizationControllerProvider).asData?.value;
    final autoListenEnabled = settings?.autoListenAfterResponse ?? true;

    if (!autoListenEnabled && !state.isStoryMode) {
      _log.i('Auto-listen disabled in settings');
      return;
    }

    // Brief delay before auto-starting to feel natural
    final autoListenDelay = state.isStoryMode
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 800);
    _autoListenTimer = Timer(autoListenDelay, () {
      if (!ref.mounted) return;
      if (state.isMuted) return; // Check again after delay

      // Works for both story mode and regular mode
      final canAutoListen = state.isStoryMode
          ? (state.phase == RealtimeVoicePhase.ready && !state.isBusy)
          : (!state.isBusy);

      if (canAutoListen) {
        _log.i('Auto-starting recording after AI response');
        startRecording();
      }
    });
  }

  void _cancelAutoListenTimer() {
    _autoListenTimer?.cancel();
    _autoListenTimer = null;
  }

  void _schedulePlaybackIdleStop(int byteLength) {
    final bytesPerSecond = _sampleRate * 2; // pcm16 mono
    final chunkMs = (byteLength / bytesPerSecond) * 1000.0;
    final now = DateTime.now();
    final expected = _playbackExpectedEndAt;
    final baseTime = (expected == null || expected.isBefore(now))
        ? now
        : expected;
    final newExpected = baseTime.add(Duration(milliseconds: chunkMs.round()));
    _cancelPlaybackIdleTimer(keepExpected: true);
    _playbackExpectedEndAt = newExpected;
    final cushionMs = state.isStoryMode ? 200 : 300;
    final delay =
        newExpected.difference(now) + Duration(milliseconds: cushionMs);
    if (delay.isNegative) {
      _handlePlaybackIdleTimeout();
      return;
    }
    _playbackIdleTimer = Timer(delay, _handlePlaybackIdleTimeout);
  }

  void _handlePlaybackIdleTimeout() {
    // Temporary interruption guard: while a turn is still streaming (no
    // response.done yet), don't cut playback due to transport gaps.
    if (!_responseDoneForCurrentTurn) {
      final lastAudioAt = _lastAiAudioAt;
      if (lastAudioAt != null &&
          DateTime.now().difference(lastAudioAt) < const Duration(seconds: 6)) {
        _playbackIdleTimer = Timer(
          const Duration(milliseconds: 350),
          _handlePlaybackIdleTimeout,
        );
        return;
      }
    }
    _handlePlaybackComplete();
  }

  void _cancelPlaybackIdleTimer({bool keepExpected = false}) {
    _playbackIdleTimer?.cancel();
    _playbackIdleTimer = null;
    if (!keepExpected) {
      _playbackExpectedEndAt = null;
    }
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
  Future<void> sendTextPrompt(String prompt, {bool textOnly = false}) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    try {
      if (!_client.isOpen || !_socketOpen) {
        await _connectSocket();
      }

      if (!textOnly) _enableAudio();
      _aiTextBuffer.clear();
      state = state.copyWith(
        isProcessing: true,
        isConnecting: false,
        isRecording: false,
        isPlaying: false,
        clearAiResponse: true,
        errorMessage: null,
        clearFace: true,
        phase: state.isStoryMode ? RealtimeVoicePhase.processing : state.phase,
      );

      final modalities = textOnly ? ['text'] : ['text', 'audio'];
      final response = <String, dynamic>{
        'modalities': modalities,
        'input': [
          {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': trimmed},
            ],
          },
        ],
      };
      if (!textOnly) {
        response['output_audio_format'] = _outputAudioFormat;
        response['voice'] = _outputVoice;
      }

      _client.send({'type': 'response.create', 'response': response});

      // For text-only sends, push user message to history immediately
      // since _saveCompletedTurn relies on userTranscription (voice only).
      if (textOnly) {
        final history = [...state.conversationHistory];
        history.add(ConversationItem(role: 'user', content: trimmed));
        state = state.copyWith(conversationHistory: history);
      }
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
    if (!ref.mounted) return;
    _cancelAutoListenTimer();
    _cancelPlaybackIdleTimer();
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
    if (!ref.mounted) return;
    state = state.copyWith(
      isRecording: false,
      isProcessing: false,
      isConnecting: false,
      isPlaying: false,
      clearAiResponse: true,
      clearUserTranscription: true,
      clearAiAudio: true,
      clearFace: true,
      errorMessage: null,
      phase: RealtimeVoicePhase.idle,
      isStoryMode: false,
      clearStorySession: true,
    );
  }

  /// Stop audio playback and optionally return to listening immediately.
  Future<void> stopPlayback({bool restartListening = false}) async {
    _cancelAutoListenTimer();
    _cancelPlaybackIdleTimer();
    final shouldCancelActiveResponse =
        _socketOpen &&
        !_responseDoneForCurrentTurn &&
        (state.isProcessing || state.isPlaying || state.isConnecting);
    if (shouldCancelActiveResponse) {
      _client.send({'type': 'response.cancel'});
    }
    _ignoreIncomingAudioUntilNextResponse = true;
    _disableAudio();
    _stopAiAudioLevelTimer();
    _emitAiAudioLevelValue(0.0);
    await _player.stop();

    // In story mode, don't tear down socket
    if (!state.isStoryMode) {
      await _teardownSocket();
    }

    _resetAudioBuffer();
    _lastSpeechAt = null;
    final nextPhase = state.isStoryMode
        ? (state.isSessionReady ? RealtimeVoicePhase.ready : state.phase)
        : state.phase;
    state = state.copyWith(
      isPlaying: false,
      isProcessing: false,
      isConnecting: false,
      currentExpression: RobotExpression.neutral,
      clearFace: true,
      phase: nextPhase,
    );

    if (restartListening &&
        !state.isMuted &&
        (state.isSessionReady || !state.isStoryMode)) {
      await startRecording();
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Toggle mute state - when muted, auto-listen is disabled
  void toggleMute() {
    final newMuteState = !state.isMuted;
    _log.i('Toggling mute: ${state.isMuted} -> $newMuteState');

    if (newMuteState) {
      // Muting: stop recording, cancel auto-listen, but let AI continue
      _cancelAutoListenTimer();
      if (state.isRecording) {
        _stopRecorderOnly();
        state = state.copyWith(
          isMuted: true,
          isRecording: false,
          phase: state.isStoryMode ? RealtimeVoicePhase.ready : state.phase,
        );
      } else {
        state = state.copyWith(isMuted: true);
      }
    } else {
      // Unmuting: start listening if ready
      state = state.copyWith(isMuted: false);
      if (!state.isPlaying &&
          !state.isProcessing &&
          (state.isSessionReady || !state.isStoryMode)) {
        startRecording();
      }
    }
  }

  /// Stop recorder without sending (for mute)
  Future<void> _stopRecorderOnly() async {
    _cancelSilenceTimer();
    _lastSpeechAt = null;
    try {
      if (_recorder?.isRecording ?? false) {
        await _recorder?.stopRecorder();
      }
    } catch (e) {
      _log.e('Error stopping recorder', error: e);
    }
    await _micStreamSubscription?.cancel();
    _micStreamSubscription = null;
    await _micStreamController?.close();
    _micStreamController = null;
    _emitMicLevelValue(0.0);
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
    _ignoreIncomingAudioUntilNextResponse = false;
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
    _cancelPlaybackIdleTimer();
    unawaited(_player.stop());
  }
}

enum _VoiceAudioSessionMode { recording, playback }

class _TimedRmsSample {
  const _TimedRmsSample({required this.rms, required this.durationMs});

  final double rms;
  final int durationMs;
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
