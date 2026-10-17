import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/budget/application/budget_service.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/contexts/checklist/application/checklist_service.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/sharing/application/trip_package_service.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../helpers.dart';

void main() {
  setUpAll(initTestEnvironment);

  // "Me" and "my friend" each have their own device.
  late TestDevice me, friend;
  late Directory tmp;
  setUp(() async {
    me = await TestDevice.create();
    friend = await TestDevice.create();
    tmp = await Directory.systemTemp.createTemp('wanderplan_share_');
  });
  tearDown(() async {
    await me.dispose();
    await friend.dispose();
  });

  Future<String> makeTrip() async {
    final id = await me.app.trips.createTrip(
      TripDraft(
        title: 'Seoul / Busan',
        timeZone: 'Asia/Seoul',
        startDate: const LocalDate(2026, 12, 20),
        endDate: const LocalDate(2026, 12, 28),
        datesConfirmed: true,
        travelerCount: 2,
        currency: 'KRW',
        totalBudget: 2500000,
        destinations: [
          const Destination(city: 'Seoul', country: 'South Korea'),
          const Destination(city: 'Busan'),
        ],
        coverImageSourcePath: await fakeImage(),
      ),
    );
    final t = (await me.app.trips.getTrip(id))!;
    await me.app.trips.saveBanner(id, t.banner.copyWith(scale: 1.6, style: BannerStyle.bold));
    final photoIds = await me.app.gallery.addPhotos(id, [await fakeImage('x.jpg')]);
    await me.app.gallery.updatePhoto(photoIds.single, caption: 'Gyeongbokgung', isFavorite: true);
    final todoIds = await me.app.checklist.addItems(id, [
      TodoDraft(title: 'K-ETA', category: TodoCategory.documents, dueDate: const LocalDate(2026, 12, 1)),
      TodoDraft(title: 'T-money card'),
    ]);
    await me.app.checklist.setDone(todoIds.first, true);
    return id;
  }

  test('a friend imports a full copy of my trip, independent of mine', () async {
    final mine = await makeTrip();
    final file = await me.app.packages.exportTrip(mine);
    expect(file.path, endsWith('Seoul Busan.wanderplan'));

    final theirs = await friend.app.packages.importFile(file);
    final s = (await friend.app.tripQueries.watchSummary(theirs).first)!;
    final t = s.trip;
    expect(t.title, 'Seoul / Busan');
    expect(t.timeZone, 'Asia/Seoul');
    expect((t.startDate, t.endDate), (const LocalDate(2026, 12, 20), const LocalDate(2026, 12, 28)));
    expect((t.travelerCount, t.currency, t.totalBudget), (2, 'KRW', 2500000));
    expect(t.destinations.map(destinationLabel), ['Seoul, South Korea', 'Busan']);
    expect((t.banner.kind, t.banner.scale, t.banner.style), (BannerKind.photo, 1.6, BannerStyle.bold));
    expect(friend.media.resolve(t.banner.imagePath!).existsSync(), isTrue);
    expect(s.photoCount, 2);
    final photos = await friend.app.gallery.photosOf(theirs);
    expect(photos.where((p) => p.caption == 'Gyeongbokgung').single.isFavorite, isTrue);
    final todos = await friend.app.checklist.itemsOf(theirs);
    expect(todos.map((x) => (x.title, x.isDone)).toSet(), {('K-ETA', true), ('T-money card', false)});

    await friend.app.trips.setArchived(theirs, true);
    expect((await me.app.trips.getTrip(mine))!.archived, isFalse);
  });

  test('importing the same file twice creates two separate trips', () async {
    final file = await me.app.packages.exportTrip(await makeTrip());
    final a = await friend.app.packages.importFile(file);
    final b = await friend.app.packages.importFile(file);
    expect(a, isNot(b));
    expect(await friend.app.tripQueries.watchSummaries().first, hasLength(2));
  });

  test('without gallery photos only the banner image is sent', () async {
    final file = await me.app.packages.exportTrip(await makeTrip(), includePhotos: false);
    final theirs = await friend.app.packages.importFile(file);
    final s = (await friend.app.tripQueries.watchSummary(theirs).first)!;
    expect(s.banner.kind, BannerKind.photo);
    expect(s.photoCount, 1);
  });

  test('rejects non-packages, newer versions and invalid trips without leaving data behind', () async {
    final junk = File('${tmp.path}/junk.wanderplan')..writeAsStringSync('hello');
    await expectLater(
      friend.app.packages.importFile(junk),
      throwsA(isA<TripPackageException>().having((e) => e.error, 'error', TripPackageError.invalid)),
    );

    final newer = File('${tmp.path}/newer.json')
      ..writeAsStringSync(
        jsonEncode({
          'format': tripPackageFormat,
          'schemaVersion': 99,
          'trip': {'title': 'x'},
        }),
      );
    await expectLater(
      friend.app.packages.importFile(newer),
      throwsA(isA<TripPackageException>().having((e) => e.error, 'error', TripPackageError.tooNew)),
    );

    final noTitle = File('${tmp.path}/notitle.json')
      ..writeAsStringSync(
        jsonEncode({
          'format': tripPackageFormat,
          'schemaVersion': 1,
          'trip': {'title': ' '},
        }),
      );
    await expectLater(friend.app.packages.importFile(noTitle), throwsA(isA<TripPackageException>()));

    expect(await friend.app.tripQueries.watchSummaries().first, isEmpty);
  });

  test('a bare trip.json without media imports with a color banner', () async {
    final json = File('${tmp.path}/trip.json')
      ..writeAsStringSync(
        jsonEncode({
          'format': tripPackageFormat,
          'schemaVersion': 1,
          'trip': {'title': 'From JSON', 'timeZone': 'Europe/Paris'},
          'banner': {'kind': 'photo', 'image': 'media/0.jpg', 'colorA': '#112233'},
        }),
      );
    final id = await friend.app.packages.importFile(json);
    final t = (await friend.app.trips.getTrip(id))!;
    expect(t.title, 'From JSON');
    expect(t.banner.kind, BannerKind.gradient);
    expect(t.banner.colorA, 0xFF112233);
    expect(t.banner.imagePath, isNull);
  });

  test('the documented template in Example/ imports correctly (schema v3)', () async {
    final id = await friend.app.packages.importFile(File('../Example/trip_template.json'));
    final t = (await friend.app.trips.getTrip(id))!;
    expect(t.title, 'Autumn in Chengdu & Chongqing');
    expect((t.timeZone, t.currency, t.travelerCount), ('Asia/Shanghai', 'CNY', 2));
    expect(t.durationDays, 9);
    expect(t.destinations.map((d) => d.city), ['Chengdu', 'Chongqing']);
    expect(t.banner.colorA, 0xFF0E7C6B);
    final todos = await friend.app.checklist.itemsOf(id);
    expect(todos, hasLength(5));
    expect(todos.first.title, 'Check visa and entry requirements'); // earliest due date first

    final acts = await friend.app.itinerary.activitiesOf(id);
    expect(acts, hasLength(8));
    final hotel = acts.firstWhere((a) => a.title == 'Hotel in Chengdu');
    expect((hotel.kind, hotel.nights.length), (ActivityKind.hotel, 4));
    final train = acts.firstWhere((a) => a.kind == ActivityKind.train);
    expect(train.destination.name, 'Chongqing West Railway Station');
    expect(acts.every((a) => a.location.point == null), isTrue, reason: 'the template invents no coordinates');

    final report = await friend.app.budget.watchReport(id).first;
    expect(report.unconvertedCurrencies, isEmpty);
    // 9000 THB*0.2 + 2400 + 300 + 110 + 300 + 2000 CNY + 1200 THB*0.2 + 15 USD*7.1 + 1000 CNY
    expect(report.planned, closeTo(1800 + 2400 + 300 + 110 + 300 + 2000 + 240 + 106.5 + 1000, 1e-6));
    expect((await friend.app.budget.ratesOf(id)).every((r) => r.isManual), isTrue);

    // Day-planning fields: travel modes, opening hours, reservation reminder.
    final panda = acts.firstWhere((a) => a.title == 'Giant Panda Breeding Base');
    expect((panda.openingHours?.opens, panda.openingHours?.closes), (450, 1080));
    expect((panda.reservationRequired, panda.bookAheadDays, panda.remindToBook), (true, 3, true));
    expect(panda.bookBy, const LocalDate(2026, 11, 18));
    expect(acts.firstWhere((a) => a.kind == ActivityKind.train).arrivalMode, TravelMode.transit);
    expect(acts.firstWhere((a) => a.title == 'Hotpot dinner').arrivalMode, TravelMode.walking);
    final day = (await friend.app.itinerary.daySettingsOf(id)).single;
    expect((day.date, day.endArrivalMode, day.endArrivalMinutes), (const LocalDate(2026, 11, 21), TravelMode.transit, 30));
    // Saved places carry real (OpenStreetMap) coordinates.
    final places = await friend.app.savedPlaces.placesOf(id);
    expect(places.map((p) => p.name), contains('Hongyadong'));
    expect(places.every((p) => p.source == 'import'), isTrue);
  });

  test('itinerary, expenses and rates round-trip; booking references stay private by default', () async {
    final mine = await makeTrip();
    final flight = await me.app.itinerary.addActivity(
      mine,
      ActivityDraft(
        title: 'KE 652',
        kind: ActivityKind.flight,
        date: const LocalDate(2026, 12, 20),
        startMinute: 23 * 60,
        endDate: const LocalDate(2026, 12, 21),
        endMinute: 6 * 60 + 30,
        location: const PlaceRef(name: 'BKK', point: GeoPoint(13.69, 100.75), source: 'map'),
        destination: const PlaceRef(name: 'ICN'),
        cost: 12000,
        currency: 'THB',
        bookingStatus: BookingStatus.confirmed,
        bookingReference: 'SECRET1',
        isLocked: true,
      ),
    );
    await me.app.budget.addExpense(mine, ExpenseDraft(title: 'Seat', amount: 900, currency: 'THB', activityId: flight));
    await me.app.budget.setManualRate(mine, 'THB', 38.5);

    final theirs = await friend.app.packages.importFile(await me.app.packages.exportTrip(mine));
    final a = (await friend.app.itinerary.activitiesOf(theirs)).single;
    expect(
      (a.title, a.lastDate, a.endMinute, a.isLocked),
      ('KE 652', const LocalDate(2026, 12, 21), 6 * 60 + 30, true),
    );
    expect(a.location.point, const GeoPoint(13.69, 100.75));
    expect(a.destination.name, 'ICN');
    expect(a.bookingReference, isNull);
    final e = (await friend.app.budget.expensesOf(theirs)).single;
    expect((e.title, e.kind, e.activityId), ('Seat', ExpenseKind.actual, a.id));
    expect((await friend.app.budget.ratesOf(theirs)).single.rate, 38.5);

    final withPrivate = await friend.app.packages.importFile(
      await me.app.packages.exportTrip(mine, includePrivate: true),
    );
    expect((await friend.app.itinerary.activitiesOf(withPrivate)).single.bookingReference, 'SECRET1');
  });

  test('a bad activity in a hand-written file is reported by name and nothing is imported', () async {
    final f = File('${tmp.path}/bad.json')
      ..writeAsStringSync(
        jsonEncode({
          'format': tripPackageFormat,
          'schemaVersion': 2,
          'trip': {'title': 'Bad'},
          'activities': [
            {'title': 'Backwards', 'date': '2026-01-01', 'start': '10:00', 'end': '09:00'},
          ],
        }),
      );
    await expectLater(
      friend.app.packages.importFile(f),
      throwsA(isA<TripPackageException>().having((e) => e.detail, 'detail', contains('Backwards'))),
    );
    expect(await friend.app.tripQueries.watchSummaries().first, isEmpty);
  });

  test('the real-trip example in Example/ imports with flights, coordinates, reservations and places', () async {
    final id = await friend.app.packages.importFile(File('../Example/china_winter_trip_2026.json'));
    final acts = await friend.app.itinerary.activitiesOf(id);
    expect(acts, hasLength(33));
    final alts = acts.where((a) => a.title.startsWith('ALT:')).toList();
    expect(alts, hasLength(2));
    expect(alts.every((a) => a.isOptional && a.cost == null && a.bookingStatus == BookingStatus.notBooked), isTrue);
    final leg1 = acts.firstWhere((a) => a.title.startsWith('Flight: Kunming → Xiamen'));
    expect((leg1.startMinute, leg1.endMinute, leg1.cost, leg1.remindToBook), (955, 1105, 7610.0, true));
    expect(leg1.location.point, isNotNull, reason: 'airport coordinates from OpenStreetMap');
    final leg2 = acts.firstWhere((a) => a.title.startsWith('Flight: Xiamen → Bangkok'));
    expect((leg2.startMinute, leg2.endMinute), (16 * 60 + 20, 19 * 60 + 45), reason: '18:45 Bangkok = 19:45 China time');
    expect(acts.where((a) => a.location.point != null || a.destination.point != null), hasLength(18));
    expect(acts.firstWhere((a) => a.title == 'Jiuzhaigou National Park').reservationRequired, isTrue);
    expect(await friend.app.savedPlaces.placesOf(id), hasLength(4));
    expect(await friend.app.itinerary.daySettingsOf(id), hasLength(2));
    final report = await friend.app.budget.watchReport(id).first;
    // Planned = itemised return ticket + planned expenses (no double count, alternatives excluded).
    expect(report.planned, closeTo(7610 + (22000 - 7610) + 5000 + 10300 + 3000 + 1600 + 1500 + 1500 + 2600 + 1000 + 1000, 1e-6));
  });
}
