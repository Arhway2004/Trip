import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/feasibility.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

extension ActivityKindUi on ActivityKind {
  String label(AppLocalizations l) => switch (this) {
    ActivityKind.sightseeing => l.kindSightseeing,
    ActivityKind.food => l.kindFood,
    ActivityKind.activity => l.kindActivity,
    ActivityKind.shopping => l.kindShopping,
    ActivityKind.rest => l.kindRest,
    ActivityKind.flight => l.kindFlight,
    ActivityKind.train => l.kindTrain,
    ActivityKind.bus => l.kindBus,
    ActivityKind.transfer => l.kindTransfer,
    ActivityKind.ferry => l.kindFerry,
    ActivityKind.transport => l.kindTransport,
    ActivityKind.hotel => l.kindHotel,
    ActivityKind.other => l.kindOther,
  };

  IconData get icon => switch (this) {
    ActivityKind.sightseeing => Icons.photo_camera_outlined,
    ActivityKind.food => Icons.restaurant_outlined,
    ActivityKind.activity => Icons.local_activity_outlined,
    ActivityKind.shopping => Icons.shopping_bag_outlined,
    ActivityKind.rest => Icons.self_improvement,
    ActivityKind.flight => Icons.flight,
    ActivityKind.train => Icons.train_outlined,
    ActivityKind.bus => Icons.directions_bus_outlined,
    ActivityKind.transfer => Icons.local_taxi_outlined,
    ActivityKind.ferry => Icons.directions_boat_outlined,
    ActivityKind.transport => Icons.alt_route,
    ActivityKind.hotel => Icons.hotel_outlined,
    ActivityKind.other => Icons.more_horiz,
  };

  /// Distinct, readable hues for timeline blocks and map pins.
  Color get color => switch (this) {
    ActivityKind.sightseeing => const Color(0xFF0E7C6B),
    ActivityKind.food => const Color(0xFFC4502B),
    ActivityKind.activity => const Color(0xFF7C3AED),
    ActivityKind.shopping => const Color(0xFFBE185D),
    ActivityKind.rest => const Color(0xFF64748B),
    ActivityKind.flight => const Color(0xFF2A5FB0),
    ActivityKind.train => const Color(0xFFB45309),
    ActivityKind.bus || ActivityKind.ferry => const Color(0xFF0369A1),
    ActivityKind.transfer => const Color(0xFF4D7C0F),
    ActivityKind.transport => const Color(0xFF0F766E),
    ActivityKind.hotel => const Color(0xFF6D28D9),
    ActivityKind.other => const Color(0xFF475569),
  };
}

extension BookingStatusUi on BookingStatus {
  String label(AppLocalizations l) => switch (this) {
    BookingStatus.notBooked => l.bookingNotBooked,
    BookingStatus.booked => l.bookingBooked,
    BookingStatus.confirmed => l.bookingConfirmed,
    BookingStatus.cancelled => l.bookingCancelled,
  };

  Tone get tone => switch (this) {
    BookingStatus.notBooked => Tone.warn,
    BookingStatus.booked => Tone.info,
    BookingStatus.confirmed => Tone.good,
    BookingStatus.cancelled => Tone.bad,
  };
}

extension DayStatusUi on DayStatus {
  String label(AppLocalizations l) => switch (this) {
    DayStatus.feasible => l.dayFeasible,
    DayStatus.tight => l.dayTight,
    DayStatus.unrealistic => l.dayUnrealistic,
    DayStatus.unknown => l.dayUnknown,
    DayStatus.empty => l.dayEmpty,
  };

  Tone get tone => switch (this) {
    DayStatus.feasible => Tone.good,
    DayStatus.tight => Tone.warn,
    DayStatus.unrealistic => Tone.bad,
    DayStatus.unknown => Tone.info,
    DayStatus.empty => Tone.neutral,
  };

  IconData get icon => switch (this) {
    DayStatus.feasible => Icons.check_circle_outline,
    DayStatus.tight => Icons.warning_amber_rounded,
    DayStatus.unrealistic => Icons.error_outline,
    DayStatus.unknown => Icons.help_outline,
    DayStatus.empty => Icons.wb_sunny_outlined,
  };
}

extension IssueSeverityUi on IssueSeverity {
  Tone get tone => switch (this) {
    IssueSeverity.info => Tone.info,
    IssueSeverity.warning => Tone.warn,
    IssueSeverity.error => Tone.bad,
  };
}

String _hours(int minutes) => (minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1);

String issueText(AppLocalizations l, ScheduleIssue i) {
  String t(int n) => i.titles.length > n ? i.titles[n] : '';
  return switch (i.code) {
    IssueCode.overlap => l.issueOverlap(t(0), t(1), i.minutes ?? 0),
    IssueCode.noTravelTime => l.issueNoTravelTime(t(0), t(1)),
    IssueCode.tightTravel when i.distanceKm == null => l.issueTightTravelOwn(t(0), t(1), i.minutes ?? 0, i.requiredMinutes ?? 0),
    IssueCode.tightTravel => l.issueTightTravel(
      t(0),
      t(1),
      (i.distanceKm ?? 0).toStringAsFixed(1),
      i.minutes ?? 0,
      i.requiredMinutes ?? 0,
    ),
    IssueCode.departureBuffer => l.issueDepartureBuffer(t(1), i.minutes ?? 0, i.requiredMinutes ?? 0),
    IssueCode.longDay => l.issueLongDay(_hours(i.minutes ?? 0)),
    IssueCode.earlyAndLate => l.issueEarlyAndLate(_hours(i.minutes ?? 0)),
    IssueCode.noMealBreak => l.issueNoMealBreak,
    IssueCode.lateFinish => l.issueLateFinish,
    IssueCode.missingAccommodation => l.issueMissingAccommodation,
    IssueCode.overlappingStays => l.issueOverlappingStays(i.titles.join(', ')),
    IssueCode.transportNotBooked => l.issueTransportNotBooked(i.titles.join(', ')),
    IssueCode.outsideTripDates => l.issueOutsideTripDates(i.titles.join(', ')),
    IssueCode.timeNotSet => l.issueTimeNotSet(i.titles.join(', ')),
    IssueCode.closedOnDay => l.issueClosedOnDay(t(0)),
    IssueCode.outsideOpeningHours => l.issueOutsideOpeningHours(t(0)),
    IssueCode.bookingNeeded when i.date != null => l.issueBookBy(
      t(0),
      DateFormat.MMMd(l.localeName).format(i.date!.toDateTime()),
    ),
    IssueCode.bookingNeeded => l.issueBookingNeeded(t(0)),
  };
}

String formatDuration(AppLocalizations l, int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return l.durationM(m);
  if (m == 0) return l.durationH(h);
  return l.durationHm(h, m);
}

/// "08:30–12:45", or "Time TBD" for activities without a decided time.
String activityTimeText(AppLocalizations l, Activity a) => a.hasTime
    ? '${formatMinutes(a.startMinute!)}–${a.endMinute == 24 * 60 ? '24:00' : formatMinutes(a.endMinute!)}'
    : l.timeTbd;
