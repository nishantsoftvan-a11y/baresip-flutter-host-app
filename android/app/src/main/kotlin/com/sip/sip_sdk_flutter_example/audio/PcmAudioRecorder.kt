package com.sip.sip_sdk_flutter_example.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Process
import android.util.Log
import com.sip.sipsdk.api.SipSdk
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

/**
 * High-priority PCM capture thread for Flutter host app.
 *
 * Captures microphone audio using VOICE_COMMUNICATION with hardware AEC and noise suppression,
 * and writes directly to headless SDK uplink buffer via zero-copy direct ByteBuffer.
 */
class PcmAudioRecorder(
    private val sampleRate: Int = 48000,
    private val channelCount: Int = 1
) {
    companion object {
        private const val TAG = "PcmAudioRecorder"
        private const val FRAME_MS = 20
    }

    private val isRecording = AtomicBoolean(false)
    private val isMuted = AtomicBoolean(false)
    private var recordThread: Thread? = null
    private var audioRecord: AudioRecord? = null

    private var aec: AcousticEchoCanceler? = null
    private var agc: AutomaticGainControl? = null
    private var ns: NoiseSuppressor? = null

    private val frameSamples = (sampleRate * FRAME_MS) / 1000
    private val bytesPerSample = 2 // 16-bit PCM
    private val frameBytes = frameSamples * channelCount * bytesPerSample

    fun setMute(muted: Boolean) {
        isMuted.set(muted)
        Log.i(TAG, "Audio recorder mute set to $muted")
    }

    @SuppressLint("MissingPermission")
    fun start() {
        if (isRecording.getAndSet(true)) {
            Log.w(TAG, "PcmAudioRecorder is already recording")
            return
        }

        recordThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            Log.i(TAG, "Audio recorder thread started (rate=$sampleRate, channels=$channelCount, frameBytes=$frameBytes)")

            val channelConfig = if (channelCount == 2) AudioFormat.CHANNEL_IN_STEREO else AudioFormat.CHANNEL_IN_MONO
            val minBufSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, AudioFormat.ENCODING_PCM_16BIT)
            val bufferSize = maxOf(minBufSize, frameBytes * 4)

            val record = AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                sampleRate,
                channelConfig,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )

            if (record.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord initialization failed!")
                isRecording.set(false)
                return@Thread
            }

            audioRecord = record

            val audioSessionId = record.audioSessionId
            if (AcousticEchoCanceler.isAvailable()) {
                aec = AcousticEchoCanceler.create(audioSessionId)?.apply {
                    enabled = true
                    Log.i(TAG, "Hardware Acoustic Echo Canceler (AEC) enabled")
                }
            }
            if (AutomaticGainControl.isAvailable()) {
                agc = AutomaticGainControl.create(audioSessionId)?.apply {
                    enabled = true
                    Log.i(TAG, "Hardware Automatic Gain Control (AGC) enabled")
                }
            }
            if (NoiseSuppressor.isAvailable()) {
                ns = NoiseSuppressor.create(audioSessionId)?.apply {
                    enabled = true
                    Log.i(TAG, "Hardware Noise Suppressor (NS) enabled")
                }
            }

            try {
                record.startRecording()
                val directBuffer = ByteBuffer.allocateDirect(frameBytes)
                val directArray = ByteArray(frameBytes)
                val zeroArray = ByteArray(frameBytes)

                while (isRecording.get()) {
                    val bytesRead = record.read(directArray, 0, frameBytes)

                    if (bytesRead > 0) {
                        directBuffer.clear()
                        if (isMuted.get()) {
                            directBuffer.put(zeroArray, 0, bytesRead)
                        } else {
                            directBuffer.put(directArray, 0, bytesRead)
                        }
                        directBuffer.position(0)
                        directBuffer.limit(bytesRead)

                        SipSdk.writeUplinkPcm(directBuffer, bytesRead)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in record loop: ${e.message}", e)
            } finally {
                runCatching {
                    record.stop()
                    record.release()
                    aec?.release()
                    agc?.release()
                    ns?.release()
                }
                aec = null
                agc = null
                ns = null
                audioRecord = null
                Log.i(TAG, "Audio recorder thread exited cleanly")
            }
        }, "FlutterSipPcmRecorder").apply { start() }
    }

    fun stop() {
        if (!isRecording.getAndSet(false)) return
        recordThread?.interrupt()
        recordThread = null
    }
}
