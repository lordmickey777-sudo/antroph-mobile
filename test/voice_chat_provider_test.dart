import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:antroph_mobile/features/home/models/realtime_voice_bridge_models.dart';
import 'package:antroph_mobile/features/home/providers/voice_chat_provider.dart';
import 'package:antroph_mobile/features/home/services/pcm_audio_player.dart';
import 'package:antroph_mobile/features/home/services/realtime_voice_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceChatController realtime bridge', () {
    late FakeRealtimeVoiceClient fakeClient;
    late FakeAudioChunkPlayer fakePlayer;
    late ProviderContainer container;
    late ProviderSubscription<VoiceChatState> subscription;
    late VoiceChatController controller;

    setUp(() {
      fakeClient = FakeRealtimeVoiceClient();
      fakePlayer = FakeAudioChunkPlayer();
      container = ProviderContainer(
        overrides: [
          voiceChatControllerProvider.overrideWith(
            () => VoiceChatController(
              client: fakeClient,
              player: fakePlayer,
              voiceUriOverride:
                  Uri.parse('wss://example.com/ws/realtime/voice'),
            ),
          ),
        ],
      );
      subscription = container.listen(
        voiceChatControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );
      controller = container.read(voiceChatControllerProvider.notifier);
    });

    tearDown(() {
      subscription.close();
      container.dispose();
      fakeClient.dispose();
    });

    test('sendTextPrompt sends response.create payload', () async {
      await controller.sendTextPrompt('Hello world');

      expect(fakeClient.connectCalls, 1);
      expect(fakeClient.sent, isNotEmpty);
      final sent = fakeClient.sent.first;
      expect(sent['type'], 'response.create');
      final inputs = sent['response']['input'] as List;
      final content = inputs.first['content'] as List;
      expect(content.first['text'], 'Hello world');
      expect(container.read(voiceChatControllerProvider).isProcessing, isTrue);
    });

    test('handles audio and transcript events', () async {
      await controller.sendTextPrompt('Hi');

      fakeClient.emitJson({
        'type': 'response.audio.delta',
        'audio': base64Encode([1, 2, 3, 4]),
      });
      fakeClient.emitJson({
        'type': 'response.audio_transcript.delta',
        'delta': 'hello',
      });
      fakeClient.emitJson({'type': 'response.done'});

      await Future<void>.delayed(Duration.zero);

      expect(
        fakePlayer.addedChunks.single,
        equals(Uint8List.fromList(const [1, 2, 3, 4])),
      );
      final state = container.read(voiceChatControllerProvider);
      expect(state.aiResponse, 'hello');
      expect(state.isProcessing, isFalse);
    });

    test('handles binary audio frames', () async {
      await controller.sendTextPrompt('binary');
      fakeClient.emitBinary(Uint8List.fromList(const [9, 8]));

      await Future<void>.delayed(Duration.zero);

      expect(fakePlayer.addedChunks.last, Uint8List.fromList(const [9, 8]));
    });
  });
}

class FakeRealtimeVoiceClient extends RealtimeVoiceClient {
  FakeRealtimeVoiceClient();

  final StreamController<RealtimeIncomingMessage> _controller =
      StreamController<RealtimeIncomingMessage>.broadcast();
  final List<Map<String, dynamic>> sent = [];
  final List<Uint8List> sentBinary = [];
  bool _open = false;
  int connectCalls = 0;

  @override
  Stream<RealtimeIncomingMessage> get messages => _controller.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> connect(Uri uri, {RealtimeVoiceConfig? config}) async {
    connectCalls++;
    _open = true;
  }

  @override
  void send(Map<String, dynamic> message) {
    sent.add(message);
  }

  @override
  void sendBinary(Uint8List data) {
    sentBinary.add(data);
  }

  @override
  Future<void> close([int code = WebSocketStatus.normalClosure]) async {
    _open = false;
  }

  void emitJson(Map<String, dynamic> payload) {
    final typeStr = (payload['type'] as String?) ?? '';
    final type = RealtimeServerMessageType.fromString(typeStr);
    _controller.add(RealtimeIncomingMessage.json(payload, type));
  }

  void emitBinary(Uint8List bytes) {
    _controller.add(RealtimeIncomingMessage.binary(bytes));
  }

  void dispose() {
    _controller.close();
  }
}

class FakeAudioChunkPlayer implements AudioChunkPlayer {
  final List<Uint8List> addedChunks = [];
  bool stopped = false;

  @override
  Future<void> addChunk(
    Uint8List bytes, {
    int sampleRate = 16000,
    int bufferSize = 4096,
    bool interleaved = true,
    VoidCallback? onFinished,
  }) async {
    addedChunks.add(bytes);
    onFinished?.call();
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {
    stopped = true;
  }
}
