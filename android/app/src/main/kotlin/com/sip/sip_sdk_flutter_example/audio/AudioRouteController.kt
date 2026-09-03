package com.sip.sip_sdk_flutter_example.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log

/**
 * Manages device audio routing (Speakerphone, Earpiece, Bluetooth SCO, Wired Headset)
 * for Flutter host applications.
 */
class AudioRouteController(
    private val context: Context,
    private val onRouteChanged: (HostAudioRoute) -> Unit
) {
    companion object {
        private const val TAG = "AudioRouteController"
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var currentRoute = HostAudioRoute.EARPIECE
    private var isReceiverRegistered = false

    private val routeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_HEADSET_PLUG -> {
                    val state = intent.getIntExtra("state", -1)
                    if (state == 1) {
                        Log.i(TAG, "Wired headset connected")
                        setRoute(HostAudioRoute.WIRED_HEADSET)
                    } else if (state == 0 && currentRoute == HostAudioRoute.WIRED_HEADSET) {
                        Log.i(TAG, "Wired headset disconnected")
                        setRoute(HostAudioRoute.EARPIECE)
                    }
                }
                AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED -> {
                    val state = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, AudioManager.SCO_AUDIO_STATE_ERROR)
                    Log.d(TAG, "Bluetooth SCO state changed: $state")
                    if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED) {
                        currentRoute = HostAudioRoute.BLUETOOTH
                        onRouteChanged(currentRoute)
                    }
                }
            }
        }
    }

    fun start() {
        if (!isReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_HEADSET_PLUG)
                addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
            }
            context.registerReceiver(routeReceiver, filter)
            isReceiverRegistered = true
        }

        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        setRoute(HostAudioRoute.EARPIECE)
    }

    fun stop() {
        if (isReceiverRegistered) {
            runCatching { context.unregisterReceiver(routeReceiver) }
            isReceiverRegistered = false
        }
        audioManager.isSpeakerphoneOn = false
        if (audioManager.isBluetoothScoOn) {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false
        }
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    fun setRoute(route: HostAudioRoute) {
        Log.i(TAG, "Setting audio route to $route")
        currentRoute = route

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setRouteApi31(route)
        } else {
            setRouteLegacy(route)
        }

        onRouteChanged(currentRoute)
    }

    private fun setRouteApi31(route: HostAudioRoute) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

        val availableDevices = audioManager.availableCommunicationDevices
        val targetType = when (route) {
            HostAudioRoute.SPEAKERPHONE -> AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
            HostAudioRoute.EARPIECE -> AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
            HostAudioRoute.BLUETOOTH -> AudioDeviceInfo.TYPE_BLUETOOTH_SCO
            HostAudioRoute.WIRED_HEADSET -> AudioDeviceInfo.TYPE_WIRED_HEADSET
        }

        val targetDevice = availableDevices.firstOrNull { it.type == targetType }
            ?: availableDevices.firstOrNull { route == HostAudioRoute.BLUETOOTH && it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }

        if (targetDevice != null) {
            val success = audioManager.setCommunicationDevice(targetDevice)
            Log.i(TAG, "setCommunicationDevice(${targetDevice.type}) result: $success")
        } else {
            Log.w(TAG, "Target device type $targetType not found in available communication devices, falling back to legacy")
            setRouteLegacy(route)
        }
    }

    @Suppress("DEPRECATION")
    private fun setRouteLegacy(route: HostAudioRoute) {
        when (route) {
            HostAudioRoute.SPEAKERPHONE -> {
                if (audioManager.isBluetoothScoOn) {
                    audioManager.stopBluetoothSco()
                    audioManager.isBluetoothScoOn = false
                }
                audioManager.isSpeakerphoneOn = true
            }
            HostAudioRoute.EARPIECE, HostAudioRoute.WIRED_HEADSET -> {
                if (audioManager.isBluetoothScoOn) {
                    audioManager.stopBluetoothSco()
                    audioManager.isBluetoothScoOn = false
                }
                audioManager.isSpeakerphoneOn = false
            }
            HostAudioRoute.BLUETOOTH -> {
                audioManager.isSpeakerphoneOn = false
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
            }
        }
    }

    fun getCurrentRoute(): HostAudioRoute = currentRoute

    fun getAvailableRoutes(): List<HostAudioRoute> {
        val routes = mutableListOf(HostAudioRoute.EARPIECE, HostAudioRoute.SPEAKERPHONE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val devices = audioManager.availableCommunicationDevices
            if (devices.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO || it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }) {
                routes.add(HostAudioRoute.BLUETOOTH)
            }
            if (devices.any { it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET || it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES }) {
                routes.add(HostAudioRoute.WIRED_HEADSET)
            }
        } else {
            routes.add(HostAudioRoute.BLUETOOTH)
        }
        return routes
    }
}
