import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

import '../helpers.dart';

void main() {
  setUpAll(initTestEnvironment);

  test('trips, banners and settings survive closing and reopening the database', () async {
    final dir = await Directory.systemTemp.createTemp('wanderplan_db_');
    final file = File('${dir.path}/app.sqlite');
    final media = await tempMedia();

    var d = await TestDevice.create(db: AppDatabase(NativeDatabase(file)), media: media);
    final id = await d.app.trips.createTrip(
      TripDraft(
        title: 'Persisted',
        timeZone: 'Europe/Lisbon',
        startDate: const LocalDate(2027, 4, 2),
        endDate: const LocalDate(2027, 4, 9),
        destinations: [const Destination(country: 'Portugal', city: 'Lisbon')],
        coverImageSourcePath: await fakeImage(),
      ),
    );
    await d.app.settings.set('locale', 'th');
    await d.db.close();

    // Simulates an app restart.
    d = await TestDevice.create(db: AppDatabase(NativeDatabase(file)), media: media);
    final t = (await d.app.trips.getTrip(id))!;
    expect(t.title, 'Persisted');
    expect(t.durationDays, 8);
    expect(t.destinations.single.city, 'Lisbon');
    expect(t.banner.kind, BannerKind.photo);
    expect(media.resolve(t.banner.imagePath!).existsSync(), isTrue);
    expect(await d.app.settings.get('locale'), 'th');
    await d.dispose();
    await dir.delete(recursive: true);
  });
}
