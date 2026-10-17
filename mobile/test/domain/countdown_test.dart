import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/shared/domain/countdown.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../helpers.dart';

void main() {
  setUpAll(initTestEnvironment);

  CountdownState at(String nowUtc, {String? start, String? end, String? time, String zone = 'Asia/Bangkok'}) =>
      computeCountdown(
        start: LocalDate.tryParse(start),
        end: LocalDate.tryParse(end),
        departureTime: time,
        timeZone: zone,
        now: DateTime.parse(nowUtc),
      );

  test('no start date gives NoDate', () {
    expect(at('2026-01-01T00:00:00Z'), isA<CountdownNoDate>());
  });

  test('whole days until start without a departure time', () {
    // 2026-01-01 10:00 in Bangkok (UTC+7).
    final c = at('2026-01-01T03:00:00Z', start: '2026-02-15', end: '2026-02-20') as CountdownBeforeDeparture;
    expect(c.days, 45);
    expect(c.hasDepartureTime, isFalse);
  });

  test('days, hours and minutes with a departure time', () {
    // Now 2026-03-01 08:00 Bangkok; departs 2026-03-13 14:30 Bangkok.
    final c = at('2026-03-01T01:00:00Z', start: '2026-03-13', time: '14:30') as CountdownBeforeDeparture;
    expect((c.days, c.hours, c.minutes), (12, 6, 30));
  });

  test('uses the trip time zone, not UTC, for the calendar day', () {
    // 2026-05-09 23:30 UTC is already 2026-05-10 in Shanghai: trip has started.
    expect(
      at('2026-05-09T23:30:00Z', start: '2026-05-10', end: '2026-05-12', zone: 'Asia/Shanghai'),
      isA<CountdownDuringTrip>(),
    );
    // ...but it is still 2026-05-09 in New York: 1 day to go.
    final ny = at('2026-05-09T23:30:00Z', start: '2026-05-10', end: '2026-05-12', zone: 'America/New_York');
    expect((ny as CountdownBeforeDeparture).days, 1);
  });

  test('departure day before the departure time still counts down', () {
    final c = at('2026-03-13T00:00:00Z', start: '2026-03-13', time: '14:30') as CountdownBeforeDeparture;
    expect((c.days, c.hours, c.minutes), (0, 7, 30));
  });

  test('during the trip shows Day N of M', () {
    final c = at('2026-07-03T05:00:00Z', start: '2026-07-01', end: '2026-07-10') as CountdownDuringTrip;
    expect((c.dayNumber, c.totalDays), (3, 10));
  });

  test('after the last day the trip is completed', () {
    expect(at('2026-07-11T00:00:00Z', start: '2026-07-01', end: '2026-07-10'), isA<CountdownCompleted>());
  });

  test('never produces negative values around departure', () {
    for (var minute = -5; minute <= 5; minute++) {
      final now = DateTime.utc(2026, 3, 13, 7, 30).add(Duration(minutes: minute)); // 14:30 Bangkok ± 5 min
      final c = computeCountdown(
        start: const LocalDate(2026, 3, 13),
        end: const LocalDate(2026, 3, 14),
        departureTime: '14:30',
        timeZone: 'Asia/Bangkok',
        now: now,
      );
      if (c is CountdownBeforeDeparture) {
        expect(c.days >= 0 && c.hours >= 0 && c.minutes >= 0, isTrue);
      } else {
        expect(c, isA<CountdownDuringTrip>());
      }
    }
  });

  test('end before start is treated as a one-day trip', () {
    final c = at('2026-07-01T05:00:00Z', start: '2026-07-01', end: '2026-06-01') as CountdownDuringTrip;
    expect(c.totalDays, 1);
  });

  test('unknown time zone falls back to UTC instead of throwing', () {
    expect(at('2026-01-01T00:00:00Z', start: '2026-01-03', zone: 'Not/AZone'), isA<CountdownBeforeDeparture>());
  });

  test('LocalDate parsing rejects invalid dates', () {
    expect(LocalDate.tryParse('2026-02-30'), isNull);
    expect(LocalDate.tryParse('nope'), isNull);
    expect(LocalDate.tryParse('2028-02-29'), const LocalDate(2028, 2, 29));
  });
}
