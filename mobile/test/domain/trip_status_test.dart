import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/shared/domain/countdown.dart';
import 'package:wanderplan/contexts/trip/application/trip_queries.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';

void main() {
  const before = CountdownBeforeDeparture(days: 3, hours: 0, minutes: 0, hasDepartureTime: false);

  TripStatus status({
    bool archived = false,
    TripStage stage = TripStage.planning,
    bool confirmed = false,
    CountdownState c = const CountdownNoDate(),
  }) => computeTripStatus(archived: archived, stage: stage, datesConfirmed: confirmed, countdown: c);

  test('archived always wins', () {
    expect(status(archived: true, c: const CountdownDuringTrip(dayNumber: 1, totalDays: 2)), TripStatus.archived);
  });

  test('stage is used without dates or with flexible dates', () {
    expect(status(stage: TripStage.dreaming), TripStatus.dreaming);
    expect(status(c: before), TripStatus.planning);
  });

  test('confirmed future dates are upcoming; dates drive traveling/completed', () {
    expect(status(confirmed: true, c: before), TripStatus.upcoming);
    expect(status(c: const CountdownDuringTrip(dayNumber: 1, totalDays: 2)), TripStatus.traveling);
    expect(status(c: const CountdownCompleted()), TripStatus.completed);
  });

  test('All filter hides archived trips', () {
    expect(matchesFilter(TripStatus.archived, TripFilter.all), isFalse);
    expect(matchesFilter(TripStatus.planning, TripFilter.all), isTrue);
    expect(matchesFilter(TripStatus.archived, TripFilter.archived), isTrue);
  });
}
