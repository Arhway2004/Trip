import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/app/app.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/app/service_registry.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/application/location_link_service.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';
import 'package:wanderplan/shared/infrastructure/media/media_storage.dart';

import '../helpers.dart';

class _Expander implements LinkExpander {
  @override
  Future<Uri> expand(Uri shortLink) async =>
      Uri.parse('https://www.google.com/maps/place/x/@27.8123867,99.7021871,17z/data=!3d27.812382!4d99.704762');
}

PlaceResult _r(String name, String address, double lat, double lng) =>
    PlaceResult(name: name, address: address, point: GeoPoint(lat, lng), source: 'search:openstreetmap-nominatim');

void main() {
  late AppDatabase db;
  late MediaStorage media;
  final fixedNow = DateTime.utc(2026, 10, 16, 3);

  setUpAll(initTestEnvironment);
  setUp(() async {
    db = memoryDb();
    media = await tempMedia();
  });
  tearDown(() async {
    await db.close();
    await media.root.delete(recursive: true);
  });

  testWidgets('find locations: ranked matches, placeholders not pre-selected, paste a Google link', (tester) async {
    late String id;
    late ServiceRegistry app;
    await tester.runAsync(() async {
      app = ServiceRegistry.create(
        db: db,
        media: media,
        tempDir: () async => media.root,
        clock: () => fixedNow,
        rateSource: FakeRateSource(const {}),
        placeSearch: FakePlaceSearch(
          byQuery: {
            'Xiamen, China': [_r('厦门市', '', 24.4798, 118.0894)],
            'Shangri-La, China': [_r('香格里拉市', '', 27.8256, 99.7065)],
            '中山路步行街': [
              _r('中山路步行街', '宜昌市, 湖北省', 30.69, 111.28),
              _r('中山路步行街', '思明区, 厦门市', 24.455, 118.08),
            ],
            'Xiamen hotel': [_r('Some Xiamen Hotel', '厦门市', 24.46, 118.09)],
          },
        ),
        routeService: FakeRouteService(),
        linkExpander: _Expander(),
      );
      id = await app.trips.createTrip(
        TripDraft(
          title: 'China',
          timeZone: 'Asia/Shanghai',
          destinations: [
            const Destination(city: 'Xiamen', country: 'China'),
            const Destination(city: 'Shangri-La', country: 'China'),
          ],
        ),
      );
      await app.itinerary.addActivities(id, [
        ActivityDraft(title: 'Stroll', date: const LocalDate(2026, 12, 12), location: const PlaceRef(name: '中山路步行街')),
        ActivityDraft(
          title: 'Xiamen hotel — night 10',
          kind: ActivityKind.hotel,
          date: const LocalDate(2026, 12, 12),
          location: const PlaceRef(name: 'Xiamen hotel'),
        ),
        ActivityDraft(title: 'Old town', date: const LocalDate(2026, 12, 7), location: const PlaceRef(name: '独克宗古城')),
      ]);
    });

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Always unmount (even on failure) so drift streams close before db.close().
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mediaStorageProvider.overrideWithValue(media),
          clockProvider.overrideWithValue(() => fixedNow),
          serviceRegistryProvider.overrideWithValue(app),
          mapTilesEnabledProvider.overrideWithValue(false),
        ],
        child: const WanderPlanApp(),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(WanderPlanApp))).read(routerProvider).go(Routes.locatePlaces(id));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    // No match for 独克宗古城 (first in plan order).
    expect(find.textContaining('No match for “独克宗古城”'), findsOneWidget);
    // Xiamen's street ranks above the same-named street in Yichang, which is flagged.
    await tester.scrollUntilVisible(find.textContaining('km from your destinations'), 200, scrollable: list);
    expect(find.textContaining('思明区'), findsOneWidget);
    // The generic "Xiamen hotel" is flagged and not pre-selected.
    await tester.scrollUntilVisible(find.text('General name: choose the exact place yourself'), 200, scrollable: list);
    expect(find.text('Use selected matches (1)'), findsOneWidget);

    await tester.tap(find.text('Use selected matches (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Located'), findsOneWidget);

    // "Search again" opens and closes cleanly (regression: its text controller
    // was disposed while the dialog was still animating out).
    await tester.scrollUntilVisible(find.textContaining('No match for'), -200, scrollable: list);
    final card = find.ancestor(of: find.text('独克宗古城'), matching: find.byType(Card));
    await tester.tap(find.descendant(of: card, matching: find.text('Search again')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '独克宗古城 香格里拉');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: card, matching: find.text('Search again')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No match for “独克宗古城 香格里拉”'), findsOneWidget);

    // Paste the user's Google short link for the old town.
    await tester.scrollUntilVisible(find.textContaining('No match for'), -200, scrollable: list);
    final oldTownCard = find.ancestor(of: find.text('独克宗古城'), matching: find.byType(Card));
    await tester.tap(find.descendant(of: oldTownCard, matching: find.text('Paste link')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'https://maps.app.goo.gl/u591UoQLRBQNyBD29');
    await tester.pump();
    await tester.tap(find.text('Use location'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: oldTownCard, matching: find.text('Located')), findsOneWidget);
    expect(find.textContaining('Converted from China’s map offset'), findsOneWidget);

    late List<Activity> acts;
    await tester.runAsync(() async => acts = await app.itinerary.activitiesOf(id));
    final stroll = acts.firstWhere((a) => a.title == 'Stroll');
    expect(stroll.location.point!.latitude, closeTo(24.455, 1e-6));
    final oldTown = acts.firstWhere((a) => a.title == 'Old town');
    expect(oldTown.location.source, 'link:google');
    expect(Gcj02.fromWgs84(oldTown.location.point!).distanceKmTo(const GeoPoint(27.812382, 99.704762)), lessThan(0.001));
    expect(acts.firstWhere((a) => a.kind == ActivityKind.hotel).location.point, isNull, reason: 'never auto-picked');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
