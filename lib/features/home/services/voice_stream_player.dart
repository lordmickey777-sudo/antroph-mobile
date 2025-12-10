import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

/// Lightweight audio streamer that feeds decoded chunks into just_audio.
class VoiceStreamPlayer {
  final _log = Logger();
  AudioPlayer? _player;
  StreamController<List<int>>? _controller;
  StreamSubscription<PlayerState>? _stateSub;
  Future<void>? _setupFuture;
  VoidCallback? _onComplete;
  void Function(Object, StackTrace)? _onError;
  String _contentType = 'audio/mpeg';
  bool _sessionConfigured = false;

  bool get isPlaying => _player?.playing ?? false;
  bool get hasStream => _controller != null && (_controller?.isClosed == false);

  Future<void> start({
    String contentType = 'audio/mpeg',
    VoidCallback? onComplete,
    void Function(Object, StackTrace)? onError,
  }) async {
    await stop();
    await _ensureSession();
    _contentType = contentType;
    _onComplete = onComplete;
    _onError = onError;
    _controller = StreamController<List<int>>();
    _player = AudioPlayer();
    _stateSub = _player!.playerStateStream.listen(
      (state) {
        if (state.processingState == ProcessingState.completed) {
          _onComplete?.call();
        }
      },
      onError: (Object err, StackTrace st) {
        _log.e('Audio player stream error', error: err, stackTrace: st);
        _onError?.call(err, st);
      },
    );
  }

  Future<void> addChunk(Uint8List bytes) async {
    if (_controller == null || _player == null) {
      await start(
        contentType: _contentType,
        onComplete: _onComplete,
        onError: _onError,
      );
    }
    if (_controller?.isClosed == true) return;
    _controller!.add(bytes);
    if (_setupFuture == null) {
      final source = _VoiceStreamAudioSource(
        _controller!.stream,
        contentType: _contentType,
      );
      _setupFuture = _player!
          .setAudioSource(source)
          .then((_) => _player!.play());
      _setupFuture!.catchError((Object err, StackTrace st) async {
        _log.e('Failed to start audio stream', error: err, stackTrace: st);
        _onError?.call(err, st);
        await stop(); // reset so we can retry with next chunks
      });
    }
  }

  Future<void> markComplete() async {
    try {
      await _controller?.close();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _controller?.close();
    } catch (_) {}
    await _stateSub?.cancel();
    _stateSub = null;
    if (_player != null) {
      try {
        await _player!.stop();
      } finally {
        await _player!.dispose();
      }
    }
    _player = null;
    _controller = null;
    _setupFuture = null;
  }

  Future<void> _ensureSession() async {
    if (_sessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _sessionConfigured = true;
    } catch (err, st) {
      _log.w('Audio session configure failed', error: err, stackTrace: st);
    }
  }
}

class _VoiceStreamAudioSource extends StreamAudioSource {
  _VoiceStreamAudioSource(this.stream, {required this.contentType});

  final Stream<List<int>> stream;
  final String contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: start ?? 0,
      stream: stream,
      contentType: contentType,
      rangeRequestsSupported: false,
    );
  }
}
