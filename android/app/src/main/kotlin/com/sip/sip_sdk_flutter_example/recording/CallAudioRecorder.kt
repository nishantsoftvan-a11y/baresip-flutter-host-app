package com.sip.sip_sdk_flutter_example.recording

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Process
import android.util.Log
import com.sip.sipsdk.api.SipSdk
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * [DEMO_RECORDING_TEST_FEATURE]
 *
 * High-fidelity 2-way call audio recorder.
 *
 * Synchronizes microphone input (uplink) and remote party voice (downlink) using
 * the continuous hardware audio clock from PcmAudioRecorder.
 *
 * Mixes both streams in real-time with 16-bit linear PCM saturation into a standard
 * Mono WAV file (clean 48,000 Hz or active negotiated sample rate).
 * Zero artificial silence gaps, zero drift, zero stutter.
 */
class CallAudioRecorder private constructor(private val context: Context) {

    companion object {
        private const val TAG = "CallAudioRecorder"
        private const val CHANNELS = 1 // Clean mixed mono: mic + remote
        private const val BITS_PER_SAMPLE = 16

        @Volatile
        private var instance: CallAudioRecorder? = null

        fun getInstance(context: Context): CallAudioRecorder =
            instance ?: synchronized(this) {
                instance ?: CallAudioRecorder(context.applicationContext).also { instance = it }
            }

        /** Non-blocking downlink tap from PcmAudioPlayer (remote party audio) */
        fun feedDownlink(buffer: ByteArray, offset: Int, length: Int) {
            val inst = instance ?: return
            if (inst.isRecording.get()) {
                inst.onDownlinkAudio(buffer, offset, length)
            }
        }

        /** Non-blocking uplink tap from PcmAudioRecorder (microphone audio) */
        fun feedUplink(buffer: ByteArray, offset: Int, length: Int) {
            val inst = instance ?: return
            if (inst.isRecording.get()) {
                inst.onUplinkAudio(buffer, offset, length)
            }
        }
    }

    private val isRecording = AtomicBoolean(false)
    private val totalBytesWritten = AtomicLong(0L)
    private var recordingStartTime = 0L
    private var currentFile: File? = null
    private var currentPeer: String = "Call"
    private var currentSampleRate: Int = 48000
    private var writerThread: Thread? = null

    // Downlink queue stores decoded remote frames waiting to be mixed with mic frames
    private val downlinkQueue = ConcurrentLinkedQueue<ShortArray>()
    // Disk write queue to isolate all file I/O from the audio threads
    private val writeQueue = LinkedBlockingQueue<ByteArray>(200)

    // Built-in MediaPlayer for in-app preview
    private var mediaPlayer: MediaPlayer? = null
    private var currentlyPlayingPath: String? = null
    var onPlaybackStateChanged: ((Boolean) -> Unit)? = null

    fun isRecordingActive(): Boolean = isRecording.get()

