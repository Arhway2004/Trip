import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_settings.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// Where a day starts or ends.
enum DayAnchor { start, end }

/// A located stop on one day's route.
class DayStop {
  const DayStop(this.activity, this.point, this.label, {this.isArrival = false, this.anchor});

  /// Null for a start/end point the traveller set that isn't an activity.
  final Activity? activity;

  /// WGS84.
  final GeoPoint point;
  final String? label;

  /// The arrival end of a transport activity.
  final bool isArrival;

  /// Set when this stop is the day's start or end point.
  final DayAnchor? anchor;
}

enum DayLegKind {
  /// Travel between two stops, by the leg's mode (routed unless transit).
  road,

  /// A booked flight, train or ferry: drawn as a direct line, never as a road route.
  booked,

  /// A transport activity whose mode isn't decided: it can't be routed.
  undecided,
}

/// The way between two consecutive stops.
class DayLeg {
  const DayLeg(this.from, this.to, this.kind, {this.fixedMode, this.chosenMode, this.manualMinutes});
  final DayStop from;
  final DayStop to;
  final DayLegKind kind;

  /// Set when the itinerary fixes how this leg is travelled (a bus or taxi
  /// transfer goes by road).
  final TravelMode? fixedMode;

  /// The traveller's choice for this leg (stored on the next stop).
  final TravelMode? chosenMode;

  /// The traveller's own travel-time estimate for this leg.
  final int? manualMinutes;

  TravelMode mode(TravelMode dayDefault) => fixedMode ?? chosenMode ?? dayDefault;

  /// Minutes between leaving [from] and the planned start of [to] on [day],
  /// when both are timed activities; null when there's no fixed time window.
  int? availableMinutes(LocalDate day) {
    final a = from.activity, b = to.activity;
    if (a == null || b == null || to.anchor != null || from.anchor == DayAnchor.start) return null;
    final leave = a.spanOn(day)?.$2;
    final arrive = b.spanOn(day)?.$1;
    if (leave == null || arrive == null) return null;
    return arrive - leave;
  }

  /// The transport activity this leg belongs to, if any.
  Activity? get transport {
    final a = from.activity;
    return a != null && a == to.activity && a.kind.isTransport ? a : null;
  }
}

/// One day's route, built only from what the plan says. Nothing is reordered
/// or guessed: activities without a time can't be placed in the sequence, so
/// they are listed separately rather than slotted in.
class DayRoutePlan {
  const DayRoutePlan({required this.stops, required this.legs, required this.unordered, required this.missingLocation});

  /// In time order, from the day's start point to its end point when known.
  final List<DayStop> stops;
  final List<DayLeg> legs;

  /// Located activities on this day without a time (shown, but not routed).
  final List<DayStop> unordered;

  /// Activities on this day that have no coordinates yet.
  final List<Activity> missingLocation;

  DayStop? get start => stops.where((s) => s.anchor == DayAnchor.start).firstOrNull;
  DayStop? get end => stops.where((s) => s.anchor == DayAnchor.end).firstOrNull;
}

/// Stops closer than this are treated as the same place.
const _sameStopKm = 0.05;

/// Whether [a] belongs on [day] (timed overlap, untimed date range, or a hotel
/// stay from check-in to check-out).
bool activityOccursOn(Activity a, LocalDate day) {
  if (a.isCancelled) return false;
  if (a.kind.isStay || !a.hasTime) return a.date <= day && day <= a.lastDate;
  return a.spanOn(day) != null;
}

/// Last night's hotel (the default start) and tonight's (the default end).
(Activity?, Activity?) defaultDayAnchors(List<Activity> activities, LocalDate day) {
  final stays = activities.where((a) => a.kind.isStay && !a.isCancelled && a.location.point != null);
  return (
    stays.where((h) => h.date < day && day <= h.lastDate).firstOrNull,
    stays.where((h) => h.date <= day && day < h.lastDate).firstOrNull,
  );
}

