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

class TimerForegroundService : Service() {

    companion object {
        // ── Channels ──────────────────────────────────────────────────
        const val CHANNEL_SILENT = "lift_rest_timer_silent"
        const val CHANNEL_ALERT = "lift_rest_timer"

        // ── Notification IDs ──────────────────────────────────────────
        const val NOTIFICATION_ID_RUNNING = 10
        const val NOTIFICATION_ID_COMPLETE = 11

        // ── Intent actions ────────────────────────────────────────────
        const val ACTION_START = "com.slayernominee.lift.TIMER_START"
        const val ACTION_STOP = "com.slayernominee.lift.TIMER_STOP"
        const val EXTRA_DURATION_SECONDS = "duration_seconds"

        var isRunning: Boolean = false
            private set

        var timerCompleted: Boolean = false
            private set
    }

    // ── State ────────────────────────────────────────────────────────

    private var countDownTimer: CountDownTimer? = null
    private var wakeLock: PowerManager.WakeLock? = null

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
                startForeground(
                    NOTIFICATION_ID_RUNNING,
                    buildRunningNotification(durationSeconds),
                )
                startCountdown(durationSeconds.toLong())
            }

            else -> stopSelf()
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
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
                nm.notify(
                    NOTIFICATION_ID_RUNNING,
                    buildRunningNotification(remaining),
                )
            }

            override fun onFinish() {
                onTimerComplete()
            }
        }.start()
    }

    private fun onTimerComplete() {
        timerCompleted = true
        isRunning = false
        releaseWakeLock()
        countDownTimer = null

        val nm = getSystemService(NotificationManager::class.java)

        // Remove the silent running notification first.
        stopForeground(STOP_FOREGROUND_REMOVE)

        // Post the completion notification as a brand-new notification
        // on the alert channel so it rings, vibrates and shows heads-up.
        nm.notify(NOTIFICATION_ID_COMPLETE, buildCompleteNotification())

        // Extra vibration pulse.
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

        stopSelf()
    }

    // ── Cleanup (manual stop) ────────────────────────────────────────

    private fun cleanup() {
        if (timerCompleted) {
            isRunning = false
            stopSelf()
            return
        }

        countDownTimer?.cancel()
        countDownTimer = null
        isRunning = false
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        val nm = getSystemService(NotificationManager::class.java)
        nm.cancel(NOTIFICATION_ID_RUNNING)
        nm.cancel(NOTIFICATION_ID_COMPLETE)
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
            acquire(10 * 60 * 1_000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    // ── Notifications ────────────────────────────────────────────────

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
