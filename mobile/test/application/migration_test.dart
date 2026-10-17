import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/places/application/saved_place_service.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

import '../helpers.dart';

void main() {
  setUpAll(initTestEnvironment);

  test('a v2 database upgrades to v3 keeping trips and gaining itinerary/budget tables', () async {
    final dir = await Directory.systemTemp.createTemp('wanderplan_mig3_');
    final file = File('${dir.path}/app.sqlite');
    var d = await TestDevice.create(db: AppDatabase(NativeDatabase(file)));
    final id = await d.app.trips.createTrip(TripDraft(title: 'Before v3', timeZone: 'UTC'));
    await d.db.close();

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('DROP TABLE expenses');
    raw.execute('DROP TABLE exchange_rates');
    raw.execute('DROP TABLE activities');
    raw.execute('PRAGMA user_version = 2');
    raw.dispose();

    d = await TestDevice.create(db: AppDatabase(NativeDatabase(file)));
    expect((await d.app.trips.getTrip(id))!.title, 'Before v3');
    await d.app.itinerary.addActivity(
      id,
      ActivityDraft(title: 'Works', date: const LocalDate(2026, 1, 1), startMinute: 600, endMinute: 660),
    );
    expect(await d.app.itinerary.activitiesOf(id), hasLength(1));
    await d.dispose();
    await dir.delete(recursive: true);
  });

  test('a v3 database upgrades to v4: existing activities keep their times', () async {
    final dir = await Directory.systemTemp.createTemp('wanderplan_mig4_');
    final file = File('${dir.path}/app.sqlite');
    var d = await TestDevice.create(db: AppDatabase(NativeDatabase(file)));
    final id = await d.app.trips.createTrip(TripDraft(title: 'Before v4', timeZone: 'UTC'));
    final a = await d.app.itinerary.addActivity(
      id,
      ActivityDraft(title: 'Timed', date: const LocalDate(2026, 1, 1), startMinute: 600, endMinute: 660),
    );
    await d.db.close();

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('ALTER TABLE activities DROP COLUMN has_time');
    raw.execute('PRAGMA user_version = 3');
    raw.dispose();

    d = await TestDevice.create(db: AppDatabase(NativeDatabase(file)));
    final got = (await d.app.itinerary.getActivity(a))!;
    expect((got.hasTime, got.startMinute, got.endMinute), (true, 600, 660));
    await d.app.itinerary.addActivity(id, ActivityDraft(title: 'Untimed', date: const LocalDate(2026, 1, 2)));
    expect((await d.app.itinerary.activitiesOf(id)).where((x) => !x.hasTime), hasLength(1));
    await d.dispose();
    await dir.delete(recursive: true);
  });

  test('a v4 database upgrades to v5 and gains saved places', () async {
    final dir = await Directory.systemTemp.createTemp('wanderplan_mig5_');
    final file = File('${dir.path}/app.sqlite');
    var d = await TestDevice.create(db: AppDatabase(NativeDatabase(file)));
    final id = await d.app.trips.createTrip(TripDraft(title: 'Before v5', timeZone: 'UTC'));
    await d.db.close();

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('DROP TABLE saved_places');
    raw.execute('PRAGMA user_version = 4');
    raw.dispose();

    d = await TestDevice.create(db: AppDatabase(NativeDatabase(file)));
    expect((await d.app.trips.getTrip(id))!.title, 'Before v5');
    await d.app.savedPlaces.savePlace(id, SavedPlaceDraft(name: 'Works', point: const GeoPoint(1, 2)));
    expect(await d.app.savedPlaces.placesOf(id), hasLength(1));
    await d.dispose();
    await dir.delete(recursive: true);
  });
}
