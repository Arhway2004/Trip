import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_route.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_settings.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// Minutes to travel between two points (the caller decides how: routed
/// matrix or straight-line estimate).
typedef TravelMinutes = double Function(GeoPoint from, GeoPoint to);

/// One entry of a proposed day, in time order.
class PlannedItem {
  const PlannedItem({
    required this.activity,
    required this.start,
    required this.end,
    required this.fixed,
    this.travelMinutes = 0,
    this.waitMinutes = 0,
    this.assumedDuration = false,
    this.closed = false,
    this.outsideHours = false,
    this.lateMinutes = 0,
  });

  final Activity activity;

  /// Minutes after midnight on the day (may exceed 1440 for late finishes).
  final int start;
  final int end;

  /// A booked, locked or transport item the optimizer never moves.
  final bool fixed;

  /// Travel time from the previous stop to here.
  final int travelMinutes;

  /// Waiting for the place to open.
  final int waitMinutes;

  /// The activity had no time, so a 1-hour visit was assumed.
  final bool assumedDuration;

  /// Closed that weekday.
  final bool closed;

  /// The visit doesn't fit the opening hours.
  final bool outsideHours;

  /// How late the traveller would arrive at a fixed item.
  final int lateMinutes;
}

/// A proposed order for one day, with the before/after travel time.
class DayOptimization {
  const DayOptimization({
    required this.items,
    required this.travelMinutes,
    required this.currentTravelMinutes,
    required this.finishMinute,
    required this.dayStartMinute,
    required this.exhaustive,
  });

  final List<PlannedItem> items;

  /// Total travel with the proposed order (incl. to the end point).
  final int travelMinutes;

  /// The same, keeping today's order (re-timed the same way).
  final int currentTravelMinutes;

  /// Arrival at the end point (or end of the last item).
  final int finishMinute;
  final int dayStartMinute;

  /// Every order was tried (small days); otherwise a good heuristic order.
  final bool exhaustive;

  int get savedMinutes => currentTravelMinutes - travelMinutes;
  Iterable<PlannedItem> get moved => items.where((i) => !i.fixed);
  bool get hasProblems => items.any((i) => i.closed || i.outsideHours || i.lateMinutes > 0);
}

/// Default visit length for activities without a time (shown as assumed).
const assumedVisitMinutes = 60;

/// Activities the optimizer may move on [day]: located single-day visits that
/// are not locked, not booked and not transport or stays.
bool isMovable(Activity a, LocalDate day) =>
    !a.isCancelled &&
    !a.isLocked &&
    a.bookingStatus == BookingStatus.notBooked &&
    !a.kind.isTransport &&
    !a.kind.isStay &&
    a.location.point != null &&
    a.date == day &&
    a.lastDate == day;

class _Visit {
  _Visit(this.activity)
    : point = activity.location.point!,
      duration = activity.durationMinutes ?? assumedVisitMinutes,
      assumed = !activity.hasTime;
  final Activity activity;
  final GeoPoint point;
  final int duration;
  final bool assumed;
}

class _Fixed {
  _Fixed(this.activity, this.start, this.end);
  final Activity activity;
  final int start, end;
  GeoPoint? get from => activity.location.point;
  GeoPoint? get to => activity.endPlace.point;
}

class _Result {
  _Result(this.items, this.travel, this.cost, this.finish);
  final List<PlannedItem> items;
  final int travel;
  final double cost;
  final int finish;
}

