import 'package:timezone/timezone.dart' as tz;
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity_repository.dart';
import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/domain/clock.dart';

/// A phone notification to show at [at] (UTC).
class Reminder {
  const Reminder({required this.id, required this.tripId, required this.at, required this.title, required this.body});
  final int id;
  final String tripId;
  final DateTime at;
  final String title;
  final String body;
}

/// Port for local (on-device) notifications.
abstract interface class ReminderScheduler {
  /// Asks the OS for permission; false when the user refuses.
  Future<bool> requestPermission();
  Future<void> schedule(Reminder r);

  /// Shows a notification right away (e.g. a flight was delayed).
  Future<void> showNow(Reminder r);
  Future<void> cancel(int id);

  /// IDs of reminders already scheduled for [tripId].
  Future<List<int>> scheduledFor(String tripId);
}

/// Hour (trip time zone) at which booking reminders fire.
const bookingReminderHour = 9;

/// Keeps "book this N days before" reminders in step with the plan: one
/// notification per activity that still needs booking, at 09:00 (trip time)
/// on its book-by date. Past dates are never scheduled.
class BookingReminderService {
  BookingReminderService({
    required ActivityRepository activities,
    required TripRepository trips,
    required ReminderScheduler scheduler,
    required Clock clock,
  }) : _activities = activities,
       _trips = trips,
       _scheduler = scheduler,
       _clock = clock;

  final ActivityRepository _activities;
  final TripRepository _trips;
  final ReminderScheduler _scheduler;
  final Clock _clock;

  Future<bool> requestPermission() => _scheduler.requestPermission();

  /// Stable notification ID for an activity (31-bit FNV-1a of its ID).
  static int reminderId(String activityId) {
    var h = 0x811c9dc5;
    for (final c in activityId.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }

  /// When [a]'s reminder should fire (UTC), or null when none is due.
  static DateTime? reminderTime(Activity a, String timeZone) {
    final by = a.bookBy;
    if (!a.remindToBook || !a.needsBooking || a.isCancelled || by == null) return null;
    tz.Location loc;
    try {
      loc = tz.getLocation(timeZone);
    } catch (_) {
      loc = tz.UTC;
    }
    return tz.TZDateTime(loc, by.year, by.month, by.day, bookingReminderHour).toUtc();
  }

  /// Re-schedules every booking reminder of [tripId]; returns how many are set.
  Future<int> syncTrip(
    String tripId, {
    required String Function(Activity) title,
    required String Function(Activity) body,
  }) async {
    final trip = await _trips.findById(tripId);
    final now = _clock().toUtc();
    final wanted = <int, Reminder>{};
    if (trip != null) {
      for (final a in await _activities.findByTrip(tripId)) {
        final at = reminderTime(a, trip.timeZone);
        if (at == null || !at.isAfter(now)) continue;
        final id = reminderId(a.id);
        wanted[id] = Reminder(id: id, tripId: tripId, at: at, title: title(a), body: body(a));
      }
    }
    for (final id in await _scheduler.scheduledFor(tripId)) {
      if (!wanted.containsKey(id)) await _scheduler.cancel(id);
    }
    for (final r in wanted.values) {
      await _scheduler.schedule(r);
    }
    return wanted.length;
  }
}
