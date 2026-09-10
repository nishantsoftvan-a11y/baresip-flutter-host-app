package com.sip.sip_sdk_flutter_example.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Manages device audio routing (Speakerphone, Earpiece, Bluetooth/BLE, Wired Headset)
 * for Flutter host applications.
 *
 * Guarantees:
 * - If BLE / Bluetooth audio device is connected, default route is always BLE/Bluetooth.
 * - Dynamic auto-routing to BLE if connected mid-call.
 * - Graceful fallback to Wired Headset or Earpiece upon BLE disconnection.
 */
class AudioRouteController(
    private val context: Context,
    private val onRouteChanged: (HostAudioRoute) -> Unit
) {
    companion object {
        private const val TAG = "AudioRouteController"

        // AudioDeviceInfo types for compatibility across Android SDK levels
        private const val TYPE_HEARING_AID_INT = 23
        private const val TYPE_BLE_HEADSET_INT = 26
        private const val TYPE_BLE_SPEAKER_INT = 27
        private const val TYPE_BLE_BROADCAST_INT = 28
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentRoute = HostAudioRoute.EARPIECE
    private var isReceiverRegistered = false
    private var isDeviceCallbackRegistered = false
    private var commDeviceListener: Any? = null

    private val audioDeviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
            val bleAdded = addedDevices?.any { isBluetoothOrBleDevice(it) } == true
            Log.i(TAG, "onAudioDevicesAdded: count=${addedDevices?.size}, bleAdded=$bleAdded")
            if (bleAdded || hasConnectedBluetoothOrBle()) {
                Log.i(TAG, "BLE / Bluetooth device connected -> Auto-routing to BLUETOOTH")
                setRoute(HostAudioRoute.BLUETOOTH)
            } else if (addedDevices?.any { isWiredHeadsetDevice(it) } == true) {
                if (currentRoute != HostAudioRoute.BLUETOOTH) {
                    Log.i(TAG, "Wired headset connected -> Auto-routing to WIRED_HEADSET")
                    setRoute(HostAudioRoute.WIRED_HEADSET)
                }
            }
        }

        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            val bleRemoved = removedDevices?.any { isBluetoothOrBleDevice(it) } == true
            Log.i(TAG, "onAudioDevicesRemoved: count=${removedDevices?.size}, bleRemoved=$bleRemoved")
            if (bleRemoved && currentRoute == HostAudioRoute.BLUETOOTH) {
                if (hasConnectedBluetoothOrBle()) {
                    Log.i(TAG, "BLE device removed, but secondary BT/BLE device connected -> re-routing to BLUETOOTH")
                    setRoute(HostAudioRoute.BLUETOOTH)
                } else if (hasConnectedWiredHeadset()) {
                    Log.i(TAG, "BLE disconnected -> Fallback to WIRED_HEADSET")
                    setRoute(HostAudioRoute.WIRED_HEADSET)
                } else {
                    Log.i(TAG, "BLE disconnected -> Fallback to EARPIECE")
                    setRoute(HostAudioRoute.EARPIECE)
                }
            } else if (removedDevices?.any { isWiredHeadsetDevice(it) } == true && currentRoute == HostAudioRoute.WIRED_HEADSET) {
                if (hasConnectedBluetoothOrBle()) {
                    setRoute(HostAudioRoute.BLUETOOTH)
                } else {
                    setRoute(HostAudioRoute.EARPIECE)
                }
            }
        }
    }

    private val routeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_HEADSET_PLUG -> {
                    val state = intent.getIntExtra("state", -1)
                    if (state == 1) {
                        Log.i(TAG, "Wired headset plugged in")
                        if (currentRoute != HostAudioRoute.BLUETOOTH) {
                            setRoute(HostAudioRoute.WIRED_HEADSET)
                        }
                    } else if (state == 0 && currentRoute == HostAudioRoute.WIRED_HEADSET) {
                        Log.i(TAG, "Wired headset unplugged")
                        if (hasConnectedBluetoothOrBle()) {
                            setRoute(HostAudioRoute.BLUETOOTH)
                        } else {
                            setRoute(HostAudioRoute.EARPIECE)
                        }
                    }
                }
                AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED -> {
                    val state = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, AudioManager.SCO_AUDIO_STATE_ERROR)
                    Log.d(TAG, "Bluetooth SCO state changed: $state")
                    if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED) {
                        currentRoute = HostAudioRoute.BLUETOOTH
                        notifyRouteChanged(currentRoute)
                    }
                }
            }
        }
    }

    fun start() {
        registerCallbacks()
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

        // Rule: If BLE / Bluetooth is connected, default route must ALWAYS be BLE / Bluetooth
        val defaultRoute = when {
            hasConnectedBluetoothOrBle() -> {
                Log.i(TAG, "BLE / Bluetooth device connected -> Defaulting route to BLUETOOTH")
                HostAudioRoute.BLUETOOTH
            }
            hasConnectedWiredHeadset() -> {
                Log.i(TAG, "Wired headset connected -> Defaulting route to WIRED_HEADSET")
                HostAudioRoute.WIRED_HEADSET
            }
            else -> {
                Log.i(TAG, "No headset detected -> Defaulting route to EARPIECE")
                HostAudioRoute.EARPIECE
            }
        }
        setRoute(defaultRoute)
    }

    fun stop() {
        unregisterCallbacks()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            runCatching { audioManager.clearCommunicationDevice() }
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

        notifyRouteChanged(currentRoute)
    }

    private fun setRouteApi31(route: HostAudioRoute) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

        val availableDevices = audioManager.availableCommunicationDevices
        val targetDevice: AudioDeviceInfo? = when (route) {
            HostAudioRoute.SPEAKERPHONE -> {
                availableDevices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            }
            HostAudioRoute.EARPIECE -> {
                availableDevices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE }
            }
            HostAudioRoute.BLUETOOTH -> {
                findBluetoothOrBleCommDevice()
            }
            HostAudioRoute.WIRED_HEADSET -> {
                availableDevices.firstOrNull { isWiredHeadsetDevice(it) }
            }
        }

        if (targetDevice != null) {
            val success = audioManager.setCommunicationDevice(targetDevice)
            Log.i(TAG, "setCommunicationDevice(${targetDevice.productName}, type=${targetDevice.type}) result: $success")
        } else if (route == HostAudioRoute.EARPIECE) {
            audioManager.clearCommunicationDevice()
            Log.i(TAG, "clearCommunicationDevice() for EARPIECE route")
        } else {
            Log.w(TAG, "Target device not found in available communication devices for route=$route, falling back to legacy")
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
        if (hasConnectedBluetoothOrBle()) {
            routes.add(HostAudioRoute.BLUETOOTH)
        }
        if (hasConnectedWiredHeadset()) {
            routes.add(HostAudioRoute.WIRED_HEADSET)
        }
        return routes
    }

    fun isBluetoothOrBleDevice(device: AudioDeviceInfo): Boolean {
        val type = device.type
        return type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
               type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
               type == TYPE_HEARING_AID_INT ||
               type == TYPE_BLE_HEADSET_INT ||
               type == TYPE_BLE_SPEAKER_INT ||
               type == TYPE_BLE_BROADCAST_INT
    }

    fun isWiredHeadsetDevice(device: AudioDeviceInfo): Boolean {
        val type = device.type
        return type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
               type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
               type == AudioDeviceInfo.TYPE_USB_HEADSET ||
               type == AudioDeviceInfo.TYPE_USB_DEVICE
    }

    fun hasConnectedBluetoothOrBle(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val commDevices = audioManager.availableCommunicationDevices
            if (commDevices.any { isBluetoothOrBleDevice(it) }) return true
        }
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return devices.any { isBluetoothOrBleDevice(it) }
    }

    fun hasConnectedWiredHeadset(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val commDevices = audioManager.availableCommunicationDevices
            if (commDevices.any { isWiredHeadsetDevice(it) }) return true
        }
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return devices.any { isWiredHeadsetDevice(it) }
    }

    private fun findBluetoothOrBleCommDevice(): AudioDeviceInfo? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        val commDevices = audioManager.availableCommunicationDevices
        // Prioritize BLE devices first, then hearing aids, SCO, and A2DP
        return commDevices.firstOrNull { it.type == TYPE_BLE_HEADSET_INT }
            ?: commDevices.firstOrNull { it.type == TYPE_BLE_SPEAKER_INT }
            ?: commDevices.firstOrNull { it.type == TYPE_HEARING_AID_INT }
            ?: commDevices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
            ?: commDevices.firstOrNull { it.type == TYPE_BLE_BROADCAST_INT }
            ?: commDevices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }
    }

    private fun registerCallbacks() {
        if (!isDeviceCallbackRegistered) {
            audioManager.registerAudioDeviceCallback(audioDeviceCallback, mainHandler)
            isDeviceCallbackRegistered = true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && commDeviceListener == null) {
            val listener = AudioManager.OnCommunicationDeviceChangedListener { device ->
                Log.i(TAG, "OnCommunicationDeviceChangedListener: device=${device?.productName}, type=${device?.type}")
                val route = when {
                    device == null -> if (audioManager.isSpeakerphoneOn) HostAudioRoute.SPEAKERPHONE else HostAudioRoute.EARPIECE
                    isBluetoothOrBleDevice(device) -> HostAudioRoute.BLUETOOTH
                    isWiredHeadsetDevice(device) -> HostAudioRoute.WIRED_HEADSET
                    device.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> HostAudioRoute.SPEAKERPHONE
                    else -> HostAudioRoute.EARPIECE
                }
                currentRoute = route
                notifyRouteChanged(route)
            }
            commDeviceListener = listener
            audioManager.addOnCommunicationDeviceChangedListener(context.mainExecutor, listener)
        }

        if (!isReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_HEADSET_PLUG)
                addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
            }
            context.registerReceiver(routeReceiver, filter)
            isReceiverRegistered = true
        }
    }

    private fun unregisterCallbacks() {
        if (isDeviceCallbackRegistered) {
            runCatching { audioManager.unregisterAudioDeviceCallback(audioDeviceCallback) }
            isDeviceCallbackRegistered = false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && commDeviceListener != null) {
            (commDeviceListener as? AudioManager.OnCommunicationDeviceChangedListener)?.let {
                runCatching { audioManager.removeOnCommunicationDeviceChangedListener(it) }
            }
            commDeviceListener = null
        }

        if (isReceiverRegistered) {
            runCatching { context.unregisterReceiver(routeReceiver) }
            isReceiverRegistered = false
        }
    }

    private fun notifyRouteChanged(route: HostAudioRoute) {
        mainHandler.post {
            onRouteChanged(route)
        }
    }
}
