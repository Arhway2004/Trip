import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// A located stop on one day's route.
class DayStop {
  const DayStop(this.activity, this.point, this.label, {this.isArrival = false});
  final Activity activity;

  /// WGS84.
  final GeoPoint point;
  final String? label;

  /// The arrival end of a transport activity.
  final bool isArrival;
}

enum DayLegKind {
  /// Travel on roads between two stops; routed by a routing provider.
  road,

  /// A booked flight, train or ferry: drawn as a direct line, never as a road route.
  booked,

  /// A transport activity whose mode isn't decided: it can't be routed.
  undecided,
}

/// The way between two consecutive stops.
class DayLeg {
  const DayLeg(this.from, this.to, this.kind, {this.fixedMode});
  final DayStop from;
  final DayStop to;
  final DayLegKind kind;

  /// Set when the itinerary fixes how this leg is travelled (a bus or taxi
  /// transfer goes by road); otherwise the user's chosen mode applies.
  final TravelMode? fixedMode;

  /// The transport activity this leg belongs to, if any.
  Activity? get transport => from.activity == to.activity && from.activity.kind.isTransport ? from.activity : null;
}

/// One day's route, built only from what the plan says. Nothing is reordered
/// or guessed: activities without a time can't be placed in the sequence, so
/// they are listed separately rather than slotted in.
class DayRoutePlan {
  const DayRoutePlan({required this.stops, required this.legs, required this.unordered, required this.missingLocation});

  /// In time order, starting at last night's hotel and ending at tonight's when known.
  final List<DayStop> stops;
  final List<DayLeg> legs;

  /// Located activities on this day without a time (shown, but not routed).
  final List<DayStop> unordered;

  /// Activities on this day that have no coordinates yet.
  final List<Activity> missingLocation;
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

DayRoutePlan planDayRoute(List<Activity> activities, LocalDate day) {
  final live = activities.where((a) => activityOccursOn(a, day)).toList()..sort(compareActivities);
  final stops = <DayStop>[];
  final unordered = <DayStop>[];
  final missing = <Activity>[];

  // Every stop in order; consecutive stops at the same spot (a taxi arriving
  // where the train departs) are merged for display but keep their legs right.
  final sequence = <DayStop>[];
  void add(DayStop s) => sequence.add(s);

  // Morning: wake up at the hotel booked for last night.
  final stays = live.where((a) => a.kind.isStay).toList();
  for (final h in stays) {
    if (h.location.point == null) missing.add(h);
  }
  final lastNight = stays.where((h) => h.date < day && day <= h.lastDate && h.location.point != null);
  if (lastNight.isNotEmpty) add(DayStop(lastNight.first, lastNight.first.location.point!, lastNight.first.location.name));

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
    if (a.location.point != null && a.date == day) add(DayStop(a, a.location.point!, a.location.name));
    if (a.kind.isTransport && a.destination.point != null && a.lastDate == day) {
      add(DayStop(a, a.destination.point!, a.destination.name, isArrival: true));
    }
  }

  // Evening: back to tonight's hotel.
  final tonight = stays.where((h) => h.date <= day && day < h.lastDate && h.location.point != null);
  if (tonight.isNotEmpty) add(DayStop(tonight.first, tonight.first.location.point!, tonight.first.location.name));

  for (final s in sequence) {
    if (stops.isEmpty || stops.last.point.distanceKmTo(s.point) >= _sameStopKm) stops.add(s);
  }
  final legs = <DayLeg>[
    for (var i = 0; i + 1 < sequence.length; i++)
      if (sequence[i].point.distanceKmTo(sequence[i + 1].point) >= _sameStopKm) _leg(sequence[i], sequence[i + 1]),
  ];
  return DayRoutePlan(stops: stops, legs: legs, unordered: unordered, missingLocation: missing);
}

DayLeg _leg(DayStop from, DayStop to) {
  final sameTransport = from.activity == to.activity && from.activity.kind.isTransport && to.isArrival;
  if (!sameTransport) return DayLeg(from, to, DayLegKind.road);
  return switch (from.activity.kind) {
    ActivityKind.flight || ActivityKind.train || ActivityKind.ferry => DayLeg(from, to, DayLegKind.booked),
    ActivityKind.bus || ActivityKind.transfer => DayLeg(from, to, DayLegKind.road, fixedMode: TravelMode.driving),
    _ => DayLeg(from, to, DayLegKind.undecided),
  };
}
