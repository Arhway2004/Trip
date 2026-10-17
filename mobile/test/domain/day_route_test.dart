import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_route.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

final _t = DateTime.utc(2026, 1, 1);
var _n = 0;

Activity _a(
  String title,
  ActivityKind kind,
  LocalDate date, {
  int? start,
  int? end,
  LocalDate? endDate,
  GeoPoint? at,
  GeoPoint? to,
  BookingStatus status = BookingStatus.notBooked,
}) => Activity(
  id: '${_n++}',
  tripId: 't',
  title: title,
  kind: kind,
  date: date,
  startMinute: start,
  endMinute: end,
  endDate: endDate,
  location: PlaceRef(name: title, point: at),
  destination: PlaceRef(point: to),
  bookingStatus: status,
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  const d1 = LocalDate(2026, 12, 20), d2 = LocalDate(2026, 12, 21), d3 = LocalDate(2026, 12, 22);
  const hotel = GeoPoint(39.9139, 116.4105), palace = GeoPoint(39.9163, 116.3972);
  const lunch = GeoPoint(39.9250, 116.4040), station = GeoPoint(39.8650, 116.3785);
  const shanghai = GeoPoint(31.1940, 121.3203), bund = GeoPoint(31.2400, 121.4900);

  test('the day starts at last night\'s hotel, follows times and ends at tonight\'s hotel', () {
    final acts = [
      _a('Hotel', ActivityKind.hotel, d1, start: 15 * 60, end: 11 * 60, endDate: d3, at: hotel),
      _a('Lunch', ActivityKind.food, d2, start: 12 * 60, end: 13 * 60, at: lunch),
      _a('Palace', ActivityKind.sightseeing, d2, start: 9 * 60, end: 11 * 60, at: palace),
    ];
    final plan = planDayRoute(acts, d2);
    expect(plan.stops.map((s) => s.activity.title), ['Hotel', 'Palace', 'Lunch', 'Hotel']);
    expect(plan.legs, hasLength(3));
    expect(plan.legs.every((l) => l.kind == DayLegKind.road && l.fixedMode == null), isTrue);
  });

  test('untimed activities are shown but never slotted into the route', () {
    final acts = [
      _a('Palace', ActivityKind.sightseeing, d2, start: 9 * 60, end: 11 * 60, at: palace),
      _a('Maybe lunch', ActivityKind.food, d2, at: lunch),
      _a('No pin', ActivityKind.sightseeing, d2, start: 14 * 60, end: 15 * 60),
    ];
    final plan = planDayRoute(acts, d2);
    expect(plan.stops.map((s) => s.activity.title), ['Palace']);
    expect(plan.legs, isEmpty);
    expect(plan.unordered.single.activity.title, 'Maybe lunch');
    expect(plan.missingLocation.single.title, 'No pin');
  });

  test('a booked train is a direct leg, a taxi transfer goes by road, an undecided journey is unverified', () {
    final acts = [
      _a('Taxi', ActivityKind.transfer, d2, start: 7 * 60, end: 7 * 60 + 40, at: hotel, to: station),
      _a('G1', ActivityKind.train, d2, start: 9 * 60, end: 13 * 60 + 30, at: station, to: shanghai),
      _a('To the Bund', ActivityKind.transport, d2, start: 14 * 60, end: 15 * 60, at: shanghai, to: bund),
    ];
    final plan = planDayRoute(acts, d2);
    expect(plan.stops, hasLength(4)); // Duplicate station/arrival points are merged.
    expect(plan.legs.map((l) => l.kind), [DayLegKind.road, DayLegKind.booked, DayLegKind.undecided]);
    expect(plan.legs.first.fixedMode, TravelMode.driving);
    expect(plan.legs[1].transport?.title, 'G1');
  });

  test('an overnight train departs on its first day and arrives on its last', () {
    final night = _a('Sleeper', ActivityKind.train, d1, start: 21 * 60, end: 7 * 60, endDate: d2, at: station, to: shanghai);
    expect(planDayRoute([night], d1).stops.map((s) => s.isArrival), [false]);
    expect(planDayRoute([night], d2).stops.map((s) => s.isArrival), [true]);
  });

  test('cancelled activities are left out', () {
    final acts = [
      _a('Palace', ActivityKind.sightseeing, d2, start: 9 * 60, end: 10 * 60, at: palace),
      _a('Cancelled', ActivityKind.food, d2, start: 12 * 60, end: 13 * 60, at: lunch, status: BookingStatus.cancelled),
    ];
    expect(planDayRoute(acts, d2).stops, hasLength(1));
  });
}
