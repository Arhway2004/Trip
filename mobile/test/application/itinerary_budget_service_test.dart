import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/budget/application/budget_service.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../helpers.dart';

void main() {
  late TestDevice d;
  late FakeRateSource rates;
  setUpAll(initTestEnvironment);
  setUp(() async {
    rates = FakeRateSource({'THB': 0.2, 'USD': 7.1});
    d = await TestDevice.create(rates: rates);
  });
  tearDown(() => d.dispose());

  const day1 = LocalDate(2026, 11, 20), day2 = LocalDate(2026, 11, 21);
  Future<String> trip() => d.app.trips.createTrip(
    TripDraft(
      title: 'Sichuan',
      timeZone: 'Asia/Shanghai',
      startDate: day1,
      endDate: const LocalDate(2026, 11, 22),
      currency: 'CNY',
      totalBudget: 10000,
      travelerCount: 2,
    ),
  );
  ActivityDraft draft(
    String title,
    int start,
    int end, {
    LocalDate date = day1,
    ActivityKind kind = ActivityKind.sightseeing,
    double? cost,
    String? cur,
  }) => ActivityDraft(
    title: title,
    kind: kind,
    date: date,
    startMinute: start,
    endMinute: end,
    cost: cost,
    currency: cur,
  );

  test('activities are listed chronologically and edits keep identity', () async {
    final t = await trip();
    final late = await d.app.itinerary.addActivity(t, draft('Dinner', 18 * 60, 20 * 60, kind: ActivityKind.food));
    final early = await d.app.itinerary.addActivity(t, draft('Pandas', 7 * 60, 11 * 60));
    expect((await d.app.itinerary.activitiesOf(t)).map((a) => a.id), [early, late]);

    final edited = ActivityDraft.fromActivity((await d.app.itinerary.getActivity(early))!)..title = 'Panda base';
    await d.app.itinerary.updateActivity(early, edited);
    expect((await d.app.itinerary.getActivity(early))!.title, 'Panda base');
  });

  test('drag-move and resize respect locks', () async {
    final t = await trip();
    final id = await d.app.itinerary.addActivity(t, draft('Museum', 9 * 60, 11 * 60));
    await d.app.itinerary.moveActivity(id, day2, 14 * 60);
    var a = (await d.app.itinerary.getActivity(id))!;
    expect((a.date, a.startMinute, a.endMinute), (day2, 14 * 60, 16 * 60));
    await d.app.itinerary.resizeActivity(id, 45);
    expect((await d.app.itinerary.getActivity(id))!.endMinute, 14 * 60 + 45);

    await d.app.itinerary.setLocked(id, true);
    await expectLater(d.app.itinerary.moveActivity(id, day1, 8 * 60), throwsA(isA<LockedActivityException>()));
    a = (await d.app.itinerary.getActivity(id))!;
    expect(a.date, day2, reason: 'locked bookings are never moved');
  });

  test('budget report updates live as costs change and converts currencies', () async {
    final t = await trip();
    await d.app.itinerary.addActivity(
      t,
      draft('Flight', 8 * 60, 12 * 60, kind: ActivityKind.flight, cost: 9000, cur: 'THB'),
    );
    await d.app.budget.addExpense(
      t,
      ExpenseDraft(title: 'Hotpot', amount: 280, currency: 'CNY', category: ExpenseCategory.food),
    );
    var r = await d.app.budget.watchReport(t).first;
    expect(r.planned, 0, reason: 'THB has no rate yet');
    expect(r.unconvertedCurrencies, {'THB'});
    expect(r.actual, 280);

    final missing = await d.app.budget.refreshRates(t, {'THB', 'JPY'});
    expect(missing, {'JPY'});
    expect(rates.calls.single.$1, 'CNY');
    r = await d.app.budget.watchReport(t).first;
    expect(r.planned, closeTo(1800, 1e-9));
    expect(r.byCategory[ExpenseCategory.flights]!.planned, closeTo(1800, 1e-9));
    expect((await d.app.budget.ratesOf(t)).single.source, 'test-rates');

    await d.app.budget.setManualRate(t, 'THB', 0.19);
    r = await d.app.budget.watchReport(t).first;
    expect(r.planned, closeTo(1710, 1e-9));
  });

  test('duplicating a trip copies the plan as a template, not the spending', () async {
    final t = await trip();
    final flight = await d.app.itinerary.addActivity(
      t,
      draft('Flight', 8 * 60, 12 * 60, kind: ActivityKind.flight, cost: 9000, cur: 'THB')
        ..bookingStatus = BookingStatus.confirmed
        ..bookingReference = 'ABC123'
        ..isLocked = true,
    );
    await d.app.budget.addExpense(
      t,
      ExpenseDraft(title: 'Insurance', amount: 1200, currency: 'THB', kind: ExpenseKind.planned, activityId: flight),
    );
    await d.app.budget.addExpense(t, ExpenseDraft(title: 'Snacks', amount: 50, currency: 'CNY'));
    await d.app.budget.setManualRate(t, 'THB', 0.2);

    final copy = await d.app.trips.duplicateTrip(t, titleSuffix: ' copy');
    final acts = await d.app.itinerary.activitiesOf(copy);
    expect(acts.single.bookingStatus, BookingStatus.notBooked);
    expect(acts.single.bookingReference, isNull);
    expect(acts.single.isLocked, isFalse);
    final exps = await d.app.budget.expensesOf(copy);
    expect(exps.map((e) => e.title), ['Insurance']);
    expect(exps.single.activityId, acts.single.id, reason: 'links are remapped to the copied activity');
    expect((await d.app.budget.ratesOf(copy)).single.rate, 0.2);
  });

  test('deleting an activity keeps its actual expense but unlinks it', () async {
    final t = await trip();
    final a = await d.app.itinerary.addActivity(t, draft('Museum', 9 * 60, 11 * 60));
    await d.app.budget.addExpense(t, ExpenseDraft(title: 'Ticket', amount: 60, currency: 'CNY', activityId: a));
    await d.app.itinerary.deleteActivity(a);
    final e = (await d.app.budget.expensesOf(t)).single;
    expect(e.activityId, isNull);
    expect(e.amount, 60);
  });
}
