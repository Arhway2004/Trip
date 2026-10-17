import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_optimizer.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_route.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_settings.dart';
import 'package:wanderplan/contexts/itinerary/domain/feasibility.dart';
import 'package:wanderplan/contexts/itinerary/domain/opening_hours.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

final _t = DateTime.utc(2026, 1, 1);
var _n = 0;
const day = LocalDate(2026, 12, 21); // a Monday

/// A point [km] east along the equator (≈ 1 km per 0.009°).
GeoPoint at(double km) => GeoPoint(0, km * 0.009);

Activity act(
  String title, {
  double? km,
  int? start,
  int? end,
  ActivityKind kind = ActivityKind.sightseeing,
  bool locked = false,
  OpeningHours? hours,
  LocalDate? date,
  LocalDate? endDate,
  TravelMode? arrival,
  int? arrivalMinutes,
  BookingStatus status = BookingStatus.notBooked,
}) => Activity(
  id: '${_n++}',
  tripId: 't',
  title: title,
  kind: kind,
  date: date ?? day,
  endDate: endDate,
  startMinute: start,
  endMinute: end,
  location: PlaceRef(name: title, point: km == null ? null : at(km)),
  isLocked: locked,
  openingHours: hours,
  arrivalMode: arrival,
  arrivalMinutes: arrivalMinutes,
  bookingStatus: status,
  createdAt: _t,
  updatedAt: _t,
);

/// 10 minutes per km.
double travel(GeoPoint a, GeoPoint b) => a.distanceKmTo(b) * 10;