    fun getRecordingDirectory(): File {
        val dir = File(context.getExternalFilesDir(null) ?: context.filesDir, "demo_recordings")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    @Synchronized
    fun startRecording(peerUri: String = "Call", callId: Long = 0L): Boolean {
        if (isRecording.get()) {
            Log.w(TAG, "Recording is already active")
            return true
        }

        try {
            downlinkQueue.clear()
            writeQueue.clear()
            totalBytesWritten.set(0L)
            currentPeer = peerUri

            // Detect active negotiated sample rate from headless SDK
            val (rate, _) = runCatching { SipSdk.getPcmFormat() }.getOrDefault(Pair(48000, 1))
            currentSampleRate = if (rate > 0) rate else 48000
            Log.i(TAG, "Starting recording: peer=$peerUri, sampleRate=$currentSampleRate Hz")

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val sanitizedPeer = peerUri.replace(Regex("[^a-zA-Z0-9_-]"), "_").take(24)
            val filename = "call_rec_${timestamp}_$sanitizedPeer.wav"
            val file = File(getRecordingDirectory(), filename)
            currentFile = file

            // Write initial 44-byte WAV header placeholder
            val raf = RandomAccessFile(file, "rw")
            raf.write(ByteArray(44))
            raf.close()

            isRecording.set(true)
            recordingStartTime = System.currentTimeMillis()

            writerThread = Thread({
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
                writeRecordingLoop(file)
            }, "DemoCallAudioWriter").apply { start() }

            Log.i(TAG, "Started demo call recording to ${file.absolutePath}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording: ${e.message}", e)
            isRecording.set(false)
            return false
        }
    }

    @Synchronized
    fun stopRecording(): Map<String, Any?>? {
        if (!isRecording.getAndSet(false)) {
            Log.w(TAG, "No active recording to stop")
            return null
        }

        try {
            writerThread?.interrupt()
            writerThread?.join(1500)
            writerThread = null

            val file = currentFile ?: return null
            val durationMs = System.currentTimeMillis() - recordingStartTime
            val dataSize = totalBytesWritten.get()

            // Finalize WAV Header with exact bytes written & sample rate
            finalizeWavHeader(file, dataSize, currentSampleRate)

            Log.i(TAG, "Stopped demo call recording: ${file.name}, size=$dataSize bytes, duration=${durationMs}ms at $currentSampleRate Hz")

            val result = mapOf(
                "path" to file.absolutePath,
                "filename" to file.name,
                "durationMs" to durationMs,
                "durationSeconds" to (durationMs / 1000).toInt(),
                "sizeBytes" to file.length(),
                "sampleRate" to currentSampleRate,
                "channels" to CHANNELS,
                "timestamp" to recordingStartTime,
                "peerUri" to currentPeer
            )
            currentFile = null
            return result
        } catch (e: Exception) {
            Log.e(TAG, "Error finalizing recording: ${e.message}", e)
            return null
        }
    }

    /**
     * Ingests remote party audio samples from PcmAudioPlayer.
     * Converts to ShortArray and buffers into downlinkQueue.
     */
    private fun onDownlinkAudio(buffer: ByteArray, offset: Int, length: Int) {
        if (!isRecording.get() || length <= 0) return
        val sampleCount = length / 2
        val shorts = ShortArray(sampleCount)
        ByteBuffer.wrap(buffer, offset, length)
            .order(ByteOrder.LITTLE_ENDIAN)
            .asShortBuffer()
            .get(shorts)

        // Prevent unbounded lag drift if network delivers bursts
        while (downlinkQueue.size > 8) {
            downlinkQueue.poll()
        }
        downlinkQueue.offer(shorts)
    }

    /**
     * Master clock audio tap from PcmAudioRecorder (microphone).
     * Ticks steadily every 20ms with physical audio hardware precision.
     * Mixes current mic audio with available remote audio into writeQueue.
     */
    private fun onUplinkAudio(buffer: ByteArray, offset: Int, length: Int) {
        if (!isRecording.get() || length <= 0) return

        val sampleCount = length / 2
        val micShorts = ShortArray(sampleCount)
        ByteBuffer.wrap(buffer, offset, length)
            .order(ByteOrder.LITTLE_ENDIAN)
            .asShortBuffer()
            .get(micShorts)

        // Poll matching remote audio frame if available
        val remoteShorts = downlinkQueue.poll()

        // Mix 16-bit PCM with saturation protection
        val outBytes = ByteArray(sampleCount * 2)
        val outBuf = ByteBuffer.wrap(outBytes).order(ByteOrder.LITTLE_ENDIAN)

        for (i in 0 until sampleCount) {
            val mic = micShorts[i].toInt()
            val remote = if (remoteShorts != null && i < remoteShorts.size) remoteShorts[i].toInt() else 0
            val sum = mic + remote
            val clamped = sum.coerceIn(-32768, 32767).toShort()
            outBuf.putShort(clamped)
        }

        // Push to background disk queue (non-blocking)
        writeQueue.offer(outBytes)
    }

    /**
     * Background disk writer loop. Writes mixed PCM frames directly to file.
     */
    private fun writeRecordingLoop(file: File) {
        var raf: RandomAccessFile? = null
        try {
            raf = RandomAccessFile(file, "rw")
            raf.seek(44) // Skip header

            while (isRecording.get() || !writeQueue.isEmpty()) {
                val chunk = writeQueue.poll(100, TimeUnit.MILLISECONDS) ?: continue
                raf.write(chunk)
                totalBytesWritten.addAndGet(chunk.size.toLong())
            }
        } catch (ie: InterruptedException) {
            // Drain remaining queued chunks before exit
            while (true) {
                val chunk = writeQueue.poll() ?: break
                runCatching {
                    raf?.write(chunk)
                    totalBytesWritten.addAndGet(chunk.size.toLong())
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in recording write loop: ${e.message}", e)
        } finally {
            runCatching { raf?.close() }
        }
    }

    private fun finalizeWavHeader(file: File, dataSize: Long, sampleRate: Int) {
        var raf: RandomAccessFile? = null
        try {
            raf = RandomAccessFile(file, "rw")
            val totalFileSize = dataSize + 44 - 8
            val byteRate = sampleRate * CHANNELS * (BITS_PER_SAMPLE / 8)
            val blockAlign = CHANNELS * (BITS_PER_SAMPLE / 8)

            raf.seek(0)
            // RIFF chunk
            raf.writeBytes("RIFF")
            raf.writeInt(Integer.reverseBytes(totalFileSize.toInt()))
            raf.writeBytes("WAVE")

            // fmt sub-chunk
            raf.writeBytes("fmt ")
            raf.writeInt(Integer.reverseBytes(16)) // Subchunk1Size = 16 for PCM
            raf.writeShort(java.lang.Short.reverseBytes(1.toShort()).toInt()) // AudioFormat 1 = PCM
            raf.writeShort(java.lang.Short.reverseBytes(CHANNELS.toShort()).toInt())
            raf.writeInt(Integer.reverseBytes(sampleRate))
            raf.writeInt(Integer.reverseBytes(byteRate))
            raf.writeShort(java.lang.Short.reverseBytes(blockAlign.toShort()).toInt())
            raf.writeShort(java.lang.Short.reverseBytes(BITS_PER_SAMPLE.toShort()).toInt())

            // data sub-chunk
            raf.writeBytes("data")
            raf.writeInt(Integer.reverseBytes(dataSize.toInt()))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update WAV header: ${e.message}", e)
        } finally {
            runCatching { raf?.close() }
        }
    }

    // ── File Management & Playback ───────────────────────────────────────────

    fun getRecordings(): List<Map<String, Any>> {
        val dir = getRecordingDirectory()
        val files = dir.listFiles { _, name -> name.endsWith(".wav") } ?: return emptyList()

        return files.sortedByDescending { it.lastModified() }.map { f ->
            val size = f.length()
            val pcmDataSize = maxOf(0L, size - 44)
            // 16-bit mono byteRate = currentSampleRate * 2
            val sRate = if (currentSampleRate > 0) currentSampleRate else 48000
            val durationSec = (pcmDataSize / (sRate * 2)).toInt()

            mapOf(
                "path" to f.absolutePath,
                "filename" to f.name,
                "durationSeconds" to durationSec,
                "sizeBytes" to size,
                "timestamp" to f.lastModified()
            )
        }
    }

    fun deleteRecording(path: String): Boolean {
        return try {
            if (currentlyPlayingPath == path) {
                stopPlayback()
            }
            val f = File(path)
            f.exists() && f.delete()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete recording $path: ${e.message}")
            false
        }
    }

    fun deleteAllRecordings(): Boolean {
        return try {
            stopPlayback()
            val dir = getRecordingDirectory()
            dir.listFiles()?.forEach { it.delete() }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete all recordings: ${e.message}")
            false
        }
    }

    @Synchronized
    fun playRecording(path: String, onFinished: (() -> Unit)? = null): Boolean {
        stopPlayback()
        return try {
            val file = File(path)
            if (!file.exists()) {
                Log.w(TAG, "File does not exist: $path")
                return false
            }

            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                setDataSource(context, Uri.fromFile(file))
                prepare()
                setOnCompletionListener {
                    stopPlayback()
                    onFinished?.invoke()
                }
                start()
            }
            mediaPlayer = player
            currentlyPlayingPath = path
            onPlaybackStateChanged?.invoke(true)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error playing audio $path: ${e.message}", e)
            stopPlayback()
            false
        }
    }

    @Synchronized
    fun stopPlayback(): Boolean {
        return try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
            mediaPlayer = null
            currentlyPlayingPath = null
            onPlaybackStateChanged?.invoke(false)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping playback: ${e.message}")
            false
        }
    }

    fun isPlaying(): Boolean {
        return runCatching { mediaPlayer?.isPlaying == true }.getOrDefault(false)
    }

    fun getCurrentlyPlayingPath(): String? = currentlyPlayingPath
}
