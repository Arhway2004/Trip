import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/budget/domain/budget_report.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

void main() {
  final t0 = DateTime.utc(2026);
  const day = LocalDate(2026, 11, 20);
  Activity act(
    double? cost,
    String? cur, {
    ActivityKind kind = ActivityKind.sightseeing,
    BookingStatus s = BookingStatus.booked,
  }) => Activity(
    id: 'a$cost$cur$kind',
    tripId: 't',
    title: 'x',
    kind: kind,
    date: day,
    startMinute: 600,
    endMinute: 660,
    cost: cost,
    currency: cur,
    bookingStatus: s,
    createdAt: t0,
    updatedAt: t0,
  );
  Expense exp(
    double amount,
    String cur,
    ExpenseKind kind, {
    ExpenseCategory cat = ExpenseCategory.food,
    bool shared = true,
    bool paid = true,
  }) => Expense(
    id: 'e$amount$cur$kind',
    tripId: 't',
    title: 'y',
    amount: amount,
    currency: cur,
    kind: kind,
    category: cat,
    isShared: shared,
    isPaid: paid,
    date: day,
    createdAt: t0,
  );

  BudgetReport report({
    List<Activity> acts = const [],
    List<Expense> exps = const [],
    List<ExchangeRate> rates = const [],
    double? budget = 10000,
    int travelers = 2,
  }) => BudgetReport.compute(
    currency: 'CNY',
    totalBudget: budget,
    travelerCount: travelers,
    activities: acts,
    expenses: exps,
    rates: rates,
  );

  test('planned = activity costs + planned expenses; actual kept separate', () {
    final r = report(
      acts: [
        act(300, 'CNY'),
        act(2400, 'CNY', kind: ActivityKind.hotel),
      ],
      exps: [
        exp(1000, 'CNY', ExpenseKind.planned, cat: ExpenseCategory.emergency),
        exp(250, 'CNY', ExpenseKind.actual),
      ],
    );
    expect(r.planned, 3700);
    expect(r.actual, 250);
    expect(r.byCategory[ExpenseCategory.hotels]!.planned, 2400);
    expect(r.byCategory[ExpenseCategory.attractions]!.planned, 300);
    expect(r.byCategory[ExpenseCategory.food]!.actual, 250);
    expect(r.remainingAfterPlan, 6300);
    expect(r.remainingCash, 9750);
    expect(r.byDayPlanned[day], 3700);
  });

  test('foreign currencies convert with trip rates; missing rates are excluded and reported', () {
    final r = report(
      acts: [act(9000, 'THB', kind: ActivityKind.flight)],
      exps: [exp(15, 'USD', ExpenseKind.planned), exp(100, 'JPY', ExpenseKind.actual)],
      rates: [
        ExchangeRate(currency: 'THB', rate: 0.2, updatedAt: t0),
        ExchangeRate(currency: 'USD', rate: 7, updatedAt: t0),
      ],
    );
    expect(r.planned, closeTo(1800 + 105, 1e-9));
    expect(r.actual, 0);
    expect(r.unconvertedCurrencies, {'JPY'});
    expect(r.warnings, contains(BudgetWarning.missingRates));
  });

  test('per-person figures respect shared vs personal expenses', () {
    final r = report(exps: [exp(200, 'CNY', ExpenseKind.actual), exp(50, 'CNY', ExpenseKind.actual, shared: false)]);
    expect(r.actualPerPerson, 150);
    expect(report(acts: [act(1000, 'CNY')]).plannedPerPerson, 500);
  });

  test('cancelled activities cost nothing; unbooked ones count as still to pay', () {
    final r = report(
      acts: [
        act(500, 'CNY', s: BookingStatus.cancelled),
        act(300, 'CNY', s: BookingStatus.notBooked),
      ],
    );
    expect(r.planned, 300);
    expect(r.unpaidPlanned, 300);
  });

  test('budget warnings', () {
    expect(report(acts: [act(9500, 'CNY')]).warnings, contains(BudgetWarning.nearLimit));
    expect(report(acts: [act(12000, 'CNY')]).warnings, contains(BudgetWarning.overBudgetPlanned));
    expect(report(exps: [exp(11000, 'CNY', ExpenseKind.actual)]).warnings, contains(BudgetWarning.overBudgetActual));
    expect(
      BudgetReport.compute(
        currency: null,
        totalBudget: null,
        travelerCount: 1,
        activities: const [],
        expenses: const [],
        rates: const [],
      ).warnings,
      [BudgetWarning.noCurrency],
    );
  });

  test('expense and rate invariants', () {
    expect(() => exp(-1, 'CNY', ExpenseKind.actual), throwsA(anything));
    expect(() => exp(1, 'yuan', ExpenseKind.actual), throwsA(anything));
    expect(() => ExchangeRate(currency: 'THB', rate: 0, updatedAt: t0), throwsA(anything));
  });
}
