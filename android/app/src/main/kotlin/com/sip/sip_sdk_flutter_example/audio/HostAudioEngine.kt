package com.sip.sip_sdk_flutter_example.audio

import android.content.Context
import android.util.Log
import com.sip.sipsdk.api.SipSdk

/**
 * Host Audio Coordinator for Flutter host application.
 *
 * Coordinates PcmAudioPlayer, PcmAudioRecorder, and AudioRouteController.
 * Runs high-priority zero-copy PCM pipelines between hardware audio drivers
 * and the headless SDK native buffer.
 */
class HostAudioEngine private constructor(private val context: Context) {

    companion object {
        private const val TAG = "HostAudioEngine"

        @Volatile
        private var instance: HostAudioEngine? = null

        fun getInstance(context: Context): HostAudioEngine =
            instance ?: synchronized(this) {
                instance ?: HostAudioEngine(context.applicationContext).also { instance = it }
            }
    }

    private var player: PcmAudioPlayer? = null
    private var recorder: PcmAudioRecorder? = null
    private var routeController: AudioRouteController? = null

    private var isEngineRunning = false
    private var sampleRate = 48000
    private var channelCount = 1

    var onAudioRouteChangedListener: ((HostAudioRoute) -> Unit)? = null

    init {
        routeController = AudioRouteController(context) { route ->
            Log.d(TAG, "Audio route changed: $route")
            onAudioRouteChangedListener?.invoke(route)
        }
    }

    @Synchronized
    fun startCallAudio() {
        if (isEngineRunning) {
            Log.w(TAG, "HostAudioEngine is already running")
            return
        }

        Log.i(TAG, "Starting HostAudioEngine for active call...")

        val (rate, channels) = SipSdk.getPcmFormat()
        if (rate > 0) {
            sampleRate = rate
            channelCount = channels
            Log.i(TAG, "Detected native PCM format: rate=$sampleRate, channels=$channelCount")
        } else {
            sampleRate = 48000
            channelCount = 1
            Log.w(TAG, "Defaulting to 48000Hz mono PCM")
        }

        // 1. Initialize Route Controller
        routeController?.start()

        // 2. Start Playback
        player = PcmAudioPlayer(sampleRate, channelCount).apply { start() }

        // 3. Start Capture
        recorder = PcmAudioRecorder(sampleRate, channelCount).apply { start() }

        isEngineRunning = true
        Log.i(TAG, "HostAudioEngine started successfully")
    }

    @Synchronized
    fun stopCallAudio() {
        if (!isEngineRunning) return
        Log.i(TAG, "Stopping HostAudioEngine...")

        // 1. Stop Recorder
        recorder?.stop()
        recorder = null

        // 2. Stop Player
        player?.stop()
        player = null

        // 3. Clear SPSC Buffers
        SipSdk.clearPcmBuffers()

        // 4. Restore Audio Route
        routeController?.stop()

        isEngineRunning = false
        Log.i(TAG, "HostAudioEngine stopped cleanly")
    }

    fun setMute(muted: Boolean) {
        recorder?.setMute(muted)
    }

    fun setRoute(route: HostAudioRoute) {
        routeController?.setRoute(route)
    }

    fun getCurrentRoute(): HostAudioRoute =
        routeController?.getCurrentRoute() ?: HostAudioRoute.EARPIECE

    fun getAvailableRoutes(): List<HostAudioRoute> =
        routeController?.getAvailableRoutes() ?: listOf(HostAudioRoute.EARPIECE, HostAudioRoute.SPEAKERPHONE)
}
