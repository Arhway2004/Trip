import 'package:timezone/timezone.dart' as tz;

import 'package:wanderplan/shared/domain/local_date.dart';

/// Result of evaluating a trip's schedule against "now".
sealed class CountdownState {
  const CountdownState();
}

/// Dates are not set yet.
class CountdownNoDate extends CountdownState {
  const CountdownNoDate();
}

class CountdownBeforeDeparture extends CountdownState {
  const CountdownBeforeDeparture({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.hasDepartureTime,
  });

  /// When no departure time is set, [days] is the number of calendar days
  /// until the start date (in the trip time zone) and hours/minutes are 0.
  final int days;
  final int hours;
  final int minutes;
  final bool hasDepartureTime;
}

class CountdownDuringTrip extends CountdownState {
  const CountdownDuringTrip({required this.dayNumber, required this.totalDays});
  final int dayNumber;
  final int totalDays;
}

class CountdownCompleted extends CountdownState {
  const CountdownCompleted();
}

/// Resolves IANA names, falling back to UTC for unknown identifiers so a bad
/// value can never crash the UI.
tz.Location resolveLocation(String name) {
  try {
    return tz.getLocation(name);
  } catch (_) {
    return tz.UTC;
  }
}

/// Today's calendar date in [timeZone].
LocalDate todayIn(String timeZone, DateTime now) {
  final local = tz.TZDateTime.from(now, resolveLocation(timeZone));
  return LocalDate(local.year, local.month, local.day);
}

/// Computes the countdown for a trip. All comparisons happen in the trip's
/// time zone, and the result never contains negative values.
CountdownState computeCountdown({
  required LocalDate? start,
  required LocalDate? end,
  required String? departureTime,
  required String timeZone,
  required DateTime now,
}) {
  if (start == null) return const CountdownNoDate();
  final last = (end == null || end < start) ? start : end;
  final loc = resolveLocation(timeZone);
  final nowTz = tz.TZDateTime.from(now, loc);
  final today = LocalDate(nowTz.year, nowTz.month, nowTz.day);

  if (today > last) return const CountdownCompleted();

  final time = parseTimeOfDay(departureTime);
  final departure = tz.TZDateTime(loc, start.year, start.month, start.day, time?.$1 ?? 0, time?.$2 ?? 0);

  if (nowTz.isBefore(departure)) {
    if (time == null) {
      return CountdownBeforeDeparture(days: today.daysUntil(start), hours: 0, minutes: 0, hasDepartureTime: false);
    }
    final diff = departure.difference(nowTz);
    // Round up to the next whole minute so "0 minutes" only shows at departure.
    final totalMinutes = (diff.inSeconds + 59) ~/ 60;
    return CountdownBeforeDeparture(
      days: totalMinutes ~/ (24 * 60),
      hours: (totalMinutes ~/ 60) % 24,
      minutes: totalMinutes % 60,
      hasDepartureTime: true,
    );
  }

  final total = start.daysUntil(last) + 1;
  final day = (start.daysUntil(today) + 1).clamp(1, total);
  return CountdownDuringTrip(dayNumber: day, totalDays: total);
}

/// Minutes since midnight right now in [timeZone].
int minuteOfDayIn(String timeZone, DateTime now) {
  final local = tz.TZDateTime.from(now, resolveLocation(timeZone));
  return local.hour * 60 + local.minute;
}
