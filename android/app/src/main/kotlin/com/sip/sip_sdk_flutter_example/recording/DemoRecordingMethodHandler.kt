package com.sip.sip_sdk_flutter_example.recording

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * [DEMO_RECORDING_TEST_FEATURE]
 *
 * MethodChannel handler connecting Flutter UI to the native CallAudioRecorder.
 *
 * Channel: `com.sip.sip_sdk_flutter_example/demo_recording`
 */
class DemoRecordingMethodHandler(
    private val context: Context,
    private val recorder: CallAudioRecorder
) : MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.sip.sip_sdk_flutter_example/demo_recording"

        fun register(context: Context, messenger: BinaryMessenger): DemoRecordingMethodHandler {
            val recorder = CallAudioRecorder.getInstance(context)
            val handler = DemoRecordingMethodHandler(context, recorder)
            val channel = MethodChannel(messenger, CHANNEL_NAME)
            channel.setMethodCallHandler(handler)
            handler.channel = channel
            return handler
        }
    }

    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        recorder.onPlaybackStateChanged = { isPlaying ->
            mainHandler.post {
                channel?.invokeMethod("onPlaybackStateChanged", mapOf("isPlaying" to isPlaying))
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isSupported" -> {
                result.success(true)
            }
            "isRecording" -> {
                result.success(recorder.isRecordingActive())
            }
            "startRecording" -> {
                val peerUri = call.argument<String>("peerUri") ?: "Call"
                val callId = call.argument<Number>("callId")?.toLong() ?: 0L
                val started = recorder.startRecording(peerUri, callId)
                result.success(started)
            }
            "stopRecording" -> {
                val info = recorder.stopRecording()
                result.success(info)
            }
            "getRecordings" -> {
                val list = recorder.getRecordings()
                result.success(list)
            }
            "deleteRecording" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGS", "Missing path", null)
                } else {
                    val deleted = recorder.deleteRecording(path)
                    result.success(deleted)
                }
            }
            "deleteAllRecordings" -> {
                val cleared = recorder.deleteAllRecordings()
                result.success(cleared)
            }
            "playRecording" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGS", "Missing path", null)
                } else {
                    val played = recorder.playRecording(path) {
                        mainHandler.post {
                            channel?.invokeMethod("onPlaybackCompleted", mapOf("path" to path))
                        }
                    }
                    result.success(played)
                }
            }
            "stopPlayback" -> {
                val stopped = recorder.stopPlayback()
                result.success(stopped)
            }
            "isPlaying" -> {
                result.success(recorder.isPlaying())
            }
            "getCurrentlyPlayingPath" -> {
                result.success(recorder.getCurrentlyPlayingPath())
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}
