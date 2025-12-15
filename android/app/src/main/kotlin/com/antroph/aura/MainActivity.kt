package com.antroph.aura

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private val channelName = "com.antroph.aura/pcm_player"
    private var audioTrack: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                        val bufferSize = call.argument<Int>("bufferSize") ?: 4096
                        startTrack(sampleRate, bufferSize)
                        result.success(true)
                    }

                    "write" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes != null && bytes.isNotEmpty()) {
                            try {
                                audioTrack?.write(
                                    bytes,
                                    0,
                                    bytes.size,
                                    AudioTrack.WRITE_BLOCKING,
                                )
                            } catch (e: IllegalStateException) {
                                Log.e(channelName, "write failed", e)
                            }
                        }
                        result.success(bytes?.size ?: 0)
                    }

                    "stop" -> {
                        stopTrack()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun startTrack(sampleRate: Int, requestedBufferSize: Int) {
        stopTrack()
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferSize = max(minBuffer, requestedBufferSize)

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(bufferSize)
            .build()
        try {
            audioTrack?.play()
        } catch (e: IllegalStateException) {
            Log.e(channelName, "AudioTrack start failed", e)
            stopTrack()
        }
    }

    private fun stopTrack() {
        try {
            audioTrack?.stop()
            audioTrack?.flush()
        } catch (_: IllegalStateException) {
            // ignore
        }
        try {
            audioTrack?.release()
        } catch (_: IllegalStateException) {
            // ignore
        }
        audioTrack = null
    }
}