/// Finds the order of the day's movable visits with the least travel, from
/// the day's start point to its end point, around fixed items and opening
/// hours. Returns null when there is nothing to reorder (fewer than 2 visits).
///
/// Up to 7 visits every order is tried; beyond that a nearest-neighbour start
/// is improved with 2-opt moves. Times come from [travel], so they are only as
/// good as the routing behind it.
DayOptimization? optimizeDay({
  required List<Activity> activities,
  required LocalDate day,
  required TravelMinutes travel,
  DaySettings? settings,
  int? dayStartMinute,
}) {
  final visits = [
    for (final a in activities.where((a) => isMovable(a, day))) _Visit(a),
  ];
  if (visits.length < 2) return null;
  final movable = {for (final v in visits) v.activity.id};
  final fixed = <_Fixed>[
    for (final a in activities)
      if (!movable.contains(a.id) && !a.isCancelled && !a.kind.isStay && a.hasTime)
        if (a.spanOn(day) case (final s, final e)) _Fixed(a, s, e),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final (lastNight, tonight) = defaultDayAnchors(activities, day);
  final startPoint = settings?.start.point ?? lastNight?.location.point;
  final endPoint = settings?.end.point ?? tonight?.location.point;

  final timedStarts = [for (final v in visits) if (v.activity.hasTime) v.activity.startMinute!];
  final dayStart =
      dayStartMinute ?? (timedStarts.isEmpty ? 9 * 60 : timedStarts.reduce((a, b) => a < b ? a : b));

  _Result simulate(List<_Visit> order) {
    final items = <PlannedItem>[];
    var t = dayStart;
    GeoPoint? at = startPoint;
    var travelTotal = 0, late = 0, problems = 0;
    var fi = 0;

    int go(GeoPoint? to) {
      if (at == null || to == null) return 0;
      final m = travel(at!, to).round();
      travelTotal += m;
      return m;
    }

    // Fixed items that end before the day starts are already done.
    while (fi < fixed.length && fixed[fi].end <= dayStart) {
      at = fixed[fi].to ?? at;
      fi++;
    }

    void doFixed(_Fixed f) {
      final tr = go(f.from);
      final arrive = t + tr;
      final lateBy = arrive > f.start ? arrive - f.start : 0;
      late += lateBy;
      items.add(
        PlannedItem(
          activity: f.activity,
          start: f.start,
          end: f.end,
          fixed: true,
          travelMinutes: tr,
          lateMinutes: lateBy,
        ),
      );
      t = f.end > arrive ? f.end : arrive + (f.end - f.start);
      at = f.to ?? f.from ?? at;
    }

    for (final v in order) {
      // Go to a fixed item first when visiting v would make us late for it.
      while (fi < fixed.length) {
        final f = fixed[fi];
        final arriveV = t + (at == null ? 0 : travel(at!, v.point));
        final startV = _openFrom(v.activity, day, arriveV.round());
        final back = f.from == null ? 0 : travel(v.point, f.from!);
        if (startV + v.duration + back <= f.start) break;
        doFixed(f);
        fi++;
      }
      final tr = go(v.point);
      final arrive = t + tr;
      final start = _openFrom(v.activity, day, arrive);
      final end = start + v.duration;
      final hours = v.activity.openingHours;
      final closed = hours?.isClosedOn(day) ?? false;
      final outside = !closed && hours != null && !hours.covers(day, start, end);
      if (closed || outside) problems++;
      items.add(
        PlannedItem(
          activity: v.activity,
          start: start,
          end: end,
          fixed: false,
          travelMinutes: tr,
          waitMinutes: start - arrive,
          assumedDuration: v.assumed,
          closed: closed,
          outsideHours: outside,
        ),
      );
      t = end;
      at = v.point;
    }
    while (fi < fixed.length) {
      doFixed(fixed[fi]);
      fi++;
    }
    t += go(endPoint);
    final cost = travelTotal + 2000.0 * problems + 3.0 * late + t / 1000;
    return _Result(items, travelTotal, cost, t);
  }

  // Today's order: timed visits by time, untimed ones after, as created.
  final current = [...visits]..sort((a, b) {
    if (a.activity.hasTime != b.activity.hasTime) return a.activity.hasTime ? -1 : 1;
    return compareActivities(a.activity, b.activity);
  });
  final currentResult = simulate(current);

  var best = currentResult;
  var bestOrder = current;
  final exhaustive = visits.length <= 7;
  if (exhaustive) {
    for (final p in _permutations(visits)) {
      final r = simulate(p);
      if (r.cost < best.cost - 1e-9) {
        best = r;
        bestOrder = p;
      }
    }
  } else {
    // Nearest neighbour from the start point, then 2-opt.
    final left = [...visits];
    final order = <_Visit>[];
    var from = startPoint ?? left.first.point;
    while (left.isNotEmpty) {
      left.sort((a, b) => travel(from, a.point).compareTo(travel(from, b.point)));
      final next = left.removeAt(0);
      order.add(next);
      from = next.point;
    }
    var cur = order;
    var curR = simulate(cur);
    var improved = true;
    var rounds = 0;
    while (improved && rounds++ < 50) {
      improved = false;
      for (var i = 0; i < cur.length - 1; i++) {
        for (var j = i + 1; j < cur.length; j++) {
          final cand = [...cur.sublist(0, i), ...cur.sublist(i, j + 1).reversed, ...cur.sublist(j + 1)];
          final r = simulate(cand);
          if (r.cost < curR.cost - 1e-9) {
            cur = cand;
            curR = r;
            improved = true;
          }
        }
      }
    }
    if (curR.cost < best.cost) {
      best = curR;
      bestOrder = cur;
    }
  }
  assert(bestOrder.length == visits.length);
  return DayOptimization(
    items: best.items,
    travelMinutes: best.travel,
    currentTravelMinutes: currentResult.travel,
    finishMinute: best.finish,
    dayStartMinute: dayStart,
    exhaustive: exhaustive,
  );
}

/// Earliest start at or after [arrive] that the opening hours allow.
int _openFrom(Activity a, LocalDate day, int arrive) {
  final h = a.openingHours;
  if (h == null || h.isClosedOn(day)) return arrive;
  return arrive < h.opens ? h.opens : arrive;
}

Iterable<List<T>> _permutations<T>(List<T> items) sync* {
  final a = [...items];
  final c = List.filled(a.length, 0);
  yield [...a];
  var i = 0;
  while (i < a.length) {
    if (c[i] < i) {
      final k = i.isEven ? 0 : c[i];
      final tmp = a[k];
      a[k] = a[i];
      a[i] = tmp;
      yield [...a];
      c[i]++;
      i = 0;
    } else {
      c[i] = 0;
      i++;
    }
  }
}
