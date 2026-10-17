import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/app/app.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/app/service_registry.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/presentation/activity_editor_screen.dart';
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

  testWidgets('day panel: choose train/metro for a leg with your own time, then optimize and apply', (tester) async {
    final (id, app) = await seed(tester, FakeRouteService());
    await pumpMap(tester, id, app);
    await tester.tap(find.text('Dec 20'));
    await tester.pumpAndSettle();

    // The leg Louvre → Lunch: switch to train/metro/bus with 30 minutes.
    final panel = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Louvre → Lunch'), 100, scrollable: panel);
    await tester.tap(find.text('Louvre → Lunch'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Train / metro / bus'));
    await tester.enterText(find.byType(TextField).last, '30');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    late Activity lunch;
    await tester.runAsync(() async => lunch = (await app.itinerary.activitiesOf(id)).firstWhere((a) => a.title == 'Lunch'));
    expect((lunch.arrivalMode, lunch.arrivalMinutes), (TravelMode.transit, 30));
    await tester.scrollUntilVisible(find.textContaining('your estimate 30 min'), 100, scrollable: panel);

    // Optimize: preview, then apply.
    await tester.scrollUntilVisible(find.text('Optimize order'), 100, scrollable: panel);
    await tester.tap(find.text('Optimize order'));
    await tester.pumpAndSettle();
    expect(find.text('Suggested order'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Updated 2 activities'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('activity editor: opening hours, closed day and reservation with book-by date', (tester) async {
    final (id, app) = await seed(tester, FakeRouteService());
    late String louvreId;
    await tester.runAsync(
      () async => louvreId = (await app.itinerary.activitiesOf(id)).firstWhere((a) => a.title == 'Louvre').id,
    );
    await pumpMap(tester, id, app);
    ProviderScope.containerOf(
      tester.element(find.byType(WanderPlanApp)),
    ).read(routerProvider).push(Routes.editActivity(id, louvreId));
    await tester.pumpAndSettle();

    final list = find.descendant(of: find.byType(ActivityEditorScreen), matching: find.byType(Scrollable)).first;
    Future<void> show(Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: list);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }

    await show(find.text('Has opening hours'));
    await tester.tap(find.text('Has opening hours'));
    await tester.pumpAndSettle();
    // Dec 20, 2026 is a Sunday: mark Sunday closed and see the warning.
    await show(find.widgetWithText(FilterChip, 'Sun'));
    await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
    await tester.pumpAndSettle();
    expect(find.text('Closed on this day!'), findsOneWidget);

    await show(find.text('Needs a reservation or ticket in advance'));
    await tester.tap(find.text('Needs a reservation or ticket in advance'));
    await tester.pumpAndSettle();
    await show(find.widgetWithText(TextField, 'Book how many days before?'));
    await tester.enterText(find.widgetWithText(TextField, 'Book how many days before?'), '5');
    await tester.pumpAndSettle();
    expect(find.text('Book by Dec 15, 2026'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    late Activity a;
    await tester.runAsync(() async => a = (await app.itinerary.getActivity(louvreId))!);
    expect(a.openingHours!.closedWeekdays, {DateTime.sunday});
    expect((a.reservationRequired, a.bookAheadDays, a.bookBy), (true, 5, const LocalDate(2026, 12, 15)));
    await unmount(tester);
  });
}
