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
              voiceUriOverride: Uri.parse(
                'wss://example.com/ws/realtime/voice',
              ),
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

    test(
      'sendTextPrompt shows pending assistant state before socket connects',
      () async {
        final gate = Completer<void>();
        final slowClient = FakeRealtimeVoiceClient(connectGate: gate);
        final slowContainer = ProviderContainer(
          overrides: [
            voiceChatControllerProvider.overrideWith(
              () => VoiceChatController(
                client: slowClient,
                player: FakeAudioChunkPlayer(),
                voiceUriOverride: Uri.parse(
                  'wss://example.com/ws/realtime/voice',
                ),
              ),
            ),
          ],
        );
        final slowSub = slowContainer.listen(
          voiceChatControllerProvider,
          (_, __) {},
          fireImmediately: true,
        );
        addTearDown(() {
          slowSub.close();
          slowContainer.dispose();
          slowClient.dispose();
        });

        final slowController = slowContainer.read(
          voiceChatControllerProvider.notifier,
        );
        final sendFuture = slowController.sendTextPrompt(
          'Tell me more',
          textOnly: true,
        );

        await Future<void>.delayed(Duration.zero);

        final pendingState = slowContainer.read(voiceChatControllerProvider);
        expect(pendingState.isProcessing, isTrue);
        expect(pendingState.showPendingAssistantBubble, isTrue);
        expect(pendingState.conversationHistory.last.content, 'Tell me more');
        expect(slowClient.sent, isEmpty);

        gate.complete();
        await sendFuture;

        expect(slowClient.sent, isNotEmpty);
      },
    );

    test('text delta clears pending assistant bubble', () async {
      await controller.sendTextPrompt('Hi', textOnly: true);

      expect(
        container.read(voiceChatControllerProvider).showPendingAssistantBubble,
        isTrue,
      );

      fakeClient.emitJson({'type': 'response.text.delta', 'delta': 'Hello'});
      await Future<void>.delayed(Duration.zero);

      final state = container.read(voiceChatControllerProvider);
      expect(state.showPendingAssistantBubble, isFalse);
      expect(state.aiResponse, 'Hello');
    });

    test(
      'sendTextPrompt clears pending assistant bubble on send failure',
      () async {
        final failingClient = FakeRealtimeVoiceClient(
          connectError: StateError('socket unavailable'),
        );
        final failingContainer = ProviderContainer(
          overrides: [
            voiceChatControllerProvider.overrideWith(
              () => VoiceChatController(
                client: failingClient,
                player: FakeAudioChunkPlayer(),
                voiceUriOverride: Uri.parse(
                  'wss://example.com/ws/realtime/voice',
                ),
              ),
            ),
          ],
        );
        final failingSub = failingContainer.listen(
          voiceChatControllerProvider,
          (_, __) {},
          fireImmediately: true,
        );
        addTearDown(() {
          failingSub.close();
          failingContainer.dispose();
          failingClient.dispose();
        });

        await failingContainer
            .read(voiceChatControllerProvider.notifier)
            .sendTextPrompt('Try this', textOnly: true);

        final state = failingContainer.read(voiceChatControllerProvider);
        expect(state.showPendingAssistantBubble, isFalse);
        expect(state.errorMessage, contains('Failed to send prompt'));
      },
    );

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

      await _waitFor(() => fakePlayer.addedChunks.isNotEmpty);

      expect(
        fakePlayer.addedChunks.single,
        equals(Uint8List.fromList(const [1, 2, 3, 4])),
      );
      final state = container.read(voiceChatControllerProvider);
      expect(
        state.conversationHistory.any(
          (item) => item.isAssistant && item.content == 'hello',
        ),
        isTrue,
      );
      expect(state.isProcessing, isFalse);
    });

    test('incoming response events clear stale listening state', () async {
      await controller.sendTextPrompt('prime');
      controller.state = container
          .read(voiceChatControllerProvider)
          .copyWith(
            isStoryMode: true,
            isRecording: true,
            isProcessing: false,
            isPlaying: false,
            phase: RealtimeVoicePhase.recording,
          );

      fakeClient.emitJson({'type': 'response.created'});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      var state = container.read(voiceChatControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.isProcessing, isTrue);
      expect(state.phase, RealtimeVoicePhase.processing);

      fakeClient.emitJson({
        'type': 'response.audio.delta',
        'audio': base64Encode([1, 2, 3, 4]),
      });
      await _waitFor(() => fakePlayer.addedChunks.isNotEmpty);

      state = container.read(voiceChatControllerProvider);
      expect(state.isRecording, isFalse);
    });

    test('handles binary audio frames', () async {
      await controller.sendTextPrompt('binary');
      fakeClient.emitBinary(Uint8List.fromList(const [9, 8]));

      await _waitFor(() => fakePlayer.addedChunks.isNotEmpty);

      expect(fakePlayer.addedChunks.last, Uint8List.fromList(const [9, 8]));
    });

    test(
      'stopPlayback cancels upstream audio and ignores stale chunks',
      () async {
        await controller.sendTextPrompt('interrupt');
        controller.state = container
            .read(voiceChatControllerProvider)
            .copyWith(isStoryMode: true, phase: RealtimeVoicePhase.ready);

        fakeClient.emitJson({
          'type': 'response.audio.delta',
          'audio': base64Encode([1, 2, 3, 4]),
        });
        await _waitFor(() => fakePlayer.addedChunks.isNotEmpty);

        await controller.stopPlayback();

        expect(fakeClient.sent.last['type'], 'response.cancel');
        final chunkCount = fakePlayer.addedChunks.length;

        fakeClient.emitJson({
          'type': 'response.audio.delta',
          'audio': base64Encode([5, 6, 7, 8]),
        });
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(fakePlayer.addedChunks.length, chunkCount);

        await controller.sendTextPrompt('resume');
        fakeClient.emitJson({'type': 'response.created'});
        fakeClient.emitJson({
          'type': 'response.audio.delta',
          'audio': base64Encode([9, 10, 11, 12]),
        });
        await _waitFor(() => fakePlayer.addedChunks.length == chunkCount + 1);
      },
    );

    test(
      'ensureStorySessionConnected resumes a closed story session',
      () async {
        controller.state = container
            .read(voiceChatControllerProvider)
            .copyWith(
              isStoryMode: true,
              phase: RealtimeVoicePhase.closed,
              storySession: const StorySessionInfo(
                sessionId: 'session_123',
                storyId: 'story_1',
              ),
            );

        await controller.ensureStorySessionConnected('story_1');

        expect(fakeClient.connectCalls, 1);
        final state = container.read(voiceChatControllerProvider);
        expect(state.isStoryMode, isTrue);
        expect(state.isConnecting, isTrue);
        expect(state.phase, RealtimeVoicePhase.waitingForReady);
      },
    );
  });

  group('VoiceChatController turn detection', () {
    late FakeRealtimeVoiceClient fakeClient;
    late ProviderContainer container;
    late ProviderSubscription<VoiceChatState> subscription;
    late TestVoiceChatController controller;

    setUp(() {
      fakeClient = FakeRealtimeVoiceClient();
      controller = TestVoiceChatController(
        client: fakeClient,
        player: FakeAudioChunkPlayer(),
      );
      container = ProviderContainer(
        overrides: [voiceChatControllerProvider.overrideWith(() => controller)],
      );
      subscription = container.listen(
        voiceChatControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );
      controller =
          container.read(voiceChatControllerProvider.notifier)
              as TestVoiceChatController;
    });

    tearDown(() {
      subscription.close();
      container.dispose();
      fakeClient.dispose();
    });

    test('quiet valid speech commits and enters processing', () async {
      controller.debugPrepareRecording();
      controller.debugInjectMicRmsSamples([0.008, 0.009, 0.031, 0.033]);

      await controller.stopRecordingAndSend();

      expect(
        fakeClient.sent.any(
          (message) => message['type'] == 'input_audio_buffer.commit',
        ),
        isTrue,
      );
      final state = container.read(voiceChatControllerProvider);
      expect(state.isProcessing, isTrue);
      expect(state.phase, RealtimeVoicePhase.processing);
    });

    test('ambient noise is rejected and auto-listens again', () async {
      controller.debugPrepareRecording();
      controller.debugInjectMicRmsSamples([0.004, 0.005, 0.006]);

      await controller.stopRecordingAndSend();

      var state = container.read(voiceChatControllerProvider);
      expect(state.isProcessing, isFalse);
      expect(state.phase, RealtimeVoicePhase.ready);
      expect(
        fakeClient.sent.any(
          (message) => message['type'] == 'input_audio_buffer.commit',
        ),
        isFalse,
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      state = container.read(voiceChatControllerProvider);
      expect(controller.startRecordingCalls, 1);
      expect(state.isRecording, isTrue);
      expect(state.phase, RealtimeVoicePhase.recording);
    });

    test('insufficient speech audio does not produce a response', () async {
      controller.debugPrepareRecording();
      controller.debugInjectMicRmsSamples([
        0.005,
        0.04,
        0.05,
      ], samplesPerChunk: 700);

      await controller.stopRecordingAndSend();

      final state = container.read(voiceChatControllerProvider);
      expect(state.isProcessing, isFalse);
      expect(state.phase, RealtimeVoicePhase.ready);
      expect(
        fakeClient.sent.any(
          (message) => message['type'] == 'input_audio_buffer.commit',
        ),
        isFalse,
      );
    });

    test(
      'speech activity flag tracks live sound instead of armed mic',
      () async {
        controller.debugPrepareRecording();

        expect(
          container.read(voiceChatControllerProvider).isUserSpeaking,
          isFalse,
        );

        controller.debugInjectMicRmsSamples([0.008, 0.031]);
        expect(
          container.read(voiceChatControllerProvider).isUserSpeaking,
          isTrue,
        );

        controller.debugInjectMicRmsSamples([0.004]);
        expect(
          container.read(voiceChatControllerProvider).isUserSpeaking,
          isTrue,
        );

        await Future<void>.delayed(const Duration(milliseconds: 260));
        expect(
          container.read(voiceChatControllerProvider).isUserSpeaking,
          isFalse,
        );
      },
    );
  });
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final sw = Stopwatch()..start();
  while (!condition()) {
    if (sw.elapsed >= timeout) {
      throw StateError('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class FakeRealtimeVoiceClient extends RealtimeVoiceClient {
  FakeRealtimeVoiceClient({this.connectGate, this.connectError});

  final StreamController<RealtimeIncomingMessage> _controller =
      StreamController<RealtimeIncomingMessage>.broadcast();
  final List<Map<String, dynamic>> sent = [];
  final List<Uint8List> sentBinary = [];
  final Completer<void>? connectGate;
  final Object? connectError;
  bool _open = false;
  int connectCalls = 0;

  @override
  Stream<RealtimeIncomingMessage> get messages => _controller.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> connect(Uri uri, {RealtimeVoiceConfig? config}) async {
    connectCalls++;
    await connectGate?.future;
    final error = connectError;
    if (error != null) throw error;
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

class TestVoiceChatController extends VoiceChatController {
  TestVoiceChatController({
    required RealtimeVoiceClient client,
    required AudioChunkPlayer player,
  }) : super(
         client: client,
         player: player,
         voiceUriOverride: Uri.parse('wss://example.com/ws/realtime/voice'),
       );

  int startRecordingCalls = 0;

  @override
  VoiceChatState build() {
    return const VoiceChatState();
  }

  @override
  Future<void> startRecording() async {
    startRecordingCalls++;
    state = state.copyWith(
      isRecording: true,
      isProcessing: false,
      isConnecting: false,
      phase: state.isStoryMode ? RealtimeVoicePhase.recording : state.phase,
    );
  }
}
