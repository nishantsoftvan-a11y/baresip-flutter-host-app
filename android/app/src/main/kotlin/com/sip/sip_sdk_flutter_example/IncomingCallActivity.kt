package com.sip.sip_sdk_flutter_example

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.TextView
import android.view.View
import android.util.Log
import com.sip.sipsdk.api.SipSdk
import com.sip.sipsdk.api.SdkCallback
import com.sip.sipsdk.model.CallState
import com.sip.sipsdk.call.CallManager
import com.sip.sip_sdk_flutter_example.R

class IncomingCallActivity : Activity() {

    private val TAG = "IncomingCallActivity"
    private var callback: SdkCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Configure flags to display UI over the keyguard/lockscreen and wake up the screen
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

        setContentView(R.layout.activity_incoming_call)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        }

        val peerUri = intent.getStringExtra("peer_uri") ?: "Unknown"
        val callerUriText = findViewById<TextView>(R.id.callerUriText)
        callerUriText.text = peerUri

        findViewById<View>(R.id.btnDecline).setOnClickListener {
            Log.d(TAG, "Decline button clicked")
            CallManager.rejectCall()
            finish()
        }

        findViewById<View>(R.id.btnAnswer).setOnClickListener {
            Log.d(TAG, "Answer button clicked")
            CallManager.answerCall()
            
            // Launch the main activity to open the Flutter UI
            val mainIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            if (mainIntent != null) {
                startActivity(mainIntent)
            }
            finish()
        }

        // Listen for call state changes so we finish the activity if the call is hung up remotely
        callback = object : SdkCallback {
            override fun onCallState(state: CallState, peerUri: String, callId: Long) {
                Log.d(TAG, "onCallState changed to $state")
                if (state == CallState.CLOSED) {
                    Log.d(TAG, "Call closed, finishing activity")
                    finish()
                }
            }
        }
        callback?.let { SipSdk.registerCallback(it) }
    }

    override fun onDestroy() {
        callback?.let { SipSdk.unregisterCallback(it) }
        super.onDestroy()
    }
}
