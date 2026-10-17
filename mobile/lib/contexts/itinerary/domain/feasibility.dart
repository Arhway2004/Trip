import 'package:wanderplan/shared/domain/local_date.dart';

import 'activity.dart';

enum DayStatus { feasible, tight, unrealistic, unknown, empty }

enum IssueSeverity { info, warning, error }

enum IssueCode {
  overlap,
  noTravelTime,
  tightTravel,
  departureBuffer,
  longDay,
  earlyAndLate,
  noMealBreak,
  lateFinish,
  missingAccommodation,
  overlappingStays,
  transportNotBooked,
  outsideTripDates,
  timeNotSet,
}

/// A specific finding with the data needed to explain it.
class ScheduleIssue {
  const ScheduleIssue(
    this.code,
    this.severity, {
    this.activityIds = const [],
    this.titles = const [],
    this.minutes,
    this.requiredMinutes,
    this.distanceKm,
  });

  final IssueCode code;
  final IssueSeverity severity;
  final List<String> activityIds;

  /// Titles of the involved activities, for messages.
  final List<String> titles;
  final int? minutes;
  final int? requiredMinutes;
  final double? distanceKm;
}

class DayAssessment {
  const DayAssessment(this.date, this.status, this.issues, this.activities);
  final LocalDate date;
  final DayStatus status;
  final List<ScheduleIssue> issues;

  /// Activities touching this day, chronologically (stays included).
  final List<Activity> activities;
}

/// Rules of thumb used by the analyzer. They are planning estimates, not
/// routing results, and are labelled as such in the UI.
abstract final class FeasibilityRules {
  /// Assumed door-to-door speed for a straight-line distance when no route is known.
  static const assumedSpeedKmh = 25.0;
  static const transferOverheadMinutes = 10;
  static const longDayMinutes = 13 * 60;
  static const earlyStartMinute = 6 * 60;
  static const lateEndMinute = 22 * 60;
  static const lateFinishMinute = 23 * 60;
  static const lunchStart = 12 * 60, lunchEnd = 13 * 60 + 30;
}

/// Assesses every day of a trip. Days outside the trip dates that still have
/// activities are included so nothing is silently hidden.
List<DayAssessment> assessItinerary({required List<Activity> activities, LocalDate? tripStart, LocalDate? tripEnd}) {
  final live = activities.where((a) => !a.isCancelled).toList()..sort(compareActivities);
  final days = <LocalDate>{
    if (tripStart != null) ...tripStart.through(tripEnd ?? tripStart),
    for (final a in live) ...a.date.through(a.lastDate),
  }.toList()..sort();

  final nightsCovered = <LocalDate, List<Activity>>{};
  for (final s in live.where((a) => a.kind.isStay)) {
    for (final n in s.nights) {
      (nightsCovered[n] ??= []).add(s);
    }
  }

  return [
    for (final day in days)
      _assessDay(
        day,
        live
            .where(
              (a) =>
                  a.spanOn(day) != null ||
                  (a.kind.isStay && a.date == day) ||
                  // Untimed activities still belong to their date(s).
                  (!a.hasTime && !a.kind.isStay && day >= a.date && day <= a.lastDate),
            )
            .toList(),
        nightsCovered,
        tripStart: tripStart,
        tripEnd: tripEnd ?? tripStart,
      ),
  ];
}

