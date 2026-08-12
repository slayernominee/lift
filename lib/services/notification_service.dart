import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for rest-timer notifications.
///
/// Uses a **dual strategy** to maximise reliability across OEM-specific
/// battery-optimisation quirks:
///
/// 1. **Native foreground service** (primary) – a Kotlin
///    [android.app.Service] runs the entire countdown in the native
///    Android layer, completely independent of the Flutter / Dart isolate.
///    It shows a persistent "Rest Timer – 1:30" notification that updates
///    every second and automatically fires a completion notification with
///    sound and vibration. This survives OEM process-killing, isolate
///    suspension, and AlarmManager blocking.
///
/// 2. **OS alarm via `zonedSchedule`** (secondary fallback) – for non-Android
///    platforms or edge cases where the foreground service cannot start.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Must match the channel IDs in TimerForegroundService.kt.
  static const _silentChannelId = 'lift_rest_timer_silent';
  static const _alertChannelId = 'lift_rest_timer';
  static const _alertChannelName = 'Rest Timer';
  static const _alertChannelDescription = 'Alert when your rest period is over';
  static const _notificationId = 0;

  static const _methodChannel = MethodChannel('com.slayernominee.lift/timer');

  bool _initialized = false;
  bool _permissionRequested = false;

  // ─── Initialisation ───────────────────────────────────────────────

  /// Initialises timezone data, the notification plugin, and the Android
  /// notification channel. Must be called once in `main()` before `runApp()`.
  Future<void> init() async {
    if (_initialized) return;

    // --- Timezone setup (required for zonedSchedule fallback) ---
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('NotificationService: timezone set to $timeZoneName');
    } catch (e) {
      debugPrint(
        'NotificationService: failed to detect timezone ($e), '
        'falling back to UTC',
      );
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {
        debugPrint('NotificationService: failed to set UTC fallback');
      }
    }

    // --- Plugin initialisation ---
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final result = await _plugin.initialize(initSettings);
    debugPrint('NotificationService: plugin initialized (result=$result)');

    // Create both notification channels to match TimerForegroundService.kt.
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Silent channel for the running countdown (no sound, no heads-up).
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _silentChannelId,
          'Rest Timer (silent)',
          description: 'Silent countdown while your rest timer is running',
          importance: Importance.low,
        ),
      );

      // Alert channel for the completion notification (sound + vibration).
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _alertChannelId,
          _alertChannelName,
          description: _alertChannelDescription,
          importance: Importance.high,
        ),
      );
      debugPrint('NotificationService: Android notification channels created');
    }

    _initialized = true;
  }

  // ─── Permissions ──────────────────────────────────────────────────

  /// Requests notification permissions from the OS.
  ///
  /// On Android 13+ this triggers the `POST_NOTIFICATIONS` runtime dialog.
  /// On iOS this triggers the standard notification permission prompt.
  Future<bool> requestPermissionsIfNeeded() async {
    if (_permissionRequested) return true;
    _permissionRequested = true;

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted =
            await androidPlugin?.requestNotificationsPermission() ?? false;
        debugPrint(
          'NotificationService: Android notification permission '
          'granted=$granted',
        );
        return granted;
      }
      if (Platform.isIOS) {
        final iosPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted =
            await iosPlugin?.requestPermissions(
              alert: true,
              badge: false,
              sound: true,
            ) ??
            false;
        debugPrint(
          'NotificationService: iOS notification permission '
          'granted=$granted',
        );
        return granted;
      }
    } catch (e) {
      debugPrint('NotificationService: permission request failed ($e)');
    }
    return true;
  }

  // ─── Scheduling ───────────────────────────────────────────────────

  /// Schedules a rest-timer notification to fire after [duration].
  ///
  /// **Primary**: starts the native foreground service on Android, which
  /// runs the countdown entirely in Kotlin, independent of the Dart
  /// isolate. Shows a live "1:30 remaining" notification and fires a
  /// completion notification with sound + vibration.
  ///
  /// **Secondary**: also schedules a `zonedSchedule` alarm as a fallback
  /// for non-Android platforms or cases where the foreground service
  /// cannot be started.
  Future<void> scheduleRestTimerNotification(Duration duration) async {
    if (!_initialized) {
      debugPrint(
        'NotificationService: tried to schedule but service not initialized',
      );
      return;
    }

    // Always cancel any previous alarm first.
    await _cancelInternal();

    final permGranted = await requestPermissionsIfNeeded();
    if (!permGranted) {
      debugPrint(
        'NotificationService: notification permission not granted, '
        'skipping schedule',
      );
      return;
    }

    // ── Strategy 1: Native foreground service (Android only) ────────
    if (Platform.isAndroid) {
      final started = await _startForegroundService(duration);
      if (started) return; // foreground service handles everything
    }

    // ── Strategy 2: OS-level alarm (iOS / Android fallback) ─────────
    await _scheduleOsAlarm(duration);
  }

  // ─── Native foreground service ────────────────────────────────────

  /// Starts the native [TimerForegroundService] via MethodChannel.
  /// Returns `true` if the service started successfully.
  Future<bool> _startForegroundService(Duration duration) async {
    try {
      debugPrint(
        'NotificationService: starting foreground service '
        '(${duration.inSeconds}s)',
      );
      await _methodChannel.invokeMethod<void>('startTimer', {
        'durationSeconds': duration.inSeconds,
      });
      debugPrint('NotificationService: foreground service started');
      return true;
    } catch (e, stack) {
      debugPrint(
        'NotificationService: foreground service failed, '
        'will rely on OS alarm fallback\n$e\n$stack',
      );
      return false;
    }
  }

  /// Stops the native [TimerForegroundService] via MethodChannel.
  Future<void> _stopForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('stopTimer');
      debugPrint('NotificationService: foreground service stopped');
    } catch (e) {
      debugPrint('NotificationService: foreground service stop failed ($e)');
    }
  }

  // ─── OS alarm fallback ────────────────────────────────────────────

  /// Schedules the OS-level alarm via `zonedSchedule`.
  Future<void> _scheduleOsAlarm(Duration duration) async {
    try {
      final canExact = await _canScheduleExact();
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final scheduledDate = tz.TZDateTime.now(tz.local).add(duration);
      debugPrint(
        'NotificationService: OS alarm at $scheduledDate '
        '(in ${duration.inSeconds}s, tz=${tz.local.name}, mode=$mode)',
      );

      await _plugin.zonedSchedule(
        _notificationId,
        'Rest Timer Complete',
        'Time to get back to lifting! 💪',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('NotificationService: OS alarm scheduled');
    } catch (e, stack) {
      debugPrint('NotificationService: OS alarm failed\n$e\n$stack');
    }
  }

  /// Checks whether the app can schedule exact alarms on Android 12+.
  Future<bool> _canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('NotificationService: canScheduleExact check failed ($e)');
      return false;
    }
  }

  // ─── Cancellation ─────────────────────────────────────────────────

  /// Cancels the pending rest-timer notification and stops the foreground
  /// service.
  ///
  /// Called when:
  /// - The user manually stops the timer.
  /// - The timer expires while the app is in the foreground.
  /// - A new timer is started (replaces the previous one).
  Future<void> cancelRestTimerNotification() async {
    await _cancelInternal();
  }

  Future<void> _cancelInternal() async {
    // Stop native foreground service
    await _stopForegroundService();

    // Cancel OS alarm fallback + both foreground-service notification IDs
    if (!_initialized) return;
    try {
      await _plugin.cancel(_notificationId); // zonedSchedule fallback (0)
      await _plugin.cancel(10); // native running countdown
      await _plugin.cancel(11); // native completion alert
    } catch (e) {
      debugPrint('NotificationService: cancel failed ($e)');
    }
  }

  /// Called when the app returns to the foreground.
  ///
  /// Dismisses the completion notification (ID 11) because the user has
  /// now opened the app. The silent running notification (ID 10) is also
  /// cancelled as a safety net.
  Future<void> dismissCompletionNotification() async {
    if (!Platform.isAndroid || !_initialized) return;
    try {
      await _plugin.cancel(10);
      await _plugin.cancel(11);
    } catch (e) {
      debugPrint('NotificationService: dismiss completion failed ($e)');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Notification details for the completion alert (used by zonedSchedule
  /// fallback).  Posts to the alert channel so it plays sound + vibration.
  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        channelDescription: _alertChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    );
  }
}
