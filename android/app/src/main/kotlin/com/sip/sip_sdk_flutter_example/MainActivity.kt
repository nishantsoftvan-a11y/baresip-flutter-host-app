package com.sip.sip_sdk_flutter_example

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import com.sip.sipsdk.api.SdkCallback
import com.sip.sipsdk.api.SipSdk
import com.sip.sipsdk.model.CallState
import com.sip.sip_sdk_flutter_example.service.HostVoipForegroundService
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    private var sdkCallback: SdkCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        
        super.onCreate(savedInstanceState)
        
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        }

        // Host Application Lifecycle Listener for Headless SDK
        sdkCallback = object : SdkCallback {
            override fun onCallState(state: CallState, peerUri: String, callId: Long) {
                when (state) {
                    CallState.INCOMING -> {
                        HostVoipForegroundService.showIncomingCall(applicationContext, peerUri, callId)
                    }
                    CallState.ESTABLISHED -> {
                        HostVoipForegroundService.startCall(applicationContext, peerUri)
                    }
                    CallState.CLOSED -> {
                        HostVoipForegroundService.stopCall(applicationContext)
                    }
                    else -> {}
                }
            }

            override fun onRegistrationState(state: com.sip.sipsdk.model.RegistrationState, reason: String) {
                when (state) {
                    com.sip.sipsdk.model.RegistrationState.REGISTERED -> {
                        HostVoipForegroundService.startService(applicationContext)
                    }
                    com.sip.sipsdk.model.RegistrationState.OFFLINE -> {
                        HostVoipForegroundService.stopService(applicationContext)
                    }
                    else -> {}
                }
            }
        }
        sdkCallback?.let { SipSdk.registerCallback(it) }
    }

    override fun onResume() {
        super.onResume()
        checkFullScreenIntentPermission()
    }

    override fun onDestroy() {
        sdkCallback?.let { SipSdk.unregisterCallback(it) }
        sdkCallback = null
        super.onDestroy()
    }

    private fun checkFullScreenIntentPermission() {
        if (Build.VERSION.SDK_INT >= 34) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!notificationManager.canUseFullScreenIntent()) {
                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                    data = Uri.fromParts("package", packageName, null)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            }
        }
    }
}