DayRoutePlan planDayRoute(List<Activity> activities, LocalDate day, {DaySettings? settings}) {
  final live = activities.where((a) => activityOccursOn(a, day)).toList()..sort(compareActivities);
  final unordered = <DayStop>[];
  final missing = <Activity>[];
  // Every stop in order; consecutive stops at the same spot (a taxi arriving
  // where the train departs) are merged for display but keep their legs right.
  final sequence = <DayStop>[];

  for (final h in live.where((a) => a.kind.isStay)) {
    if (h.location.point == null) missing.add(h);
  }
  final (lastNight, tonight) = defaultDayAnchors(live, day);

  // Morning: the chosen start point, else wake up at last night's hotel.
  if (settings?.start.point case final p?) {
    sequence.add(DayStop(null, p, settings!.start.name, anchor: DayAnchor.start));
  } else if (lastNight != null) {
    sequence.add(DayStop(lastNight, lastNight.location.point!, lastNight.location.name, anchor: DayAnchor.start));
  }

  for (final a in live.where((a) => !a.kind.isStay)) {
    final hasPoint = a.location.point != null || (a.kind.isTransport && a.destination.point != null);
    if (!hasPoint) {
      missing.add(a);
      continue;
    }
    if (!a.hasTime) {
      if (a.location.point != null) unordered.add(DayStop(a, a.location.point!, a.location.name));
      if (a.kind.isTransport && a.destination.point != null) {
        unordered.add(DayStop(a, a.destination.point!, a.destination.name, isArrival: true));
      }
      continue;
    }
    // A journey spanning midnight departs on its first day and arrives on its last.
    if (a.location.point != null && a.date == day) sequence.add(DayStop(a, a.location.point!, a.location.name));
    if (a.kind.isTransport && a.destination.point != null && a.lastDate == day) {
      sequence.add(DayStop(a, a.destination.point!, a.destination.name, isArrival: true));
    }
  }

  // Evening: the chosen end point, else tonight's hotel.
  if (settings?.end.point case final p?) {
    sequence.add(DayStop(null, p, settings!.end.name, anchor: DayAnchor.end));
  } else if (tonight != null) {
    sequence.add(DayStop(tonight, tonight.location.point!, tonight.location.name, anchor: DayAnchor.end));
  }

  final stops = <DayStop>[];
  for (final s in sequence) {
    if (stops.isEmpty || stops.last.point.distanceKmTo(s.point) >= _sameStopKm) {
      stops.add(s);
    } else if (s.anchor != null && stops.last.anchor == null) {
      // Keep the anchor marker when it coincides with another stop.
      stops[stops.length - 1] = s;
    }
  }
  final legs = <DayLeg>[
    for (var i = 0; i + 1 < sequence.length; i++)
      if (sequence[i].point.distanceKmTo(sequence[i + 1].point) >= _sameStopKm) _leg(sequence[i], sequence[i + 1], settings),
  ];
  return DayRoutePlan(stops: stops, legs: legs, unordered: unordered, missingLocation: missing);
}

DayLeg _leg(DayStop from, DayStop to, DaySettings? settings) {
  final a = from.activity;
  final sameTransport = a != null && a == to.activity && a.kind.isTransport && to.isArrival;
  if (sameTransport) {
    return switch (a.kind) {
      ActivityKind.flight || ActivityKind.train || ActivityKind.ferry => DayLeg(from, to, DayLegKind.booked),
      ActivityKind.bus || ActivityKind.transfer => DayLeg(from, to, DayLegKind.road, fixedMode: TravelMode.driving),
      _ => DayLeg(from, to, DayLegKind.undecided),
    };
  }
  // The way *to* a stop is the traveller's choice, stored on that stop.
  if (to.anchor == DayAnchor.end) {
    return DayLeg(
      from,
      to,
      DayLegKind.road,
      chosenMode: settings?.endArrivalMode,
      manualMinutes: settings?.endArrivalMinutes,
    );
  }
  return DayLeg(
    from,
    to,
    DayLegKind.road,
    chosenMode: to.activity?.arrivalMode,
    manualMinutes: to.activity?.arrivalMinutes,
  );
}
