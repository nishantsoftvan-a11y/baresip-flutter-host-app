package com.sip.sip_sdk_flutter_example.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.sip.sipsdk.api.SdkCallback
import com.sip.sipsdk.api.SipSdk
import com.sip.sipsdk.call.CallManager
import com.sip.sipsdk.model.CallState
import com.sip.sip_sdk_flutter_example.audio.HostAudioEngine

/**
 * Android 14+ Compliant VoIP Foreground Service for Flutter Host App.
 *
 * Implements two distinct notification channels:
 * 1. `sip_flutter_incoming_channel` (High Importance, Ringtone, Vibration, Full-Screen Intent for incoming calls)
 * 2. `sip_flutter_active_channel` (Low/Default Importance, Silent, Persistent in-call controls for active calls)
 */
class HostVoipForegroundService : Service(), SdkCallback {

    companion object {
        private const val TAG = "HostVoipService"

        const val CHANNEL_INCOMING_ID = "sip_flutter_incoming_channel"
        const val CHANNEL_ACTIVE_ID = "sip_flutter_active_channel"

        const val NOTIFICATION_STANDBY_ID = 1000
        const val NOTIFICATION_ACTIVE_CALL_ID = 1001
        const val NOTIFICATION_INCOMING_CALL_ID = 1002

        const val ACTION_START_SERVICE = "com.sip.sip_sdk_flutter_example.ACTION_START_SERVICE"
        const val ACTION_STOP_SERVICE = "com.sip.sip_sdk_flutter_example.ACTION_STOP_SERVICE"
        const val ACTION_START_CALL = "com.sip.sip_sdk_flutter_example.ACTION_START_CALL"
        const val ACTION_INCOMING_CALL = "com.sip.sip_sdk_flutter_example.ACTION_INCOMING_CALL"
        const val ACTION_STOP_CALL = "com.sip.sip_sdk_flutter_example.ACTION_STOP_CALL"
        const val ACTION_ANSWER = "com.sip.sip_sdk_flutter_example.ACTION_ANSWER"
        const val ACTION_REJECT = "com.sip.sip_sdk_flutter_example.ACTION_REJECT"
        const val ACTION_HANGUP = "com.sip.sip_sdk_flutter_example.ACTION_HANGUP"
        const val ACTION_TOGGLE_MUTE = "com.sip.sip_sdk_flutter_example.ACTION_TOGGLE_MUTE"

        const val EXTRA_PEER_URI = "extra_peer_uri"
        const val EXTRA_CALL_ID = "extra_call_id"

        fun startService(context: Context) {
            val intent = Intent(context, HostVoipForegroundService::class.java).apply {
                action = ACTION_START_SERVICE
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, HostVoipForegroundService::class.java).apply {
                action = ACTION_STOP_SERVICE
            }
            context.startService(intent)
        }

        fun startCall(context: Context, peerUri: String) {
            val intent = Intent(context, HostVoipForegroundService::class.java).apply {
                action = ACTION_START_CALL
                putExtra(EXTRA_PEER_URI, peerUri)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun showIncomingCall(context: Context, peerUri: String, callId: Long) {
            val intent = Intent(context, HostVoipForegroundService::class.java).apply {
                action = ACTION_INCOMING_CALL
                putExtra(EXTRA_PEER_URI, peerUri)
                putExtra(EXTRA_CALL_ID, callId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopCall(context: Context) {
            val intent = Intent(context, HostVoipForegroundService::class.java).apply {
                action = ACTION_STOP_CALL
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var isMuted = false
    private var currentPeer = "Call"
    private var incomingCallId: Long = 0L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "SipFlutter:VoipWakeLock"
        ).apply {
            setReferenceCounted(false)
        }

        SipSdk.registerCallback(this)
        Log.i(TAG, "HostVoipForegroundService created and registered with SipSdk")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_SERVICE -> {
                startForegroundWithStandbyNotification()
            }
            ACTION_STOP_SERVICE -> {
                cancelIncomingNotification()
                HostAudioEngine.getInstance(applicationContext).stopCallAudio()
                wakeLock?.let { if (it.isHeld) it.release() }
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_INCOMING_CALL -> {
                currentPeer = intent.getStringExtra(EXTRA_PEER_URI) ?: "Incoming Call"
                incomingCallId = intent.getLongExtra(EXTRA_CALL_ID, 0L)
                wakeLock?.acquire(60 * 1000L) // 60 seconds ring timeout
                startForegroundWithIncomingNotification(currentPeer, incomingCallId)
            }
            ACTION_START_CALL -> {
                currentPeer = intent.getStringExtra(EXTRA_PEER_URI) ?: "Voice Call"
                cancelIncomingNotification()
                wakeLock?.acquire(60 * 60 * 1000L) // 1 hour max in-call
                startForegroundWithActiveNotification(currentPeer)
                HostAudioEngine.getInstance(applicationContext).startCallAudio()
            }
            ACTION_ANSWER -> {
                cancelIncomingNotification()
                CallManager.answerCall(if (incomingCallId != 0L) incomingCallId else null)
                startForegroundWithActiveNotification(currentPeer)
                HostAudioEngine.getInstance(applicationContext).startCallAudio()
            }
            ACTION_REJECT -> {
                cancelIncomingNotification()
                CallManager.rejectCall(if (incomingCallId != 0L) incomingCallId else null)
                HostAudioEngine.getInstance(applicationContext).stopCallAudio()
                wakeLock?.let { if (it.isHeld) it.release() }
                startForegroundWithStandbyNotification()
            }
            ACTION_STOP_CALL, ACTION_HANGUP -> {
                if (intent.action == ACTION_HANGUP) {
                    CallManager.hangup()
                }
                cancelIncomingNotification()
                HostAudioEngine.getInstance(applicationContext).stopCallAudio()
                wakeLock?.let { if (it.isHeld) it.release() }
                startForegroundWithStandbyNotification()
            }
            ACTION_TOGGLE_MUTE -> {
                isMuted = !isMuted
                HostAudioEngine.getInstance(applicationContext).setMute(isMuted)
                CallManager.mute(isMuted)
                updateActiveNotification(currentPeer)
            }
        }
        return START_STICKY
    }

    // ── SdkCallback Implementation (Invoked by Native Headless SDK) ───────────

    override fun onCallState(state: CallState, peerUri: String, callId: Long) {
        Log.i(TAG, "SdkCallback: onCallState state=$state, peerUri=$peerUri, callId=$callId")
        when (state) {
            CallState.INCOMING -> {
                currentPeer = peerUri.ifEmpty { "Incoming Call" }
                incomingCallId = callId
                wakeLock?.acquire(60 * 1000L)
                startForegroundWithIncomingNotification(currentPeer, incomingCallId)
            }
            CallState.ESTABLISHED -> {
                currentPeer = peerUri.ifEmpty { "Active Call" }
                cancelIncomingNotification()
                wakeLock?.acquire(60 * 60 * 1000L)
                startForegroundWithActiveNotification(currentPeer)
                HostAudioEngine.getInstance(applicationContext).startCallAudio()
            }
            CallState.CLOSED -> {
                cancelIncomingNotification()
                HostAudioEngine.getInstance(applicationContext).stopCallAudio()
                wakeLock?.let { if (it.isHeld) it.release() }
                startForegroundWithStandbyNotification()
            }
            else -> {}
        }
    }

    override fun onRegistrationState(state: com.sip.sipsdk.model.RegistrationState, reason: String) {
        Log.i(TAG, "SdkCallback: onRegistrationState state=$state, reason=$reason")
        if (state == com.sip.sipsdk.model.RegistrationState.REGISTERED) {
            startForegroundWithStandbyNotification()
        }
    }

    private fun startForegroundWithIncomingNotification(peer: String, callId: Long) {
        val notification = buildIncomingNotification(peer, callId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            startForeground(NOTIFICATION_INCOMING_CALL_ID, notification, type)
        } else {
            startForeground(NOTIFICATION_INCOMING_CALL_ID, notification)
        }
    }

    private fun startForegroundWithActiveNotification(peer: String) {
        val notification = buildActiveNotification(peer)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            startForeground(NOTIFICATION_ACTIVE_CALL_ID, notification, type)
        } else {
            startForeground(NOTIFICATION_ACTIVE_CALL_ID, notification)
        }
    }

    private fun startForegroundWithStandbyNotification() {
        val notification = buildStandbyNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_STANDBY_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL)
        } else {
            startForeground(NOTIFICATION_STANDBY_ID, notification)
        }
    }

    private fun buildStandbyNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, CHANNEL_ACTIVE_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("VoIP Ready")
            .setContentText("Listening for incoming calls")
            .setOngoing(true)
            .setContentIntent(contentPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateActiveNotification(peer: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ACTIVE_CALL_ID, buildActiveNotification(peer))
    }

    private fun cancelIncomingNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_INCOMING_CALL_ID)
    }

    private fun buildIncomingNotification(peer: String, callId: Long): Notification {
        val incomingActivityIntent = Intent().apply {
            setClassName(packageName, "com.sip.sip_sdk_flutter_example.IncomingCallActivity")
            putExtra("peer_uri", peer)
            putExtra("call_id", callId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val targetIntent = if (incomingActivityIntent.resolveActivity(packageManager) != null) {
            incomingActivityIntent
        } else {
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                putExtra("peer_uri", peer)
                putExtra("call_id", callId)
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 10, targetIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val answerIntent = Intent(this, HostVoipForegroundService::class.java).apply {
            action = ACTION_ANSWER
            putExtra(EXTRA_CALL_ID, callId)
        }
        val answerPendingIntent = PendingIntent.getService(
            this, 11, answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val rejectIntent = Intent(this, HostVoipForegroundService::class.java).apply {
            action = ACTION_REJECT
            putExtra(EXTRA_CALL_ID, callId)
        }
        val rejectPendingIntent = PendingIntent.getService(
            this, 12, rejectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        return NotificationCompat.Builder(this, CHANNEL_INCOMING_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("Incoming VoIP Call")
            .setContentText(peer)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(ringtoneUri)
            .setVibrate(longArrayOf(0, 1000, 1000, 1000))
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(android.R.drawable.sym_action_call, "Answer", answerPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", rejectPendingIntent)
            .build()
    }

    private fun buildActiveNotification(peer: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this, 20, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val hangupIntent = Intent(this, HostVoipForegroundService::class.java).apply { action = ACTION_HANGUP }
        val hangupPendingIntent = PendingIntent.getService(
            this, 21, hangupIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val muteIntent = Intent(this, HostVoipForegroundService::class.java).apply { action = ACTION_TOGGLE_MUTE }
        val mutePendingIntent = PendingIntent.getService(
            this, 22, muteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, CHANNEL_ACTIVE_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("Ongoing Call")
            .setContentText(peer)
            .setOngoing(true)
            .setContentIntent(contentPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "End Call", hangupPendingIntent)
            .addAction(
                if (isMuted) android.R.drawable.ic_lock_silent_mode else android.R.drawable.ic_btn_speak_now,
                if (isMuted) "Unmute" else "Mute",
                mutePendingIntent
            )
            .build()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 1. Incoming Call Channel (High Importance, Ringtone, Vibration)
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val incomingChannel = NotificationChannel(
                CHANNEL_INCOMING_ID,
                "Incoming VoIP Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows incoming VoIP call alerts and full-screen notifications"
                setSound(
                    ringtoneUri,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 1000, 1000)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            // 2. Active Ongoing Call Channel (Silent, Low/Default Importance)
            val activeChannel = NotificationChannel(
                CHANNEL_ACTIVE_ID,
                "Ongoing VoIP Calls",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows active in-call status and actions without sound interruptions"
                setSound(null, null)
                enableVibration(false)
            }

            nm.createNotificationChannel(incomingChannel)
            nm.createNotificationChannel(activeChannel)
        }
    }

    override fun onDestroy() {
        SipSdk.unregisterCallback(this)
        cancelIncomingNotification()
        HostAudioEngine.getInstance(applicationContext).stopCallAudio()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
