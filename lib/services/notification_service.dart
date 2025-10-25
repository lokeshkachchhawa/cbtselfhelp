// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'reminder_service.dart';

final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();

class NotificationService {
  NotificationService._private();
  static final NotificationService _instance = NotificationService._private();
  factory NotificationService() => _instance;

  /// Call once at app startup (after timezone DB init). Example usage shown below.
  Future<void> init() async {
    // Android init
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS (Darwin) init
    const ios = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
      requestBadgePermission: true,
    );

    const initSettings = InitializationSettings(android: android, iOS: ios);

    await _flnp.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        // handle taps (payload: resp.payload)
        // TODO: route to appropriate screen if needed
      },
    );
  }

  /// Request platform permissions (call at an appropriate UX moment, e.g. when user first creates a reminder)
  Future<void> requestPermissions() async {
    // Android 13+ runtime permission
    final androidImpl = _flnp
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission(); // <-- NEW name

    // iOS / macOS (Darwin) permission request
    final iosImpl = _flnp
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<NotificationDetails> _platformChannelSpecifics() async {
    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'Reminders for activities',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Schedule a reminder using timezone-aware zonedSchedule
  /// Uses AndroidScheduleMode.exactAllowWhileIdle for best fidelity (may require exact alarms permission on Android).
  Future<void> scheduleReminder(Reminder r) async {
    final details = await _platformChannelSpecifics();

    // Convert local DateTime into tz-aware object (tz.local must be set in main)
    final tzScheduled = tz.TZDateTime.from(r.scheduledAt, tz.local);

    final baseId = r.id.hashCode;

    if (r.recurrence == ReminderRecurrence.none) {
      // one-time
      await _flnp.zonedSchedule(
        baseId,
        r.title,
        r.body,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: r.id,
      );
    } else if (r.recurrence == ReminderRecurrence.daily) {
      final next = _nextInstanceOfTime(r.scheduledAt);
      await _flnp.zonedSchedule(
        baseId,
        r.title,
        r.body,
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: r.id,
      );
    } else if (r.recurrence == ReminderRecurrence.weekly) {
      final next = _nextInstanceOfWeekdayAndTime(
        r.scheduledAt.weekday,
        r.scheduledAt,
      );
      await _flnp.zonedSchedule(
        baseId,
        r.title,
        r.body,
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: r.id,
      );
    } else if (r.recurrence == ReminderRecurrence.weekdays) {
      // mon–fri: schedule separate notifications (each uses dayOfWeekAndTime)
      for (final weekday in [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ]) {
        final id = ('${r.id}_wd$weekday').hashCode;
        final dt = _nextInstanceOfWeekdayAndTime(weekday, r.scheduledAt);
        await _flnp.zonedSchedule(
          id,
          r.title,
          r.body,
          dt,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: r.id,
        );
      }
    }
  }

  /// Cancel a reminder and any weekday variants
  Future<void> cancelReminder(Reminder r) async {
    await _flnp.cancel(r.id.hashCode);
    for (final weekday in [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ]) {
      await _flnp.cancel(('${r.id}_wd$weekday').hashCode);
    }
  }

  Future<void> cancelByIdString(String idString) async {
    await _flnp.cancel(idString.hashCode);
  }

  Future<void> cancelAll() => _flnp.cancelAll();

  // Helpers - compute next instance (tz-aware)
  tz.TZDateTime _nextInstanceOfTime(DateTime dt) {
    final tzNow = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      tzNow.year,
      tzNow.month,
      tzNow.day,
      dt.hour,
      dt.minute,
      dt.second,
    );
    if (scheduled.isBefore(tzNow)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int weekday, DateTime dt) {
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      tz.TZDateTime.now(tz.local).year,
      tz.TZDateTime.now(tz.local).month,
      tz.TZDateTime.now(tz.local).day,
      dt.hour,
      dt.minute,
      dt.second,
    );

    while (scheduled.weekday != weekday ||
        scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
