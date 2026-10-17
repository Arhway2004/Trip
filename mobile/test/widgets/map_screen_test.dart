import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/app/app.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/app/service_registry.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/application/saved_place_service.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';
import 'package:wanderplan/shared/infrastructure/media/media_storage.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late MediaStorage media;
  final fixedNow = DateTime.utc(2026, 10, 16, 3);
  const louvre = GeoPoint(48.8606, 2.3376), eiffel = GeoPoint(48.8584, 2.2945);
  const gareDeLyon = PlaceResult(
    name: 'Gare de Lyon',
    address: 'Paris 12e',
    point: GeoPoint(48.8443, 2.3744),
    source: 'search:openstreetmap-nominatim',
    category: PlaceCategory.railwayStation,
  );

  setUpAll(initTestEnvironment);
  setUp(() async {
    db = memoryDb();
    media = await tempMedia();
  });
  tearDown(() async {
    await db.close();
    await media.root.delete(recursive: true);
  });

  Future<(String, ServiceRegistry)> seed(WidgetTester tester, FakeRouteService routes) async {
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
          results: [gareDeLyon],
          nearbyResults: {
            PlaceCategory.railwayStation: [gareDeLyon],
          },
        ),
        routeService: routes,
        locationService: const FakeLocationService(null),
      );
      id = await app.trips.createTrip(
        TripDraft(
          title: 'Paris',
          timeZone: 'Europe/Paris',
          startDate: const LocalDate(2026, 12, 20),
          endDate: const LocalDate(2026, 12, 22),
        ),
      );
      await app.itinerary.addActivities(id, [
        ActivityDraft(
          title: 'Louvre',
          date: const LocalDate(2026, 12, 20),
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          location: const PlaceRef(name: 'Louvre', point: louvre, source: 'map'),
        ),
        ActivityDraft(
          title: 'Lunch',
          kind: ActivityKind.food,
          date: const LocalDate(2026, 12, 20),
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          location: const PlaceRef(name: 'Lunch', point: eiffel, source: 'map'),
        ),
      ]);
      await app.savedPlaces.savePlace(id, SavedPlaceDraft(name: 'Musée d’Orsay', point: const GeoPoint(48.86, 2.3266)));
    });
    return (id, app);
  }

  Future<void> unmount(WidgetTester tester) async {
    // Dispose providers (timers, drift streams) before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pumpMap(WidgetTester tester, String id, ServiceRegistry app) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mediaStorageProvider.overrideWithValue(media),
          deviceTimeZoneProvider.overrideWithValue('Europe/Paris'),
          clockProvider.overrideWithValue(() => fixedNow),
          serviceRegistryProvider.overrideWithValue(app),
          mapTilesEnabledProvider.overrideWithValue(false),
        ],
        child: const WanderPlanApp(),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(WanderPlanApp))).read(routerProvider).go(Routes.tripMap(id));
    await tester.pumpAndSettle();
  }

  testWidgets('day route uses the routing provider; mode switch re-routes; places can be found and saved', (
    tester,
  ) async {
    final routes = FakeRouteService();
    final (id, app) = await seed(tester, routes);
    await pumpMap(tester, id, app);

    expect(find.textContaining('OpenStreetMap ·'), findsOneWidget, reason: 'Paris uses OpenStreetMap');
    expect(find.text('1'), findsWidgets, reason: 'saved places badge');

    // One day: a real road route between the two timed stops.
    await tester.tap(find.text('Dec 20'));
    await tester.pumpAndSettle();
    expect(routes.calls.single.$2, TravelMode.walking);
    expect(routes.calls.single.$1, [louvre, eiffel]);
    expect(find.textContaining('about'), findsOneWidget);
    expect(find.textContaining('Road routes: test-routing'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.directions_bike));
    await tester.pumpAndSettle();
    expect(routes.calls.last.$2, TravelMode.cycling);

    // Explore nearby railway stations and save one.
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Railway stations'));
    await tester.tap(find.widgetWithText(FilterChip, 'Railway stations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.train_outlined).first); // The marker (the chip comes later in the tree).
    await tester.pumpAndSettle();
    expect(find.text('Coordinates from OpenStreetMap search'), findsOneWidget);
    await tester.tap(find.text('Save place'));
    await tester.pumpAndSettle();
    expect(find.text('Saved to this trip'), findsOneWidget);
    late List<String> names;
    await tester.runAsync(() async => names = [for (final p in await app.savedPlaces.placesOf(id)) p.name]);
    expect(names, containsAll(['Musée d’Orsay', 'Gare de Lyon']));

    // Location permission denied is explained, not silently ignored.
    await tester.pump(const Duration(seconds: 5)); // Let the "saved" snackbar go.
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My location'));
    await tester.pumpAndSettle();
    expect(find.text('Location permission was denied'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('without a routing provider, legs are drawn straight and labelled unverified', (tester) async {
    final (id, app) = await seed(tester, FakeRouteService(fail: true));
    await pumpMap(tester, id, app);
    await tester.tap(find.text('Dec 20'));
    await tester.pumpAndSettle();
    expect(find.text('1 leg has no road route: straight line, unverified'), findsOneWidget);
    expect(find.textContaining('about'), findsNothing, reason: 'no distance or time is invented');
    await unmount(tester);
  });

  testWidgets('the marker filter hides plan pins by kind', (tester) async {
    final (id, app) = await seed(tester, FakeRouteService());
    await pumpMap(tester, id, app);
    // The lunch pin and the "Restaurants" explore chip share the icon.
    final before = find.byIcon(Icons.restaurant_outlined).evaluate().length;
    await tester.tap(find.byTooltip('Filter markers'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Food').first);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // Close the sheet.
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.restaurant_outlined).evaluate().length, before - 1);
    await unmount(tester);
  });

  testWidgets('pins at the same spot merge into one numbered marker that lists them', (tester) async {
    final (id, app) = await seed(tester, FakeRouteService());
    await tester.runAsync(
      () => app.itinerary.addActivity(
        id,
        ActivityDraft(
          title: 'Louvre again',
          date: const LocalDate(2026, 12, 21),
          location: const PlaceRef(name: 'Louvre', point: louvre, source: 'map'),
        ),
      ),
    );
    await pumpMap(tester, id, app);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Louvre'), findsOneWidget);
    expect(find.text('Louvre again · Louvre'), findsOneWidget);
    await unmount(tester);
  });
}
