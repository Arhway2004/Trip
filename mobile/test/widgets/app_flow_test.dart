import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/app/app.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/shared/infrastructure/media/media_storage.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/app/service_registry.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late MediaStorage media;
  // 2026-10-16 10:00 in Bangkok.
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

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Always unmount (even when a test fails) so live DB streams close before db.close().
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mediaStorageProvider.overrideWithValue(media),
          deviceTimeZoneProvider.overrideWithValue('Asia/Bangkok'),
          clockProvider.overrideWithValue(() => fixedNow),
        ],
        child: const WanderPlanApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    // Dispose providers (and their timers / drift streams) before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets(
    'empty state, create a trip with only a title, see its dashboard',
    (tester) async {
      await pumpApp(tester);
      expect(find.text('No trips yet'), findsOneWidget);
      expect(
        find.text('China'),
        findsNothing,
        reason: 'no trip is created automatically',
      );

      await tester.tap(find.text('Create new trip'));
      await tester.pumpAndSettle();
      expect(find.text('New Trip'), findsOneWidget);

      // Saving without a title is blocked.
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a title'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip title'),
        'Kyoto in Autumn',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      // Dashboard of the new trip.
      expect(find.text('Set dates to start the countdown'), findsOneWidget);
      expect(find.text('Planning'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Asia/Bangkok (UTC+07:00)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Asia/Bangkok (UTC+07:00)'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();

      // The dashboard exposes labeled planning actions below the cover.
      expect(find.widgetWithText(OutlinedButton, 'Map'), findsWidgets);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Timeline'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Set trip dates or add an activity to start planning day by day.',
        ),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Back on Home, the card has its own rail too.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Budget'), findsOneWidget);
      expect(find.text('Kyoto in Autumn'), findsWidgets);
      expect((await db.select(db.trips).get()).single.title, 'Kyoto in Autumn');
      await unmount(tester);
    },
  );

  testWidgets('home lists trips with countdowns and filters by status', (
    tester,
  ) async {
    final repo = ServiceRegistry.create(
      db: db,
      media: media,
      tempDir: () async => media.root,
    ).trips;
    await tester.runAsync(() async {
      await repo.createTrip(
        TripDraft(
          title: 'Lisbon',
          timeZone: 'Europe/Lisbon',
          startDate: const LocalDate(2026, 11, 30),
          endDate: const LocalDate(2026, 12, 6),
          datesConfirmed: true,
          destinations: [Destination(city: 'Lisbon', country: 'Portugal')],
        ),
      );
      await repo.createTrip(
        TripDraft(
          title: 'Hanoi',
          timeZone: 'Asia/Ho_Chi_Minh',
          startDate: const LocalDate(2026, 10, 14),
          endDate: const LocalDate(2026, 10, 20),
        ),
      );
      final old = await repo.createTrip(
        TripDraft(title: 'Old one', timeZone: 'UTC'),
      );
      await repo.setArchived(old, true);
    });

    await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('45 days to go'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('45 days to go'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Day 3 of 7'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Day 3 of 7'), findsOneWidget);
    expect(find.text('Old one'), findsNothing);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Traveling'));
    await tester.tap(find.widgetWithText(TextButton, 'Traveling'));
    await tester.pumpAndSettle();
    expect(find.text('Hanoi'), findsWidgets);
    expect(find.text('Lisbon'), findsNothing);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Archived'));
    await tester.tap(find.widgetWithText(TextButton, 'Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Old one'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('switching language to Thai and Chinese localizes the UI', (
    tester,
  ) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WanderPlanApp)),
    );

    await container.read(localeProvider.notifier).set(const Locale('th'));
    await tester.pumpAndSettle();
    expect(find.text('ทริปของฉัน'), findsOneWidget);

    await container.read(localeProvider.notifier).set(const Locale('zh'));
    await tester.pumpAndSettle();
    expect(find.text('我的旅行'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'to-do list: add suggestions, check one off, progress on dashboard',
    (tester) async {
      late String id;
      await tester.runAsync(() async {
        id =
            await ServiceRegistry.create(
              db: db,
              media: media,
              tempDir: () async => media.root,
            ).trips.createTrip(
              TripDraft(
                title: 'Tokyo',
                timeZone: 'Asia/Tokyo',
                startDate: const LocalDate(2026, 11, 20),
                endDate: const LocalDate(2026, 11, 25),
              ),
            );
      });
      await pumpApp(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WanderPlanApp)),
      );
      container.read(routerProvider).go(Routes.todos(id));
      await tester.pumpAndSettle();
      expect(find.text('Before you go'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add suggestions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check passport / ID expiry date'));
      await tester.tap(find.text('Arrange travel insurance'));
      await tester.pump();
      await tester.tap(find.text('Add 2'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 2 done'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 done'), findsOneWidget);

      container.read(routerProvider).go(Routes.trip(id));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1 of 2 done'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 of 2 done'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'timeline: add an activity, see it with its day check; budget shows the plan',
    (tester) async {
      late String id;
      await tester.runAsync(() async {
        id =
            await ServiceRegistry.create(
              db: db,
              media: media,
              tempDir: () async => media.root,
            ).trips.createTrip(
              TripDraft(
                title: 'Chengdu',
                timeZone: 'Asia/Shanghai',
                startDate: const LocalDate(2026, 11, 20),
                endDate: const LocalDate(2026, 11, 21),
                currency: 'CNY',
                totalBudget: 5000,
              ),
            );
      });
      await pumpApp(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WanderPlanApp)),
      );
      container.read(routerProvider).go(Routes.tripTimeline(id));
      await tester.pumpAndSettle();
      expect(find.text('Day 1'), findsOneWidget);
      expect(
        find.text('No accommodation planned for this night'),
        findsOneWidget,
      );

      await tester.tap(find.text('Add activity'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Panda base',
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Estimated cost'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Estimated cost'),
        '110',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Panda base'), findsOneWidget);
      expect(find.text('1 activity'), findsOneWidget);

      container.read(routerProvider).go(Routes.tripBudget(id));
      await tester.pumpAndSettle();
      expect(find.text('Planned'), findsWidgets);
      expect(find.textContaining('110'), findsWidgets);
      await unmount(tester);
    },
  );

  testWidgets(
    'import by pasting text: errors are specific, valid JSON opens the trip',
    (tester) async {
      final json = File(
        'test/fixtures/china_winter_trip_2026.json',
      ).readAsStringSync();
      await pumpApp(tester);
      await tester.tap(find.text('Import trip'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a file'), findsOneWidget);
      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        '{"format":"wanderplan.trip","schemaVersion":2,"trip":{"title":"X"},'
        '"activities":[{"title":"Half","date":"2026-01-01","start":"10:00"}]}',
      );
      await tester.pump();
      // The importer touches the file system (media cleanup), which needs real async.
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(TextButton, 'Import'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not import: activity "Half"'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), json);
      await tester.pump();
      // The importer touches the file system (media cleanup), which needs real async.
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(TextButton, 'Import'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(find.text('China Winter Adventure 2026'), findsWidgets);
      await tester.pump(
        const Duration(seconds: 10),
      ); // let the snackbar timers finish
      await unmount(tester);
    },
  );
}
