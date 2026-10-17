import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/app/app.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/app/service_registry.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_update_service.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';
import 'package:wanderplan/shared/infrastructure/media/media_storage.dart';

import '../domain/flight_status_test.dart' show answer, parse;
import '../helpers.dart';

void main() {
  late AppDatabase db;
  late MediaStorage media;
  final now = DateTime.utc(2026, 12, 12, 2);

  setUpAll(initTestEnvironment);
  setUp(() async {
    db = memoryDb();
    media = await tempMedia();
  });
  tearDown(() async {
    await db.close();
    await media.root.delete(recursive: true);
  });

  Future<(ServiceRegistry, MemorySecretStore, FakeFlightServer, String)> seed(
    WidgetTester tester, {
    String serverUrl = 'http://192.168.1.20:8080',
  }) async {
    final secrets = MemorySecretStore();
    final source = FakeFlightServer(statuses: {'MU5103': parse(answer(gate: 'B12', at: now))});
    late ServiceRegistry app;
    late String tripId;
    await tester.runAsync(() async {
      app = ServiceRegistry.create(
        db: db,
        media: media,
        tempDir: () async => media.root,
        clock: () => now,
        rateSource: FakeRateSource(const {}),
        placeSearch: FakePlaceSearch(),
        routeService: FakeRouteService(),
        reminderScheduler: FakeReminderScheduler(),
        flightServer: source,
        secretStore: secrets,
        serverUrl: serverUrl,
      );
      tripId = await app.trips.createTrip(TripDraft(title: 'Yunnan', timeZone: 'Asia/Shanghai'));
      await app.itinerary.addActivities(tripId, [
        ActivityDraft(
          title: 'KMG → XMN',
          kind: ActivityKind.flight,
          date: const LocalDate(2026, 12, 12),
          startMinute: 955,
          endMinute: 1105,
          serviceNumber: 'MU5103',
          bookingStatus: BookingStatus.booked,
        ),
        ActivityDraft(title: 'No number yet', kind: ActivityKind.flight, date: const LocalDate(2026, 12, 13)),
      ]);
    });
    return (app, secrets, source, tripId);
  }

  Future<void> pump(WidgetTester tester, ServiceRegistry app, String route) async {
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
          clockProvider.overrideWithValue(() => now),
          serviceRegistryProvider.overrideWithValue(app),
          mapTilesEnabledProvider.overrideWithValue(false),
          flightAutoCheckProvider.overrideWithValue(false),
        ],
        child: const WanderPlanApp(),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(WanderPlanApp))).read(routerProvider).go(route);
    await tester.pumpAndSettle();
  }

  testWidgets('Settings → Flight updates: nothing to fill in; the app signs in by itself', (tester) async {
    final (app, secrets, server, _) = await seed(tester);
    await pump(tester, app, Routes.flightUpdates);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing, reason: 'no server address or token to type');
    expect(find.text('On · signed in as demo@wanderplan.test'), findsOneWidget);
    expect(secrets.values[FlightUpdateService.tokenKey], 'token-0');
    expect(server.calls.first, 'sign-in 192.168.1.20');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('Settings → Flight updates: an unreachable server is explained with a retry', (tester) async {
    final (app, _, server, _) = await seed(tester);
    server.failure = FlightLookupFailure.network;
    await pump(tester, app, Routes.flightUpdates);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Can’t reach the WanderPlan server'), findsOneWidget);

    server.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('On · signed in as demo@wanderplan.test'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('Bookings: "Check now" shows the server\'s live status; flights without a number explain why', (tester) async {
    final (app, _, server, tripId) = await seed(tester);
    await pump(tester, app, Routes.bookings(tripId));

    expect(find.text('Add the flight number (e.g. MU5103) to get live updates.'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Check now'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(server.calls, contains(startsWith('refresh f-MU5103-2026-12-12')));
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.textContaining('Gate B12'), findsOneWidget);
    expect(find.textContaining('times are local at each airport'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('Bookings: a build without a server says live updates are not available', (tester) async {
    final (app, _, _, tripId) = await seed(tester, serverUrl: '');
    await pump(tester, app, Routes.bookings(tripId));
    expect(find.text('Live flight updates aren’t available in this version of the app.'), findsOneWidget);
    expect(find.text('Check now'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('saving a flight with "time to be decided" closes the editor without a crash', (tester) async {
    final (app, _, _, tripId) = await seed(tester);
    late String id;
    await tester.runAsync(() async {
      id = (await app.itinerary.activitiesOf(tripId)).firstWhere((a) => a.title == 'No number yet').id;
    });
    await pump(tester, app, Routes.editActivity(tripId, id));
    final list = find.descendant(of: find.byType(Scaffold).last, matching: find.byType(Scrollable)).first;
    final number = find.widgetWithText(TextField, 'Flight / train number');
    await tester.scrollUntilVisible(number, 200, scrollable: list);
    await tester.enterText(number, 'SL545');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    late Activity a;
    await tester.runAsync(() async => a = (await app.itinerary.getActivity(id))!);
    expect((a.serviceNumber, a.hasTime), ('SL545', false));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
