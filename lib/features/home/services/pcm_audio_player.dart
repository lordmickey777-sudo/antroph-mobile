import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// Interface for streaming PCM audio chunks.
abstract class AudioChunkPlayer {
  Future<void> addChunk(
    Uint8List bytes, {
    int sampleRate,
    int bufferSize,
    bool interleaved,
    VoidCallback? onFinished,
  });

  Future<void> stop();
  Future<void> dispose();
}

/// Streams PCM16 audio into a FlutterSoundPlayer.
class PcmAudioPlayer implements AudioChunkPlayer {
  FlutterSoundPlayer _player = FlutterSoundPlayer();
  Future<void>? _startFuture;
  bool _stopped = true;
  VoidCallback? _onFinished;
  bool _finishedNotified = false;

  bool get isPlaying => _player.isPlaying;

  @override
  Future<void> addChunk(
    Uint8List bytes, {
    int sampleRate = 16000,
    int bufferSize = 4096,
    bool interleaved = true,
    VoidCallback? onFinished,
  }) async {
    _onFinished ??= onFinished;
    _startFuture ??= _start(
      sampleRate: sampleRate,
      bufferSize: bufferSize,
      interleaved: interleaved,
    );
    await _startFuture;
    _player.uint8ListSink?.add(bytes);
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    try {
      await _player.uint8ListSink?.close();
    } catch (_) {}
    try {
      await _player.stopPlayer();
    } catch (_) {}
    try {
      await _player.closePlayer();
    } catch (_) {}
    _player = FlutterSoundPlayer();
    _startFuture = null;
    _stopped = true;
    _notifyFinished();
  }

  @override
  Future<void> dispose() => stop();

  Future<void> _start({
    required int sampleRate,
    required int bufferSize,
    required bool interleaved,
  }) async {
    _stopped = false;
    _finishedNotified = false;
    await _player.openPlayer();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: sampleRate,
      bufferSize: bufferSize,
      interleaved: interleaved,
    );
  }

  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    _onFinished?.call();
    _onFinished = null;
  }
}
