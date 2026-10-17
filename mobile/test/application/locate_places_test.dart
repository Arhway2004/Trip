import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/unlocated_places.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../helpers.dart';

void main() {
  setUpAll(initTestEnvironment);
  late TestDevice d;
  setUp(() async => d = await TestDevice.create());
  tearDown(() => d.dispose());

  test('one place name located once updates every activity that uses it, and only those', () async {
    final id = await d.app.trips.createTrip(TripDraft(title: 'Yunnan', timeZone: 'Asia/Shanghai'));
    const airport = 'Kunming Changshui International Airport';
    await d.app.itinerary.addActivities(id, [
      ActivityDraft(
        title: 'Fly in',
        kind: ActivityKind.flight,
        date: const LocalDate(2026, 12, 3),
        location: const PlaceRef(name: 'Bangkok airport (confirm BKK or DMK)'),
        destination: const PlaceRef(name: airport),
      ),
      ActivityDraft(
        title: 'Transfer',
        kind: ActivityKind.transport,
        date: const LocalDate(2026, 12, 3),
        location: const PlaceRef(name: airport),
        destination: const PlaceRef(name: 'Kunming hotel'),
      ),
      ActivityDraft(title: 'Old street', date: const LocalDate(2026, 12, 3), location: const PlaceRef(name: '昆明老街')),
    ]);

    final before = unlocatedPlaces(await d.app.itinerary.activitiesOf(id));
    expect(before.map((p) => p.name), [
      'Bangkok airport (confirm BKK or DMK)',
      airport,
      'Kunming hotel',
      '昆明老街',
    ]);
    expect(before[1].activities, hasLength(2));

    final n = await d.app.itinerary.locateByName(id, airport, const GeoPoint(25.1019, 102.9292), 'search:test');
    expect(n, 2);
    final acts = await d.app.itinerary.activitiesOf(id);
    final fly = acts.firstWhere((a) => a.title == 'Fly in');
    final transfer = acts.firstWhere((a) => a.title == 'Transfer');
    expect(fly.destination.point, const GeoPoint(25.1019, 102.9292));
    expect(fly.destination.name, airport, reason: 'the name stays as written');
    expect(fly.location.point, isNull);
    expect(transfer.location.point, isNotNull);
    expect(transfer.destination.point, isNull);
    expect(unlocatedPlaces(acts).map((p) => p.name), isNot(contains(airport)));
  });
}
