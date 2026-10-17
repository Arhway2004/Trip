import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/itinerary/application/booking_reminders.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_optimizer.dart';
import 'package:wanderplan/contexts/itinerary/domain/opening_hours.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../helpers.dart';

void main() {
  setUpAll(initTestEnvironment);
  const day = LocalDate(2026, 12, 10);
  // 2026-11-20 08:00 UTC.
  final now = DateTime.utc(2026, 11, 20, 8);

  late TestDevice d;
  late FakeReminderScheduler notifications;
  setUp(() async {
    notifications = FakeReminderScheduler();
    d = await TestDevice.create(clock: () => now, reminders: notifications);
  });
  tearDown(() => d.dispose());

  Future<String> trip() => d.app.trips.createTrip(TripDraft(title: 'Yunnan', timeZone: 'Asia/Shanghai'));

  test('a "book 7 days before" reminder fires at 09:00 trip time on the book-by date', () async {
    final id = await trip();
    final a = await d.app.itinerary.addActivity(
      id,
      ActivityDraft(
        title: 'Jade Dragon Snow Mountain',
        date: day,
        reservationRequired: true,
        reservationVia: 'Official WeChat account',
        bookAheadDays: 7,
        remindToBook: true,
      ),
    );
    final n = await d.app.reminders.syncTrip(id, title: (_) => 'Time to book', body: (x) => x.title);
    expect(n, 1);
    final r = notifications.scheduled[BookingReminderService.reminderId(a)]!;
    // Dec 3, 09:00 in Shanghai (UTC+8) = 01:00 UTC.
    expect(r.at, DateTime.utc(2026, 12, 3, 1));
    expect((r.title, r.body, r.tripId), ('Time to book', 'Jade Dragon Snow Mountain', id));

    // Once booked, the reminder is cancelled.
    final act = (await d.app.itinerary.getActivity(a))!;
    await d.app.itinerary.updateActivity(a, ActivityDraft.fromActivity(act)..bookingStatus = BookingStatus.booked);
    expect(await d.app.reminders.syncTrip(id, title: (_) => '', body: (_) => ''), 0);
    expect(notifications.scheduled, isEmpty);
  });

  test('book-by dates already past are not scheduled; deleting the trip clears its reminders', () async {
    final id = await trip();
    await d.app.itinerary.addActivities(id, [
      ActivityDraft(title: 'Too late', date: const LocalDate(2026, 11, 22), reservationRequired: true, bookAheadDays: 7, remindToBook: true),
      ActivityDraft(title: 'Later', date: day, reservationRequired: true, bookAheadDays: 1, remindToBook: true),
    ]);
    expect(await d.app.reminders.syncTrip(id, title: (_) => '', body: (_) => ''), 1);
    await d.app.trips.deleteTrip(id);
    await d.app.reminders.syncTrip(id, title: (_) => '', body: (_) => '');
    expect(notifications.scheduled, isEmpty);
  });

  test('applying an optimized plan moves only the movable visits', () async {
    final id = await trip();
    GeoPoint at(double km) => GeoPoint(27, 100 + km * 0.01);
    final ids = await d.app.itinerary.addActivities(id, [
      ActivityDraft(title: 'Far', date: day, startMinute: 540, endMinute: 600, location: PlaceRef(name: 'Far', point: at(5))),
      ActivityDraft(title: 'Near', date: day, startMinute: 620, endMinute: 680, location: PlaceRef(name: 'Near', point: at(1))),
      ActivityDraft(title: 'Booked show', date: day, startMinute: 1140, endMinute: 1260, bookingStatus: BookingStatus.booked, location: PlaceRef(name: 'Show', point: at(2))),
    ]);
    await d.app.itinerary.setDayAnchors(id, day, start: PlaceRef(name: 'Hotel', point: at(0)));
    final acts = await d.app.itinerary.activitiesOf(id);
    final settings = (await d.app.itinerary.daySettingsOf(id)).single;
    final plan = optimizeDay(activities: acts, day: day, travel: (a, b) => a.distanceKmTo(b) * 10, settings: settings)!;
    expect(plan.moved.first.activity.title, 'Near');
    expect(await d.app.itinerary.applyDayPlan(day, plan), 2);
    final after = {for (final a in await d.app.itinerary.activitiesOf(id)) a.title: a};
    expect(after['Near']!.startMinute, lessThan(after['Far']!.startMinute!));
    expect(after['Booked show']!.startMinute, 1140);
    expect(ids, hasLength(3));
  });

  test('travel modes, opening hours, reservations and day start/end survive a trip file', () async {
    final id = await trip();
    final a = await d.app.itinerary.addActivity(
      id,
      ActivityDraft(
        title: 'Songzanlin',
        date: day,
        startMinute: 600,
        endMinute: 720,
        arrivalMode: TravelMode.transit,
        arrivalMinutes: 35,
        openingHours: OpeningHours(opens: 8 * 60, closes: 18 * 60, closedWeekdays: {DateTime.monday}),
        reservationRequired: true,
        reservationVia: 'WeChat',
        bookAheadDays: 3,
        remindToBook: true,
      ),
    );
    await d.app.itinerary.setDayAnchors(id, day, start: const PlaceRef(name: 'Guesthouse', point: GeoPoint(27.8, 99.7)));
    await d.app.itinerary.setEndArrival(id, day, TravelMode.driving, 20);

    final friend = await TestDevice.create();
    addTearDown(friend.dispose);
    final theirs = await friend.app.packages.importFile(await d.app.packages.exportTrip(id));
    final got = (await friend.app.itinerary.activitiesOf(theirs)).single;
    expect((got.arrivalMode, got.arrivalMinutes), (TravelMode.transit, 35));
    expect(got.openingHours, OpeningHours(opens: 480, closes: 1080, closedWeekdays: {DateTime.monday}));
    expect((got.reservationRequired, got.reservationVia, got.bookAheadDays, got.remindToBook), (true, 'WeChat', 3, true));
    final s = (await friend.app.itinerary.daySettingsOf(theirs)).single;
    expect((s.start.name, s.endArrivalMode, s.endArrivalMinutes), ('Guesthouse', TravelMode.driving, 20));
    expect(a, isNotEmpty);
  });
}