void main() {
  group('opening hours', () {
    test('a visit must fit the hours and not fall on a closed weekday', () {
      final h = OpeningHours(opens: 9 * 60, closes: 17 * 60, closedWeekdays: {DateTime.monday});
      expect(h.isClosedOn(day), isTrue);
      final tue = day.addDays(1);
      expect(h.covers(tue, 9 * 60, 11 * 60), isTrue);
      expect(h.covers(tue, 8 * 60, 10 * 60), isFalse);
      expect(h.covers(tue, 16 * 60, 18 * 60), isFalse);
    });

    test('closing after midnight and invalid hours', () {
      final night = OpeningHours(opens: 18 * 60, closes: 2 * 60);
      expect(night.overnight, isTrue);
      expect(night.covers(day, 22 * 60, 25 * 60), isTrue);
      expect(() => OpeningHours(opens: 9 * 60, closes: 17 * 60, closedWeekdays: {1, 2, 3, 4, 5, 6, 7}), throwsA(isA<DomainException>()));
    });
  });

  group('day route with start/end and leg modes', () {
    test('a chosen start point replaces the hotel; leg modes come from the next stop', () {
      final hotel = act('Hotel', km: 0, kind: ActivityKind.hotel, date: day.addDays(-1), endDate: day.addDays(1), start: 900, end: 660);
      final a = act('A', km: 2, start: 600, end: 660, arrival: TravelMode.transit, arrivalMinutes: 25);
      final b = act('B', km: 4, start: 720, end: 780);
      final settings = DaySettings(tripId: 't', date: day, start: PlaceRef(name: 'Station', point: at(-3)), endArrivalMode: TravelMode.driving);
      final plan = planDayRoute([hotel, a, b], day, settings: settings);
      expect(plan.stops.map((s) => s.label), ['Station', 'A', 'B', 'Hotel']);
      expect(plan.start!.activity, isNull);
      expect((plan.legs[0].chosenMode, plan.legs[0].manualMinutes), (TravelMode.transit, 25));
      expect(plan.legs[1].mode(TravelMode.walking), TravelMode.walking);
      expect(plan.legs[2].chosenMode, TravelMode.driving, reason: 'the end leg uses the day setting');
      expect(plan.legs[1].availableMinutes(day), 60);
    });
  });

  group('optimizer', () {
    final hotel = act('Hotel', km: 0, kind: ActivityKind.hotel, date: day.addDays(-1), endDate: day.addDays(1), start: 900, end: 660);

    test('reorders zig-zag visits into the shortest loop from and back to the hotel', () {
      final visits = [
        act('A', km: 1, start: 540, end: 600),
        act('D', km: 4, start: 620, end: 680),
        act('B', km: 2, start: 700, end: 760),
        act('C', km: 3, start: 780, end: 840),
      ];
      final r = optimizeDay(activities: [hotel, ...visits], day: day, travel: travel)!;
      // Several orders tie on a straight line (e.g. A-B-C-D and A-B-D-C are both 8 km).
      expect(r.currentTravelMinutes, closeTo(100, 2)); // A-D-B-C zig-zags 10 km
      expect(r.travelMinutes, lessThan(r.currentTravelMinutes));
      expect(r.travelMinutes, closeTo(80, 2)); // 4 km out + 4 km back at 10 min/km
      expect(r.exhaustive, isTrue);
      // Times are re-planned in sequence from the first start, keeping durations.
      expect(r.items.first.start, 540 + 10);
      expect(r.items.first.end - r.items.first.start, 60);
    });

    test('locked and booked items keep their time; visits fit around them', () {
      final lunch = act('Lunch', km: 2, start: 12 * 60, end: 13 * 60, kind: ActivityKind.food, locked: true);
      final visits = [act('A', km: 1, start: 600, end: 660), act('B', km: 3, start: 700, end: 760)];
      final r = optimizeDay(activities: [hotel, lunch, ...visits], day: day, travel: travel)!;
      final l = r.items.firstWhere((i) => i.activity.title == 'Lunch');
      expect((l.fixed, l.start, l.end, l.lateMinutes), (true, 720, 780, 0));
      expect(r.moved.map((i) => i.activity.title), unorderedEquals(['A', 'B']));
    });

    test('waits for opening time and flags a place closed that weekday', () {
      final late = act('Opens at 2pm', km: 1, start: 600, end: 660, hours: OpeningHours(opens: 14 * 60, closes: 18 * 60));
      final closed = act('Closed Mondays', km: 2, start: 700, end: 760, hours: OpeningHours(opens: 9 * 60, closes: 18 * 60, closedWeekdays: {DateTime.monday}));
      final r = optimizeDay(activities: [hotel, late, closed], day: day, travel: travel)!;
      final o = r.items.firstWhere((i) => i.activity.title == 'Opens at 2pm');
      expect(o.start, greaterThanOrEqualTo(14 * 60));
      expect(r.items.firstWhere((i) => i.activity.title == 'Closed Mondays').closed, isTrue);
      expect(r.hasProblems, isTrue);
    });

    test('untimed visits get an assumed hour; fewer than two movable visits gives nothing', () {
      final r = optimizeDay(activities: [hotel, act('X', km: 1), act('Y', km: 2)], day: day, travel: travel)!;
      expect(r.items.every((i) => i.assumedDuration && i.end - i.start == 60), isTrue);
      expect(r.dayStartMinute, 9 * 60);
      expect(optimizeDay(activities: [hotel, act('X', km: 1)], day: day, travel: travel), isNull);
      expect(
        optimizeDay(
          activities: [hotel, act('X', km: 1, locked: true), act('Y', km: 2, status: BookingStatus.booked)],
          day: day,
          travel: travel,
        ),
        isNull,
      );
    });

    test('larger days use the heuristic and still beat a bad order', () {
      final kms = <double>[5, 1, 8, 2, 7, 3, 6, 4, 9];
      final visits = [for (var i = 0; i < kms.length; i++) act('V$i', km: kms[i], start: 480 + i * 70, end: 540 + i * 70)];
      final r = optimizeDay(activities: [hotel, ...visits], day: day, travel: travel)!;
      expect(r.exhaustive, isFalse);
      expect(r.travelMinutes, closeTo(180, 5)); // 9 km out and back
    });
  });

  group('feasibility', () {
    test('closed days, opening hours, own travel time and bookings are reported', () {
      final closed = act('Museum', km: 1, start: 600, end: 660, hours: OpeningHours(opens: 9 * 60, closes: 17 * 60, closedWeekdays: {DateTime.monday}));
      final early = act('Temple', km: 2, start: 700, end: 760, hours: OpeningHours(opens: 12 * 60, closes: 17 * 60), arrivalMinutes: 60);
      final ticket = Activity(
        id: 'tk',
        tripId: 't',
        title: 'Snow mountain',
        date: day,
        reservationRequired: true,
        bookAheadDays: 7,
        createdAt: _t,
        updatedAt: _t,
      );
      final d = assessItinerary(activities: [closed, early, ticket]).firstWhere((x) => x.date == day);
      final codes = d.issues.map((i) => i.code).toSet();
      expect(codes, containsAll([IssueCode.closedOnDay, IssueCode.outsideOpeningHours, IssueCode.tightTravel, IssueCode.bookingNeeded]));
      expect(d.issues.firstWhere((i) => i.code == IssueCode.tightTravel).requiredMinutes, 60);
      expect(d.issues.firstWhere((i) => i.code == IssueCode.bookingNeeded).date, day.addDays(-7));
      expect(d.status, DayStatus.unrealistic);
    });
  });
}
