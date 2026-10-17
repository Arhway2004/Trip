// Reproducible previews use an isolated simulated device, never user data.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/app/app.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestDevice deviceToDispose;
  tearDown(() async {
    await deviceToDispose.dispose();
  });
  setUpAll(() async {
    await initTestEnvironment();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final font in [
      ('DM Sans', 'DM-Sans.ttf'),
      ('Newsreader', 'Newsreader.ttf'),
    ]) {
      final loader = FontLoader(font.$1)
        ..addFont(rootBundle.load('assets/fonts/${font.$2}'));
      await loader.load();
    }
    // Widget hosts have no OS font collection. Register installed fallback
    // families for local preview captures without shipping system font files.
    if (const bool.fromEnvironment('DESIGN_PREVIEWS')) {
      for (final font in [
        ('Noto Sans SC', '/System/Library/Fonts/STHeiti Light.ttc'),
        ('Noto Sans CJK SC', '/System/Library/Fonts/STHeiti Light.ttc'),
        ('PingFang SC', '/System/Library/Fonts/STHeiti Light.ttc'),
        (
          'Arial Unicode MS',
          '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
        ),
        ('Noto Sans Thai', '/System/Library/Fonts/ThonburiUI.ttc'),
        ('Thonburi', '/System/Library/Fonts/ThonburiUI.ttc'),
        ('Noto Serif SC', '/System/Library/Fonts/Supplemental/Songti.ttc'),
        ('Songti SC', '/System/Library/Fonts/Supplemental/Songti.ttc'),
      ]) {
        final file = File(font.$2);
        if (file.existsSync()) {
          final loader = FontLoader(font.$1)
            ..addFont(
              file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await loader.load();
        }
      }
    }
  });
  for (final review in [
    (const Size(390, 844), false, 1.0, 'en'),
    (const Size(820, 1180), false, 1.0, 'en'),
    (const Size(320, 740), false, 1.0, 'en'),
    (const Size(390, 844), true, 1.0, 'en'),
    (const Size(390, 844), false, 1.6, 'en'),
    (const Size(390, 844), false, 1.0, 'zh'),
    (const Size(390, 844), false, 1.0, 'th'),
  ]) {
    final size = review.$1;
    final suffix = review.$2
        ? '-dark'
        : review.$3 > 1
        ? '-large-text'
        : review.$4 != 'en'
        ? '-${review.$4}'
        : '';
    testWidgets(
      'atlas layout at ${size.width.toInt()}px$suffix has no overflow',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = review.$2
            ? Brightness.dark
            : Brightness.light;
        tester.platformDispatcher.textScaleFactorTestValue = review.$3;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final now = DateTime.utc(2026, 10, 16, 3);
        final seeded = await tester.runAsync(() async {
          final device = await TestDevice.create(clock: () => now);
          final first = await device.app.trips.createTrip(
            TripDraft(
              title: 'Autumn in Chengdu & Chongqing',
              timeZone: 'Asia/Shanghai',
              startDate: const LocalDate(2026, 11, 20),
              endDate: const LocalDate(2026, 11, 28),
              datesConfirmed: true,
              travelerCount: 2,
              currency: 'CNY',
              totalBudget: 15000,
            ),
          );
          await device.app.trips.saveBanner(
            first,
            const BannerConfig(colorA: 0xFF254F3E, colorB: 0xFF35624C),
          );
          final kyoto = await device.app.trips.createTrip(
            TripDraft(
              title: 'A slow week in Kyoto',
              timeZone: 'Asia/Tokyo',
              startDate: const LocalDate(2026, 12, 3),
              endDate: const LocalDate(2026, 12, 9),
              datesConfirmed: true,
              travelerCount: 2,
              currency: 'JPY',
              totalBudget: 180000,
            ),
          );
          await device.app.trips.saveBanner(
            kyoto,
            const BannerConfig(colorA: 0xFF6B4C3B, colorB: 0xFF89644A),
          );
          final coast = await device.app.trips.createTrip(
            TripDraft(
              title: 'The coast, without a plan',
              timeZone: 'Asia/Bangkok',
              stage: TripStage.dreaming,
            ),
          );
          await device.app.trips.saveBanner(
            coast,
            const BannerConfig(colorA: 0xFF4D5E48, colorB: 0xFF6A7856),
          );
          await device.app.trips.reorder([first, kyoto, coast]);
          return (device, first);
        });
        final device = seeded!.$1;
        deviceToDispose = device;
        final first = seeded.$2;
        final boundary = GlobalKey();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(device.db),
            mediaStorageProvider.overrideWithValue(device.media),
            serviceRegistryProvider.overrideWithValue(device.app),
            deviceTimeZoneProvider.overrideWithValue('Asia/Bangkok'),
            clockProvider.overrideWithValue(() => now),
            localeProvider.overrideWith(() => _ReviewLocale(Locale(review.$4))),
          ],
        );
        var disposed = false;
        Future<void> unmount() async {
          if (disposed) return;
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 20));
          container.dispose();
          await tester.pump(const Duration(milliseconds: 50));
          disposed = true;
        }

        addTearDown(unmount);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(key: boundary, child: const WanderPlanApp()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        Future<void> capture(String name) async {
          if (const bool.fromEnvironment('DESIGN_PREVIEWS')) {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await render.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '../docs/design/previews/mobile-$name-${size.width.toInt()}$suffix.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }

        await capture('collection');
        await tester.enterText(find.byType(TextField), 'KYOTO');
        await tester.pumpAndSettle();
        expect(find.text('A slow week in Kyoto'), findsOneWidget);
        expect(find.text('Autumn in Chengdu & Chongqing'), findsNothing);
        await tester.enterText(find.byType(TextField), 'no-such-trip');
        await tester.pumpAndSettle();
        expect(find.text('A slow week in Kyoto'), findsNothing);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.text('Autumn in Chengdu & Chongqing'), findsOneWidget);
        container.read(routerProvider).go(Routes.trip(first));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('detail');
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1800),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('tools');
        container.read(routerProvider).go(Routes.newTrip);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('form');
        await unmount();
      },
    );
  }
}

class _ReviewLocale extends LocaleController {
  _ReviewLocale(this.locale);
  final Locale locale;
  @override
  Locale? build() => locale;
}
