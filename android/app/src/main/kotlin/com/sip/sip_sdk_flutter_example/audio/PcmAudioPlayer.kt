package com.sip.sip_sdk_flutter_example.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Process
import android.util.Log
import com.sip.sipsdk.api.SipSdk
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

/**
 * High-priority PCM playback thread for Flutter host app.
 *
 * Reads decoded downlink audio from the headless SDK via zero-copy direct ByteBuffer
 * and writes directly to hardware AudioTrack.
 */
class PcmAudioPlayer(
    private val sampleRate: Int = 48000,
    private val channelCount: Int = 1
) {
    companion object {
        private const val TAG = "PcmAudioPlayer"
        private const val FRAME_MS = 20
    }

    private val isPlaying = AtomicBoolean(false)
    private var playerThread: Thread? = null
    private var audioTrack: AudioTrack? = null

    private val frameSamples = (sampleRate * FRAME_MS) / 1000
    private val bytesPerSample = 2 // 16-bit PCM
    private val frameBytes = frameSamples * channelCount * bytesPerSample

    fun start() {
        if (isPlaying.getAndSet(true)) {
            Log.w(TAG, "PcmAudioPlayer is already playing")
            return
        }

        playerThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            Log.i(TAG, "Audio player thread started (rate=$sampleRate, channels=$channelCount, frameBytes=$frameBytes)")

            val channelConfig = if (channelCount == 2) AudioFormat.CHANNEL_OUT_STEREO else AudioFormat.CHANNEL_OUT_MONO
            val minBufSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, AudioFormat.ENCODING_PCM_16BIT)
            val bufferSize = maxOf(minBufSize, frameBytes * 4)

            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(channelConfig)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            audioTrack = track

            try {
                track.play()
                val directBuffer = ByteBuffer.allocateDirect(frameBytes)
                val directArray = ByteArray(frameBytes)

                while (isPlaying.get()) {
                    directBuffer.clear()
                    val bytesRead = SipSdk.readDownlinkPcm(directBuffer, frameBytes)

                    if (bytesRead > 0) {
                        directBuffer.position(0)
                        directBuffer.limit(bytesRead)
                        directBuffer.get(directArray, 0, bytesRead)
                        track.write(directArray, 0, bytesRead, AudioTrack.WRITE_BLOCKING)
                    } else {
                        Thread.sleep(5)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in playback loop: ${e.message}", e)
            } finally {
                runCatching {
                    track.stop()
                    track.release()
                }
                audioTrack = null
                Log.i(TAG, "Audio player thread exited cleanly")
            }
        }, "FlutterSipPcmPlayer").apply { start() }
    }

    fun stop() {
        if (!isPlaying.getAndSet(false)) return
        playerThread?.interrupt()
        playerThread = null
    }
}
