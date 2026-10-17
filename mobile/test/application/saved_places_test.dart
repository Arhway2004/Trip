import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/places/application/saved_place_service.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/sharing/application/trip_package_service.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

import '../helpers.dart';

void main() {
  setUpAll(initTestEnvironment);
  late TestDevice d;
  setUp(() async => d = await TestDevice.create());
  tearDown(() => d.dispose());

  const louvre = GeoPoint(48.8606, 2.3376);

  Future<String> trip() => d.app.trips.createTrip(TripDraft(title: 'Paris', timeZone: 'Europe/Paris'));

  test('saving the same place twice keeps one; places belong to one trip', () async {
    final a = await trip(), b = await trip();
    final draft = SavedPlaceDraft(name: 'Louvre', point: louvre, source: 'search:openstreetmap-nominatim');
    final id1 = await d.app.savedPlaces.savePlace(a, draft);
    final id2 = await d.app.savedPlaces.savePlace(a, SavedPlaceDraft(name: 'louvre ', point: louvre));
    expect(id2, id1);
    expect(await d.app.savedPlaces.placesOf(a), hasLength(1));
    expect(await d.app.savedPlaces.placesOf(b), isEmpty);
    expect((await d.app.savedPlaces.placesOf(a)).single.isProviderVerified, isTrue);

    await d.app.savedPlaces.updatePlace(id1, category: PlaceCategory.other, notes: 'Mon closed');
    final p = (await d.app.savedPlaces.placesOf(a)).single;
    expect((p.category, p.notes), (PlaceCategory.other, 'Mon closed'));
    await d.app.savedPlaces.removePlace(id1);
    expect(await d.app.savedPlaces.placesOf(a), isEmpty);
  });

  test('duplicating a trip copies its places; deleting a trip removes them', () async {
    final a = await trip();
    await d.app.savedPlaces.savePlace(a, SavedPlaceDraft(name: 'Louvre', point: louvre));
    final copy = await d.app.trips.duplicateTrip(a, titleSuffix: ' (copy)');
    expect((await d.app.savedPlaces.placesOf(copy)).single.name, 'Louvre');
    await d.app.trips.deleteTrip(a);
    expect(await d.app.savedPlaces.placesOf(a), isEmpty);
    expect(await d.app.savedPlaces.placesOf(copy), hasLength(1));
  });

  test('places round-trip through a trip file; places without coordinates are refused', () async {
    final a = await trip();
    await d.app.savedPlaces.savePlace(
      a,
      SavedPlaceDraft(name: 'Gare de Lyon', point: const GeoPoint(48.8443, 2.3744), category: PlaceCategory.railwayStation),
    );
    final friend = await TestDevice.create();
    addTearDown(friend.dispose);
    final theirs = await friend.app.packages.importFile(await d.app.packages.exportTrip(a));
    final p = (await friend.app.savedPlaces.placesOf(theirs)).single;
    expect((p.name, p.category, p.source), ('Gare de Lyon', PlaceCategory.railwayStation, 'import'));
    expect(p.point.distanceKmTo(const GeoPoint(48.8443, 2.3744)), lessThan(0.001));

    final bad = File('${(await Directory.systemTemp.createTemp()).path}/bad.json')
      ..writeAsStringSync(
        jsonEncode({
          'format': tripPackageFormat,
          'schemaVersion': 3,
          'trip': {'title': 'x', 'timeZone': 'UTC'},
          'places': [
            {'name': 'Somewhere', 'category': 'attraction'},
          ],
        }),
      );
    await expectLater(
      friend.app.packages.importFile(bad),
      throwsA(isA<TripPackageException>().having((e) => e.detail, 'detail', contains('"lat" and "lng" are required'))),
    );
  });

  test('place category synonyms from hand-written files', () {
    expect(packagePlaceCategory('Train station'), PlaceCategory.railwayStation);
    expect(packagePlaceCategory('bus_terminal'), PlaceCategory.busStation);
    expect(packagePlaceCategory('food'), PlaceCategory.restaurant);
    expect(packagePlaceCategory('airport'), PlaceCategory.airport);
    expect(packagePlaceCategory('???'), PlaceCategory.other);
  });
}
