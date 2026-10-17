import 'package:rxdart/rxdart.dart';
import 'package:wanderplan/contexts/budget/application/rate_source.dart';
import 'package:wanderplan/contexts/budget/domain/budget_report.dart';
import 'package:wanderplan/contexts/budget/domain/budget_repositories.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity_repository.dart';
import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

class ExpenseDraft {
  ExpenseDraft({
    required this.title,
    this.category = ExpenseCategory.misc,
    required this.amount,
    required this.currency,
    this.kind = ExpenseKind.actual,
    this.isPaid = true,
    this.date,
    this.activityId,
    this.isShared = true,
    this.notes,
  });

  factory ExpenseDraft.fromExpense(Expense e) => ExpenseDraft(
    title: e.title,
    category: e.category,
    amount: e.amount,
    currency: e.currency,
    kind: e.kind,
    isPaid: e.isPaid,
    date: e.date,
    activityId: e.activityId,
    isShared: e.isShared,
    notes: e.notes,
  );

  String title;
  ExpenseCategory category;
  double amount;
  String currency;
  ExpenseKind kind;
  bool isPaid;
  LocalDate? date;
  String? activityId;
  bool isShared;
  String? notes;
}

/// Use cases of the Budget context.
class BudgetService {
  BudgetService({
    required ExpenseRepository expenses,
    required ExchangeRateRepository rates,
    required ActivityRepository activities,
    required TripRepository trips,
    required RateSource rateSource,
    required IdGenerator ids,
    required Clock clock,
  }) : _expenses = expenses,
       _rates = rates,
       _activities = activities,
       _trips = trips,
       _rateSource = rateSource,
       _ids = ids,
       _clock = clock;

  final ExpenseRepository _expenses;
  final ExchangeRateRepository _rates;
  final ActivityRepository _activities;
  final TripRepository _trips;
  final RateSource _rateSource;
  final IdGenerator _ids;
  final Clock _clock;

  String get rateSourceName => _rateSource.name;

  Stream<List<Expense>> watchExpenses(String tripId) => _expenses.watchByTrip(tripId);
  Future<List<Expense>> expensesOf(String tripId) => _expenses.findByTrip(tripId);
  Stream<List<ExchangeRate>> watchRates(String tripId) => _rates.watchByTrip(tripId);
  Future<List<ExchangeRate>> ratesOf(String tripId) => _rates.findByTrip(tripId);

  /// Live report: recomputed whenever the trip, its activities, expenses or rates change.
  Stream<BudgetReport> watchReport(String tripId) => Rx.combineLatest4(
    _trips.watchById(tripId),
    _activities.watchByTrip(tripId),
    _expenses.watchByTrip(tripId),
    _rates.watchByTrip(tripId),
    (trip, acts, exps, rates) => BudgetReport.compute(
      currency: trip?.currency,
      totalBudget: trip?.totalBudget,
      travelerCount: trip?.travelerCount ?? 1,
      activities: acts,
      expenses: exps,
      rates: rates,
    ),
  );

  Future<String> addExpense(String tripId, ExpenseDraft d) async {
    final e = _build(_ids.newId(), tripId, d, _clock());
    await _expenses.save(e);
    return e.id;
  }

  Future<void> updateExpense(String id, ExpenseDraft d) async {
    final cur = await _expenses.findById(id) ?? (throw EntityNotFoundException('Expense', id));
    await _expenses.save(_build(id, cur.tripId, d, cur.createdAt));
  }

  Future<void> setPaid(String id, bool paid) async {
    final cur = await _expenses.findById(id);
    if (cur != null) await _expenses.save(cur.copyWith(isPaid: paid));
  }

  Future<void> deleteExpense(String id) => _expenses.delete(id);
  Future<void> restoreExpense(Expense e) => _expenses.save(e);

  Future<void> setManualRate(String tripId, String currency, double rate) => _rates.save(
    tripId,
    ExchangeRate(currency: currency.toUpperCase(), rate: rate, source: 'manual', updatedAt: _clock()),
  );

  Future<void> deleteRate(String tripId, String currency) => _rates.delete(tripId, currency);

  /// Fetches live rates for [currencies] into the trip currency (online).
  /// Returns the currencies the provider could not supply.
  Future<Set<String>> refreshRates(String tripId, Set<String> currencies) async {
    final trip = await _trips.findById(tripId) ?? (throw EntityNotFoundException('Trip', tripId));
    final base = trip.currency;
    if (base == null) throw const DomainException('Set the trip currency first');
    final wanted = currencies.where((c) => c != base).toSet();
    if (wanted.isEmpty) return {};
    final fetched = await _rateSource.fetchRates(base: base, currencies: wanted);
    final now = _clock();
    for (final e in fetched.entries) {
      await _rates.save(tripId, ExchangeRate(currency: e.key, rate: e.value, source: _rateSource.name, updatedAt: now));
    }
    return wanted.difference(fetched.keys.toSet());
  }

  /// Copies planned expenses and rates to another trip (duplication as template).
  Future<void> copyPlan(String fromTripId, String toTripId, {Map<String, String> activityIdMap = const {}}) async {
    final now = _clock();
    for (final e in await _expenses.findByTrip(fromTripId)) {
      if (e.kind != ExpenseKind.planned) continue;
      await _expenses.save(
        e.copyWith(
          id: _ids.newId(),
          tripId: toTripId,
          activityId: e.activityId == null ? null : activityIdMap[e.activityId],
          clearActivity: e.activityId == null || activityIdMap[e.activityId] == null,
          createdAt: now,
        ),
      );
    }
    for (final r in await _rates.findByTrip(fromTripId)) {
      await _rates.save(toTripId, r);
    }
  }

  Expense _build(String id, String tripId, ExpenseDraft d, DateTime createdAt) => Expense(
    id: id,
    tripId: tripId,
    title: d.title,
    category: d.category,
    amount: d.amount,
    currency: d.currency,
    kind: d.kind,
    isPaid: d.isPaid,
    date: d.date,
    activityId: d.activityId,
    isShared: d.isShared,
    notes: (d.notes ?? '').trim().isEmpty ? null : d.notes!.trim(),
    createdAt: createdAt,
  );
}
