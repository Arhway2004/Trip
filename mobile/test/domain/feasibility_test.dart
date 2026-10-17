import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/feasibility.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

void main() {
  const d1 = LocalDate(2026, 11, 20), d2 = LocalDate(2026, 11, 21);
  final t0 = DateTime.utc(2026);
  var n = 0;
  Activity act(
    String title,
    int start,
    int end, {
    LocalDate date = d1,
    LocalDate? endDate,
    ActivityKind kind = ActivityKind.sightseeing,
    PlaceRef location = const PlaceRef(),
    BookingStatus status = BookingStatus.booked,
    bool optional = false,
  }) => Activity(
    id: 'a${n++}',
    tripId: 't',
    title: title,
    kind: kind,
    date: date,
    startMinute: start,
    endDate: endDate,
    endMinute: end,
    location: location,
    bookingStatus: status,
    isOptional: optional,
    createdAt: t0,
    updatedAt: t0,
  );
  int h(int hh, [int mm = 0]) => hh * 60 + mm;
  DayAssessment day(List<Activity> acts, {LocalDate? start, LocalDate? end, LocalDate on = d1}) =>
      assessItinerary(activities: acts, tripStart: start, tripEnd: end).firstWhere((d) => d.date == on);
  Set<IssueCode> codes(DayAssessment d) => d.issues.map((i) => i.code).toSet();

  test('a well-spaced day with lunch is feasible', () {
    final d = day([
      act('Museum', h(9), h(11)),
      act('Lunch', h(12), h(13), kind: ActivityKind.food),
      act('Park', h(14), h(16)),
    ]);
    expect(d.status, DayStatus.feasible);
    expect(d.issues, isEmpty);
  });

  test('overlaps are unrealistic; overlaps with optional items only tight', () {
    final hard = day([act('A', h(9), h(11)), act('B', h(10), h(12))]);
    expect(hard.status, DayStatus.unrealistic);
    expect(hard.issues.firstWhere((i) => i.code == IssueCode.overlap).minutes, 60);
    final soft = day([act('A', h(9), h(11)), act('B', h(10), h(12), optional: true)]);
    expect(soft.status, DayStatus.tight);
  });

  test('flights need a 2 h buffer, trains 30 min', () {
    final f = day([act('Hotel breakfast', h(7), h(8)), act('Flight', h(9), h(11), kind: ActivityKind.flight)]);
    final i = f.issues.firstWhere((x) => x.code == IssueCode.departureBuffer);
    expect((i.minutes, i.requiredMinutes), (60, 120));
    final t = day([act('Cafe', h(7), h(8, 40)), act('Train', h(9), h(11), kind: ActivityKind.train)]);
    expect(codes(t), contains(IssueCode.departureBuffer));
  });

  test('distance between known points needs travel time (estimate from straight line)', () {
    const bangkok = GeoPoint(13.7563, 100.5018), ayutthaya = GeoPoint(14.3532, 100.5689);
    final d = day([
      act(
        'Grand Palace',
        h(9),
        h(11),
        location: const PlaceRef(name: 'Grand Palace', point: bangkok),
      ),
      act(
        'Ayutthaya',
        h(11, 30),
        h(14),
        location: const PlaceRef(name: 'Ayutthaya', point: ayutthaya),
      ),
    ]);
    final i = d.issues.firstWhere((x) => x.code == IssueCode.tightTravel);
    expect(i.distanceKm, closeTo(66.7, 1));
    expect(i.requiredMinutes, greaterThan(150));
    expect(d.status, DayStatus.tight);
  });

  test('back-to-back activities at different named places get a travel warning', () {
    final d = day([
      act('A', h(9), h(10), location: const PlaceRef(name: 'Temple')),
      act('B', h(10), h(11), location: const PlaceRef(name: 'Market')),
    ]);
    expect(codes(d), contains(IssueCode.noTravelTime));
  });

  test('nights without a hotel are flagged; a stay covers its nights', () {
    final stay = act('Hotel', h(15), h(11), endDate: d2, kind: ActivityKind.hotel);
    expect(stay.nights, [d1]);
    expect(codes(day([act('X', h(9), h(10))], start: d1, end: d2)), contains(IssueCode.missingAccommodation));
    expect(codes(day([stay], start: d1, end: d2)), isNot(contains(IssueCode.missingAccommodation)));
    // The last day has no night to cover.
    expect(codes(day(const [], start: d1, end: d2, on: d2)), isNot(contains(IssueCode.missingAccommodation)));
  });

  test('unbooked flights keep a day from being called feasible', () {
    final d = day([act('Flight', h(12), h(15), kind: ActivityKind.flight, status: BookingStatus.notBooked)]);
    expect(d.status, DayStatus.unknown);
    expect(codes(d), contains(IssueCode.transportNotBooked));
  });

  test('activities outside the trip dates are reported, never hidden', () {
    final days = assessItinerary(
      activities: [act('Early bird', h(9), h(10), date: const LocalDate(2026, 11, 19))],
      tripStart: d1,
      tripEnd: d2,
    );
    expect(days.first.date, const LocalDate(2026, 11, 19));
    expect(codes(days.first), contains(IssueCode.outsideTripDates));
  });

  test('very long days and missing lunch are noted', () {
    final d = day([act('Hike', h(7), h(21, 30), kind: ActivityKind.activity)]);
    expect(codes(d), containsAll([IssueCode.longDay, IssueCode.noMealBreak]));
  });

  test('cancelled items are ignored and empty days are free', () {
    final d = day(
      [act('X', h(9), h(10), status: BookingStatus.cancelled)],
      start: d1,
      end: d1,
    );
    expect(d.status, DayStatus.empty);
  });

  test('moving keeps duration; resizing has a 15-minute minimum', () {
    final a = act('Show', h(20), h(22, 30));
    final moved = a.movedTo(d2, h(23), t0);
    expect(
      (moved.date, moved.startMinute, moved.lastDate, moved.endMinute),
      (d2, h(23), const LocalDate(2026, 11, 22), h(1, 30)),
    );
    expect(a.resized(5, t0).durationMinutes, 15);
    expect(() => act('Bad', h(10), h(9)), throwsA(anything));
  });

  group('activities without a decided time', () {
    Activity untimed(String title, {ActivityKind kind = ActivityKind.flight, bool optional = false}) => Activity(
      id: 'u${n++}',
      tripId: 't',
      title: title,
      kind: kind,
      date: d1,
      isOptional: optional,
      createdAt: t0,
      updatedAt: t0,
    );

    test('are never on the grid and never cause overlaps or buffer warnings', () {
      final u = untimed('Flight TBD');
      expect((u.hasTime, u.spanOn(d1), u.durationMinutes), (false, null, null));
      final d = day([u, act('Museum', h(9), h(11)), act('Lunch', h(12), h(13), kind: ActivityKind.food)]);
      expect(d.issues.map((i) => i.code), isNot(contains(IssueCode.overlap)));
      expect(d.issues.map((i) => i.code), isNot(contains(IssueCode.departureBuffer)));
      expect(d.activities, contains(u), reason: 'still listed on its day');
    });

    test('keep the day at "needs info" unless optional', () {
      expect(day([untimed('Bus TBD', kind: ActivityKind.bus)]).status, DayStatus.unknown);
      expect(day([untimed('Maybe a show', kind: ActivityKind.activity, optional: true)]).status, DayStatus.feasible);
    });

    test('a start without an end (or vice versa) is rejected', () {
      expect(
        () => Activity(id: 'x', tripId: 't', title: 'Half', date: d1, startMinute: 600, createdAt: t0, updatedAt: t0),
        throwsA(anything),
      );
    });

    test('moving an untimed activity shifts only its dates', () {
      final moved = untimed('Train TBD').movedTo(d2, null, t0);
      expect((moved.date, moved.hasTime), (d2, false));
    });
  });
}
