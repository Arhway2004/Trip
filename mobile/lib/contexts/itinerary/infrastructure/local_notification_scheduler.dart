import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:wanderplan/contexts/itinerary/application/booking_reminders.dart';

/// On-device notifications (no server). Scheduled with inexact alarms, so a
/// reminder may arrive a few minutes late on Android; no special permission.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const _updates = AndroidNotificationDetails(
    'flight_updates',
    'Flight updates',
    channelDescription: 'Delays, gate changes and cancellations of your booked flights',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _channel = AndroidNotificationDetails(
    'booking_reminders',
    'Booking reminders',
    channelDescription: 'Reminders to book tickets and reservations before your trip',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> _init() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // Permission is asked when the user turns a reminder on, not at start-up.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  @override
  Future<void> schedule(Reminder r) async {
    await _init();
    await _plugin.zonedSchedule(
      id: r.id,
      scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
      notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: r.title,
      body: r.body,
      payload: r.tripId,
    );
  }

  @override
  Future<void> showNow(Reminder r) async {
    await _init();
    await _plugin.show(
      id: r.id,
      title: r.title,
      body: r.body,
      notificationDetails: const NotificationDetails(android: _updates, iOS: DarwinNotificationDetails()),
      payload: 'flight:${r.tripId}',
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<List<int>> scheduledFor(String tripId) async {
    await _init();
    return [
      for (final p in await _plugin.pendingNotificationRequests())
        if (p.payload == tripId) p.id,
    ];
  }
}
