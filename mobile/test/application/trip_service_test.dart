import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/checklist/application/checklist_service.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/contexts/trip/application/trip_queries.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../helpers.dart';

void main() {
  late TestDevice d;
  setUpAll(initTestEnvironment);
  setUp(() async => d = await TestDevice.create());
  tearDown(() => d.dispose());

  TripDraft draft(String title, {String zone = 'Asia/Tokyo'}) => TripDraft(title: title, timeZone: zone);
  Future<TripSummary> summary(String id) async => (await d.app.tripQueries.watchSummary(id).first)!;

  test('a trip can be created with only a title; blank titles are rejected', () async {
    final id = await d.app.trips.createTrip(draft('  Weekend away  '));
    final t = (await d.app.trips.getTrip(id))!;
    expect(t.title, 'Weekend away');
    expect(t.startDate, isNull);
    expect(t.destinations, isEmpty);
    expect(t.banner.kind, BannerKind.gradient);
    await expectLater(d.app.trips.createTrip(draft('   ')), throwsA(isA<DomainException>()));
  });

  test('multiple trips are independent', () async {
    final a = await d.app.trips.createTrip(
      draft('Japan')
        ..destinations = [const Destination(country: 'Japan', city: 'Kyoto')]
        ..currency = 'jpy'
        ..totalBudget = 300000,
    );
    final b = await d.app.trips.createTrip(
      draft('Peru', zone: 'America/Lima')
        ..destinations = [const Destination(country: 'Peru', city: 'Cusco')]
        ..currency = 'PEN',
    );

    await d.app.trips.updateTrip(
      a,
      draft('Japan autumn')
        ..destinations = [const Destination(country: 'Japan', city: 'Osaka'), const Destination(city: 'Nara')]
        ..startDate = const LocalDate(2026, 11, 1)
        ..endDate = const LocalDate(2026, 11, 9)
        ..travelerCount = 3
        ..currency = 'JPY',
    );

    final ta = (await d.app.trips.getTrip(a))!;
    final tb = (await d.app.trips.getTrip(b))!;
    expect(ta.title, 'Japan autumn');
    expect(ta.currency, 'JPY');
    expect(ta.destinations.map(destinationLabel), ['Osaka, Japan', 'Nara']);
    expect(ta.durationDays, 9);
    expect(tb.title, 'Peru');
    expect(tb.timeZone, 'America/Lima');
    expect(tb.destinations.single.city, 'Cusco');
    expect(tb.startDate, isNull);
  });

  test('new trips appear first and reorder persists', () async {
    final a = await d.app.trips.createTrip(draft('A'));
    final b = await d.app.trips.createTrip(draft('B'));
    final c = await d.app.trips.createTrip(draft('C'));
    expect((await d.app.tripQueries.watchSummaries().first).map((t) => t.id), [c, b, a]);
    await d.app.trips.reorder([a, c, b]);
    expect((await d.app.tripQueries.watchSummaries().first).map((t) => t.id), [a, c, b]);
  });

  test('duplicate copies details, banner image and checklist but not photos', () async {
    final src = await d.app.trips.createTrip(
      draft('Iceland')
        ..destinations = [const Destination(country: 'Iceland', city: 'Reykjavík')]
        ..coverImageSourcePath = await fakeImage(),
    );
    await d.app.gallery.addPhotos(src, [await fakeImage('2.jpg')]);
    final original = (await d.app.trips.getTrip(src))!;
    await d.app.trips.saveBanner(src, original.banner.copyWith(scale: 2.5, alignX: -0.4));
    final todo = await d.app.checklist.addItems(src, [TodoDraft(title: 'Pack'), TodoDraft(title: 'Insurance')]);
    await d.app.checklist.setDone(todo.first, true);

    final copy = await d.app.trips.duplicateTrip(src, titleSuffix: ' (copy)');
    final c = await summary(copy);
    expect(c.trip.title, 'Iceland (copy)');
    expect(c.destinations.single.city, 'Reykjavík');
    expect(c.photoCount, 0);
    expect((c.banner.scale, c.banner.alignX), (2.5, -0.4));
    expect(c.banner.imagePath, isNot(original.banner.imagePath));
    expect((c.todosDone, c.todosTotal), (0, 2));

    await d.app.trips.deleteTrip(src);
    expect(d.media.resolve(c.banner.imagePath!).existsSync(), isTrue);
    expect(await d.app.checklist.itemsOf(src), isEmpty);
  });

  test('cover image at creation becomes a photo banner and a gallery photo', () async {
    final id = await d.app.trips.createTrip(draft('Bali')..coverImageSourcePath = await fakeImage());
    final s = await summary(id);
    expect(s.banner.kind, BannerKind.photo);
    expect(s.photoCount, 1);
    expect(d.media.resolve(s.banner.imagePath!).existsSync(), isTrue);
  });

  test('banner edits round-trip all metadata', () async {
    final id = await d.app.trips.createTrip(draft('Banner'));
    final rel = await d.app.trips.importBannerImage(id, await fakeImage());
    final cfg = const BannerConfig(colorA: 0xFF112233).copyWith(
      kind: BannerKind.photo,
      imagePath: rel,
      scale: 1.8,
      alignX: 0.25,
      alignY: -0.75,
      colorB: 0xFF445566,
      showTitle: false,
      titlePlacement: TitlePlacement.center,
      textColor: 0xFF000000,
      style: BannerStyle.framed,
    );
    await d.app.trips.saveBanner(id, cfg);
    expect((await d.app.trips.getTrip(id))!.banner, cfg);
  });

  test('photos: favorite, caption, set as cover, delete falls back to colors', () async {
    final id = await d.app.trips.createTrip(draft('Photos'));
    final ids = await d.app.gallery.addPhotos(id, [await fakeImage('a.jpg'), await fakeImage('b.jpg')]);
    await d.app.gallery.updatePhoto(ids.first, caption: ' Sunset ', isFavorite: true);
    final p = (await d.app.gallery.photosOf(id)).firstWhere((x) => x.id == ids.first);
    expect((p.caption, p.isFavorite), ('Sunset', true));

    await d.app.trips.setPhotoAsCover(id, p);
    expect((await d.app.trips.getTrip(id))!.banner.imagePath, p.relPath);

    await d.app.gallery.deletePhoto(p);
    final s = await summary(id);
    expect(s.photoCount, 1);
    expect(s.banner.imagePath, isNull);
    expect(s.banner.kind, isNot(BannerKind.photo));
    expect(d.media.resolve(p.relPath).existsSync(), isFalse);
  });

  test('deleting a trip cascades children and removes its media folder', () async {
    final keep = await d.app.trips.createTrip(draft('Keep')..coverImageSourcePath = await fakeImage());
    final gone = await d.app.trips.createTrip(
      draft('Gone')
        ..destinations = [const Destination(city: 'X')]
        ..coverImageSourcePath = await fakeImage(),
    );
    await d.app.checklist.addItems(gone, [TodoDraft(title: 'x')]);

    await d.app.trips.deleteTrip(gone);
    expect(await d.app.trips.getTrip(gone), isNull);
    expect(await d.db.select(d.db.tripDestinations).get(), isEmpty);
    expect(await d.db.select(d.db.tripTodos).get(), isEmpty);
    expect((await d.db.select(d.db.tripPhotos).get()).map((p) => p.tripId), [keep]);
    expect(Directory('${d.media.root.path}/trips/$gone').existsSync(), isFalse);
    expect(Directory('${d.media.root.path}/trips/$keep').existsSync(), isTrue);
  });

  test('archive toggles without affecting other fields', () async {
    final id = await d.app.trips.createTrip(draft('Old trip')..travelerCount = 4);
    await d.app.trips.setArchived(id, true);
    final t = (await d.app.trips.getTrip(id))!;
    expect(t.status(DateTime.now()), TripStatus.archived);
    expect(t.travelerCount, 4);
    await d.app.trips.setArchived(id, false);
    expect((await d.app.trips.getTrip(id))!.archived, isFalse);
  });

  test('clearing dates clears departure time and confirmation', () async {
    final id = await d.app.trips.createTrip(
      draft('Dates')
        ..startDate = const LocalDate(2026, 12, 1)
        ..endDate = const LocalDate(2026, 12, 5)
        ..departureTime = '07:15'
        ..datesConfirmed = true,
    );
    var t = (await d.app.trips.getTrip(id))!;
    expect(t.status(DateTime.utc(2026, 11, 1)), TripStatus.upcoming);

    await d.app.trips.updateTrip(
      id,
      TripDraft.fromTrip(t)
        ..startDate = null
        ..endDate = null,
    );
    t = (await d.app.trips.getTrip(id))!;
    expect((t.startDate, t.departureTime, t.datesConfirmed), (null, null, false));
    expect(t.status(DateTime.utc(2026, 11, 1)), TripStatus.planning);
  });

  test('deleteAllData wipes trips, settings and media', () async {
    await d.app.trips.createTrip(draft('One')..coverImageSourcePath = await fakeImage());
    await d.app.settings.set('locale', 'th');
    await d.app.data.deleteAllData();
    expect(await d.app.tripQueries.watchSummaries().first, isEmpty);
    expect(await d.app.settings.get('locale'), isNull);
    expect(d.media.root.listSync(), isEmpty);
  });
}
