package com.bullbitcoin.mobile

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock

/** Protects the existing owner engine. It never creates an engine or renews a native node lease. */
class CbfSyncService : Service() {
    private var owner: String? = null
    private var expiresAt = 0L
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val expiry = object : Runnable {
        override fun run() {
            if (owner == null) return
            val remaining = expiresAt - SystemClock.elapsedRealtime()
            if (remaining <= 0) finish("ownerExpired")
            else handler.postDelayed(this, remaining)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val requestedOwner = intent?.getStringExtra("owner")
        if (requestedOwner == null || pending?.owner != requestedOwner) {
            // An already rejected/expired start must never stop another owner.
            if (owner == null) stopSelf()
            return START_NOT_STICKY
        }
        val request = pending ?: return START_NOT_STICKY
        pending = null
        main.removeCallbacks(request.timeout)
        val title = intent?.getStringExtra("title")
        val body = intent?.getStringExtra("body")
        if (title.isNullOrBlank() || body.isNullOrBlank() || !notificationsAllowed(this)) {
            request.complete(false)
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(CHANNEL_ID, title, NotificationManager.IMPORTANCE_LOW)
            channel.lockscreenVisibility = Notification.VISIBILITY_SECRET
            channel.setShowBadge(false)
            channel.setSound(null, null)
            channel.enableVibration(false)
            manager.createNotificationChannel(channel)
            if (manager.getNotificationChannel(CHANNEL_ID)?.importance == NotificationManager.IMPORTANCE_NONE) {
                request.complete(false)
                stopSelf()
                return START_NOT_STICKY
            }
            val notification = Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setVisibility(Notification.VISIBILITY_SECRET)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_PROGRESS)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            expiresAt = 0L
            owner = requestedOwner
            running = this
            val power = getSystemService(PowerManager::class.java)
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "BullBitcoin:CbfSync").apply {
                setReferenceCounted(false)
            }
            if (!renew(requestedOwner)) {
                request.complete(false)
                return START_NOT_STICKY
            }
            handler.postDelayed(expiry, OWNER_TTL_MS)
            request.complete(true)
        } catch (_: RuntimeException) {
            request.complete(false)
            finish(null)
        }
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Android 15 gives only a few seconds. Never await Dart persistence/join here.
        finish("timeout")
    }

    override fun onDestroy() {
        val previousOwner = owner
        owner = null
        expiresAt = 0L
        if (running === this) running = null
        handler.removeCallbacks(expiry)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (previousOwner != null) listeners[previousOwner]?.invoke("serviceDestroyed")
        super.onDestroy()
    }

    private fun renew(requestedOwner: String): Boolean {
        if (owner != requestedOwner || expiresAt != 0L && SystemClock.elapsedRealtime() >= expiresAt) {
            if (owner == requestedOwner) finish("ownerExpired")
            return false
        }
        if (!notificationsAllowed(this)) {
            finish("notificationsDenied")
            return false
        }
        expiresAt = SystemClock.elapsedRealtime() + OWNER_TTL_MS
        // The lock exists only within this service and cannot outlive the owner's heartbeat.
        wakeLock?.acquire(OWNER_TTL_MS)
        return true
    }

    private fun finish(reason: String?) {
        val previousOwner = owner
        owner = null
        expiresAt = 0L
        if (running === this) running = null
        handler.removeCallbacks(expiry)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        if (reason != null && previousOwner != null) listeners[previousOwner]?.invoke(reason)
    }

    companion object {
        private const val CHANNEL_ID = "cbf_sync"
        // Payment outbox IDs are nonnegative; reserve the negative range here.
        private const val NOTIFICATION_ID = -0x434246
        private const val OWNER_TTL_MS = 5_000L
        private val main = Handler(Looper.getMainLooper())
        private var running: CbfSyncService? = null
        private data class Pending(val owner: String, val complete: (Boolean) -> Unit, val timeout: Runnable)
        private var pending: Pending? = null
        private val listeners = mutableMapOf<String, (String) -> Unit>()

        fun observe(owner: String, listener: (String) -> Unit) { listeners[owner] = listener }
        fun forget(owner: String) { listeners.remove(owner) }

        fun start(context: Context, owner: String, title: String, body: String, complete: (Boolean) -> Unit) {
            if (owner.isBlank() || running != null || pending != null || !notificationsAllowed(context)) {
                complete(false)
                return
            }
            val timeout = Runnable {
                val request = pending
                if (request?.owner == owner) {
                    pending = null
                    request.complete(false)
                }
            }
            pending = Pending(owner, complete, timeout)
            main.postDelayed(timeout, 3_000)
            try {
                context.startForegroundService(Intent(context, CbfSyncService::class.java)
                    .putExtra("owner", owner).putExtra("title", title).putExtra("body", body))
            } catch (_: RuntimeException) {
                pending = null
                main.removeCallbacks(timeout)
                complete(false)
            }
        }

        fun renew(owner: String): Boolean = running?.renew(owner) ?: false

        fun stop(owner: String) {
            pending?.let {
                if (it.owner == owner) {
                    pending = null
                    main.removeCallbacks(it.timeout)
                    it.complete(false)
                }
            }
            running?.let { if (it.owner == owner) it.finish(null) }
        }

        private fun notificationsAllowed(context: Context): Boolean {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            return manager.areNotificationsEnabled() &&
                manager.getNotificationChannel(CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
        }
    }
}
