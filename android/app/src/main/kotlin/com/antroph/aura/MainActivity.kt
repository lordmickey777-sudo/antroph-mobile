package com.antroph.auraapp

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity : FlutterActivity() {
    private val channelName = "com.antroph.auraapp/pcm_player"
    private var audioTrack: AudioTrack? = null
    private val gain = 4.0f // software gain to make PCM louder

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
                                val shortLen = bytes.size / 2
                                val shortData = ShortArray(shortLen)
                                ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                                    .asShortBuffer()
                                    .get(shortData)
                                // Apply a basic gain with clipping protection.
                                for (i in 0 until shortLen) {
                                    val boosted =
                                        (shortData[i] * gain).toInt()
                                            .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                                    shortData[i] = boosted.toShort()
                                }
                                audioTrack?.write(
                                    shortData,
                                    0,
                                    shortLen,
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
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    // Media usage keeps output on the loudspeaker instead of earpiece.
                    .setUsage(AudioAttributes.USAGE_MEDIA)
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
            // Force max volume for this stream; overall device volume still applies.
            audioTrack?.setVolume(1.0f)
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
