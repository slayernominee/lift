package com.slayernominee.lift

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.slayernominee.lift/timer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTimer" -> {
                        val durationSeconds = call.argument<Int>("durationSeconds") ?: 0
                        if (durationSeconds <= 0) {
                            result.error("BAD_ARGS", "durationSeconds must be > 0", null)
                            return@setMethodCallHandler
                        }
                        startTimerService(durationSeconds)
                        result.success(null)
                    }

                    "stopTimer" -> {
                        stopTimerService()
                        result.success(null)
                    }

                    "isRunning" -> {
                        result.success(TimerForegroundService.isRunning)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun startTimerService(durationSeconds: Int) {
        val intent = Intent(this, TimerForegroundService::class.java).apply {
            action = TimerForegroundService.ACTION_START
            putExtra(TimerForegroundService.EXTRA_DURATION_SECONDS, durationSeconds)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopTimerService() {
        val intent = Intent(this, TimerForegroundService::class.java).apply {
            action = TimerForegroundService.ACTION_STOP
        }
        startService(intent)
    }
}
