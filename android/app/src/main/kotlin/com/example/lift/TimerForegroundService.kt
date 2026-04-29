package com.slayernominee.lift

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.CountDownTimer
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service that runs the rest-timer countdown entirely in the
 * native Android layer, independent of the Flutter / Dart isolate.
 *
 * Two notification channels:
 * - [CHANNEL_SILENT] – low importance, no sound.  Used for the running
 *   countdown ("Rest Timer – 1:30").
 * - [CHANNEL_ALERT]  – high importance, sound + vibration.  Used for the
 *   completion alert ("Rest Timer Complete") that stays in the shade until
 *   the user dismisses it.
 *
 * Lifecycle:
 *  1. Dart sends [ACTION_START] with the duration in seconds.
 *  2. Service enters foreground with a silent ongoing countdown notification.
 *  3. [CountDownTimer] ticks every second, silently updating the notification.
 *  4. On completion the notification is replaced with a persistent, audible
 *     alert on [CHANNEL_ALERT].  The foreground is detached so the
 *     notification survives service shutdown.
 *  5. Dart may send [ACTION_STOP] to cancel early (manual stop).
 */
class TimerForegroundService : Service() {

    companion object {
        // ── Channels ──────────────────────────────────────────────────
        /** Silent / low-importance channel used while the timer is running. */
        const val CHANNEL_SILENT = "lift_rest_timer_silent"
        /** High-importance channel used for the completion alert. */
        const val CHANNEL_ALERT = "lift_rest_timer"

        const val NOTIFICATION_ID = 10 // avoid clash with FLN's ID 0

        // ── Intent actions ────────────────────────────────────────────
        const val ACTION_START = "com.slayernominee.lift.TIMER_START"
        const val ACTION_STOP = "com.slayernominee.lift.TIMER_STOP"
        const val EXTRA_DURATION_SECONDS = "duration_seconds"

        /** Whether the service is currently running. */
        var isRunning: Boolean = false
            private set
    }

    // ── State ────────────────────────────────────────────────────────

    private var countDownTimer: CountDownTimer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    /**
     * `true` once [onTimerComplete] has fired.  Guards [cleanup] so that a
     * late-arriving [ACTION_STOP] from the Dart side (the Dart isolate
     * expiry tick races with this native countdown) does not remove the
     * completion notification that the user should see.
     */
    private var timerCompleted = false

    // ── Service lifecycle ────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent.action) {
            ACTION_STOP -> {
                cleanup()
                return START_NOT_STICKY
            }

            ACTION_START -> {
                val durationSeconds =
                    intent.getIntExtra(EXTRA_DURATION_SECONDS, 0)
                if (durationSeconds <= 0) {
                    stopSelf()
                    return START_NOT_STICKY
                }

                timerCompleted = false
                isRunning = true
                acquireWakeLock()
                startForeground(NOTIFICATION_ID, buildRunningNotification(durationSeconds))
                startCountdown(durationSeconds.toLong())
            }

            else -> stopSelf()
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        // Only release resources – notification lifecycle is handled in
        // onTimerComplete (detach) or cleanup (remove).
        countDownTimer?.cancel()
        countDownTimer = null
        isRunning = false
        releaseWakeLock()
        super.onDestroy()
    }

    // ── Countdown ────────────────────────────────────────────────────

    private fun startCountdown(durationSeconds: Long) {
        countDownTimer?.cancel()
        val durationMs = durationSeconds * 1_000L

        countDownTimer = object : CountDownTimer(durationMs, 1_000L) {
            override fun onTick(millisUntilFinished: Long) {
                val remaining = (millisUntilFinished / 1_000).toInt()
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(NOTIFICATION_ID, buildRunningNotification(remaining))
            }

            override fun onFinish() {
                onTimerComplete()
            }
        }.start()
    }

    /**
     * Called when the countdown reaches zero.  Replaces the silent running
     * notification with a persistent, audible alert on [CHANNEL_ALERT].
     */
    private fun onTimerComplete() {
        timerCompleted = true
        isRunning = false
        releaseWakeLock()
        countDownTimer = null

        // Post the completion notification on the alert channel.
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, buildCompleteNotification())

        // Vibrate – 500 ms pulse so the user notices even on silent.
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE)
                as android.os.Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                android.os.VibrationEffect.createOneShot(
                    500,
                    android.os.VibrationEffect.DEFAULT_AMPLITUDE,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(500)
        }

        // Detach (not remove!) so the completion notification stays in the
        // shade until the user swipes it away.
        stopForeground(STOP_FOREGROUND_DETACH)
        stopSelf()
    }

    // ── Cleanup (manual stop) ────────────────────────────────────────

    /**
     * Called when the user manually stops the timer via the Dart side.
     *
     * If the native countdown already completed ([timerCompleted] is `true`),
     * the completion notification is already visible and must **not** be
     * removed – the user needs to see "Timer Complete".  We just stop the
     * service.
     *
     * Otherwise the timer was still running; cancel everything and remove
     * the notification.
     */
    private fun cleanup() {
        if (timerCompleted) {
            // Native countdown already finished – keep the alert visible.
            isRunning = false
            stopSelf()
            return
        }

        // Manual stop while still counting down – tear everything down.
        countDownTimer?.cancel()
        countDownTimer = null
        isRunning = false
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ── WakeLock ─────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        releaseWakeLock()
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "lift::rest-timer",
        ).apply {
            acquire(10 * 60 * 1_000L) // 10 min safety net
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    // ── Notifications ────────────────────────────────────────────────

    /**
     * Silent, ongoing notification shown while the timer counts down.
     * Uses the low-importance [CHANNEL_SILENT] so it produces no sound
     * and no heads-up.
     */
    private fun buildRunningNotification(remainingSeconds: Int): Notification {
        val min = remainingSeconds / 60
        val sec = remainingSeconds % 60
        val timeText = String.format("%d:%02d", min, sec)

        return NotificationCompat.Builder(this, CHANNEL_SILENT)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("Rest Timer")
            .setContentText("Time remaining: $timeText")
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(launchIntent())
            .build()
    }

    /**
     * Persistent, audible notification shown when the timer completes.
     * Uses the high-importance [CHANNEL_ALERT] so it plays the default
     * notification sound and vibrates.
     *
     * `setAutoCancel(false)` ensures it stays in the notification shade
     * until the user explicitly dismisses it.
     */
    private fun buildCompleteNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ALERT)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("Rest Timer Complete")
            .setContentText("Time to get back to lifting! 💪")
            .setOngoing(false)
            .setAutoCancel(false)
            .setOnlyAlertOnce(false)
            .setDefaults(NotificationCompat.DEFAULT_SOUND)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(launchIntent())
            .build()
    }

    /**
     * [PendingIntent] that re-opens the app when the user taps the
     * notification.
     */
    private fun launchIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ── Channels ─────────────────────────────────────────────────────

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)

        // ── Silent channel for the running countdown ───────────────
        if (nm.getNotificationChannel(CHANNEL_SILENT) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_SILENT,
                    "Rest Timer (silent)",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Silent countdown while your rest timer is running"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                },
            )
        }

        // ── Alert channel for the completion notification ──────────
        if (nm.getNotificationChannel(CHANNEL_ALERT) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ALERT,
                    "Rest Timer",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Alert when your rest period is over"
                    enableVibration(true)
                },
            )
        }
    }
}