DayAssessment _assessDay(
  LocalDate day,
  List<Activity> dayActs,
  Map<LocalDate, List<Activity>> nightsCovered, {
  LocalDate? tripStart,
  LocalDate? tripEnd,
}) {
  final issues = <ScheduleIssue>[];
  // Only activities with a known time take part in overlap/gap/buffer checks.
  final scheduled = dayActs.where((a) => !a.kind.isStay && a.hasTime).toList();

  // Outside the trip's dates.
  if (tripStart != null && (day < tripStart || day > tripEnd!)) {
    final starting = dayActs.where((a) => a.date == day).toList();
    if (starting.isNotEmpty) {
      issues.add(
        ScheduleIssue(
          IssueCode.outsideTripDates,
          IssueSeverity.warning,
          activityIds: [for (final a in starting) a.id],
          titles: [for (final a in starting) a.title],
        ),
      );
    }
  }

  // Overlaps between scheduled (non-stay) activities.
  for (var i = 0; i < scheduled.length; i++) {
    for (var j = i + 1; j < scheduled.length; j++) {
      final a = scheduled[i], b = scheduled[j];
      if (b.startAbsolute >= a.endAbsolute) continue;
      final overlap = (a.endAbsolute < b.endAbsolute ? a.endAbsolute : b.endAbsolute) - b.startAbsolute;
      issues.add(
        ScheduleIssue(
          IssueCode.overlap,
          a.isOptional || b.isOptional ? IssueSeverity.warning : IssueSeverity.error,
          activityIds: [a.id, b.id],
          titles: [a.title, b.title],
          minutes: overlap,
        ),
      );
    }
  }

  // Consecutive activities: travel time and departure buffers.
  for (var i = 0; i + 1 < scheduled.length; i++) {
    final a = scheduled[i], b = scheduled[i + 1];
    final gap = b.startAbsolute - a.endAbsolute;
    if (gap < 0) continue; // already reported as overlap
    if (b.date != day) continue; // only report on the day the next activity starts

    final buffer = b.kind.recommendedBufferMinutes;
    if (buffer > 0 && gap < buffer) {
      issues.add(
        ScheduleIssue(
          IssueCode.departureBuffer,
          IssueSeverity.warning,
          activityIds: [a.id, b.id],
          titles: [a.title, b.title],
          minutes: gap,
          requiredMinutes: buffer,
        ),
      );
      continue;
    }

    final from = a.endPlace, to = b.location;
    if (from.isEmpty || to.isEmpty || from.sameAs(to) || a.kind.isTransport && b.kind.isTransport) continue;
    if (from.point != null && to.point != null) {
      final km = from.point!.distanceKmTo(to.point!);
      final needed = (km / FeasibilityRules.assumedSpeedKmh * 60).round() + FeasibilityRules.transferOverheadMinutes;
      if (gap < needed && !b.kind.isTransport) {
        issues.add(
          ScheduleIssue(
            gap == 0 ? IssueCode.noTravelTime : IssueCode.tightTravel,
            gap == 0 ? IssueSeverity.warning : IssueSeverity.warning,
            activityIds: [a.id, b.id],
            titles: [a.title, b.title],
            minutes: gap,
            requiredMinutes: needed,
            distanceKm: km,
          ),
        );
      }
    } else if (gap == 0 && !b.kind.isTransport) {
      issues.add(
        ScheduleIssue(
          IssueCode.noTravelTime,
          IssueSeverity.warning,
          activityIds: [a.id, b.id],
          titles: [a.title, b.title],
          minutes: 0,
        ),
      );
    }
  }

  // Day load.
  if (scheduled.isNotEmpty) {
    final spans = [for (final a in scheduled) a.spanOn(day)].whereType<(int, int)>().toList();
    final busy = scheduled
        .where((a) => a.kind != ActivityKind.rest)
        .map((a) => a.spanOn(day))
        .whereType<(int, int)>()
        .fold<int>(0, (s, x) => s + x.$2 - x.$1);
    if (busy > FeasibilityRules.longDayMinutes) {
      issues.add(ScheduleIssue(IssueCode.longDay, IssueSeverity.warning, minutes: busy));
    }
    if (spans.isNotEmpty) {
      final first = spans.map((s) => s.$1).reduce((a, b) => a < b ? a : b);
      final last = spans.map((s) => s.$2).reduce((a, b) => a > b ? a : b);
      if (first < FeasibilityRules.earlyStartMinute && last > FeasibilityRules.lateEndMinute) {
        issues.add(ScheduleIssue(IssueCode.earlyAndLate, IssueSeverity.warning, minutes: last - first));
      } else if (last > FeasibilityRules.lateFinishMinute) {
        issues.add(const ScheduleIssue(IssueCode.lateFinish, IssueSeverity.info));
      }
      final coversLunch = first <= FeasibilityRules.lunchStart && last >= FeasibilityRules.lunchEnd;
      if (coversLunch && !scheduled.any((a) => a.kind == ActivityKind.food || a.kind == ActivityKind.rest)) {
        issues.add(const ScheduleIssue(IssueCode.noMealBreak, IssueSeverity.info));
      }
    }
  }

  // Accommodation for the night after this day (not on the trip's last day).
  final isNight = tripStart != null && day >= tripStart && day < tripEnd!;
  final stays = nightsCovered[day] ?? const [];
  if (isNight && stays.isEmpty) {
    issues.add(const ScheduleIssue(IssueCode.missingAccommodation, IssueSeverity.warning));
  } else if (stays.length > 1) {
    issues.add(
      ScheduleIssue(
        IssueCode.overlappingStays,
        IssueSeverity.warning,
        activityIds: [for (final s in stays) s.id],
        titles: [for (final s in stays) s.title],
      ),
    );
  }

  // Critical transport that isn't booked yet.
  final unbooked = dayActs
      .where(
        (a) =>
            a.date == day &&
            (a.kind == ActivityKind.flight || a.kind == ActivityKind.train) &&
            a.bookingStatus == BookingStatus.notBooked,
      )
      .toList();
  if (unbooked.isNotEmpty) {
    issues.add(
      ScheduleIssue(
        IssueCode.transportNotBooked,
        IssueSeverity.info,
        activityIds: [for (final a in unbooked) a.id],
        titles: [for (final a in unbooked) a.title],
      ),
    );
  }

  // Activities without a decided time: listed, never guessed.
  final untimed = dayActs.where((a) => !a.kind.isStay && !a.hasTime && a.date == day).toList();
  if (untimed.isNotEmpty) {
    issues.add(
      ScheduleIssue(
        IssueCode.timeNotSet,
        IssueSeverity.info,
        activityIds: [for (final a in untimed) a.id],
        titles: [for (final a in untimed) a.title],
      ),
    );
  }

  final status = switch (issues) {
    _ when dayActs.isEmpty && issues.every((i) => i.code == IssueCode.missingAccommodation) => DayStatus.empty,
    _ when issues.any((i) => i.severity == IssueSeverity.error) => DayStatus.unrealistic,
    _ when issues.any((i) => i.severity == IssueSeverity.warning) => DayStatus.tight,
    // Never call a day feasible while its key transport is unconfirmed.
    _ when unbooked.isNotEmpty || untimed.any((a) => !a.isOptional) => DayStatus.unknown,
    _ => DayStatus.feasible,
  };
  return DayAssessment(day, status, issues, dayActs);
}
