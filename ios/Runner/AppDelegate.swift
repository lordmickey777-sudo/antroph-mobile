import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioEngine: AVAudioEngine?
  private var playerNode: AVAudioPlayerNode?
  private var audioFormat: AVAudioFormat?
  private let gain: Float = 4.0 // Software gain to make PCM louder (matches Android)
  private let channelName = "com.antroph.auraapp/pcm_player"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up method channel for PCM audio playback
    let controller = window?.rootViewController as! FlutterViewController
    let pcmChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

    pcmChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate not available", details: nil))
        return
      }

      switch call.method {
      case "start":
        let args = call.arguments as? [String: Any]
        let sampleRate = args?["sampleRate"] as? Int ?? 24000
        self.startAudioEngine(sampleRate: sampleRate)
        result(true)

      case "write":
        let args = call.arguments as? [String: Any]
        if let bytes = args?["bytes"] as? FlutterStandardTypedData {
          self.writeAudioData(bytes.data)
          result(bytes.data.count)
        } else {
          result(0)
        }

      case "stop":
        self.stopAudioEngine()
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startAudioEngine(sampleRate: Int) {
    stopAudioEngine()

    do {
      // Configure audio session for playback through speaker
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
      )
      try audioSession.setActive(true)
      try audioSession.overrideOutputAudioPort(.speaker)

      audioEngine = AVAudioEngine()
      playerNode = AVAudioPlayerNode()

      // PCM 16-bit mono format
      audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: 1, interleaved: false)

      guard let engine = audioEngine, let player = playerNode, let format = audioFormat else {
        return
      }

      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: format)

      try engine.start()
      player.play()
    } catch {
      print("[\(channelName)] Failed to start audio engine: \(error)")
    }
  }

  private func writeAudioData(_ data: Data) {
    guard let player = playerNode, let format = audioFormat, player.isPlaying || audioEngine?.isRunning == true else {
      return
    }

    // Convert PCM16 bytes to Float32 samples with gain
    let sampleCount = data.count / 2
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else {
      return
    }

    buffer.frameLength = AVAudioFrameCount(sampleCount)

    guard let floatData = buffer.floatChannelData?[0] else {
      return
    }

    data.withUnsafeBytes { rawBuffer in
      let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
      for i in 0..<sampleCount {
        // Convert Int16 to Float32 (-1.0 to 1.0), apply gain, and clip
        var sample = Float(int16Buffer[i]) / Float(Int16.max) * gain
        // Clip to prevent distortion
        sample = max(-1.0, min(1.0, sample))
        floatData[i] = sample
      }
    }

    player.scheduleBuffer(buffer, completionHandler: nil)

    // Ensure player is playing
    if !player.isPlaying {
      player.play()
    }
  }

  private func stopAudioEngine() {
    playerNode?.stop()
    audioEngine?.stop()

    if let player = playerNode, let engine = audioEngine {
      engine.detach(player)
    }

    playerNode = nil
    audioEngine = nil
    audioFormat = nil
  }
}
