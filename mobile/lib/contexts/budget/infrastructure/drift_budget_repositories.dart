import 'package:drift/drift.dart';
import 'package:wanderplan/contexts/budget/domain/budget_repositories.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftExpenseRepository implements ExpenseRepository {
  DriftExpenseRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$ExpensesTable, ExpenseRow> _byTrip(String tripId) => _db.select(_db.expenses)
    ..where((t) => t.tripId.equals(tripId))
    ..orderBy([
      (t) => OrderingTerm(expression: t.date.isNull()),
      (t) => OrderingTerm.desc(t.date),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);

  List<Expense> _map(List<ExpenseRow> rows) => rows.map(_toDomain).whereType<Expense>().toList();

  @override
  Stream<List<Expense>> watchByTrip(String tripId) => _byTrip(tripId).watch().map(_map);

  @override
  Future<List<Expense>> findByTrip(String tripId) async => _map(await _byTrip(tripId).get());

  @override
  Future<Expense?> findById(String id) async {
    final r = await (_db.select(_db.expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _toDomain(r);
  }

  @override
  Future<void> save(Expense e) => _db
      .into(_db.expenses)
      .insertOnConflictUpdate(
        ExpenseRow(
          id: e.id,
          tripId: e.tripId,
          title: e.title,
          category: e.category.name,
          amount: e.amount,
          currency: e.currency,
          kind: e.kind.name,
          isPaid: e.isPaid,
          date: e.date?.toIso(),
          activityId: e.activityId,
          isShared: e.isShared,
          notes: e.notes,
          createdAt: e.createdAt,
        ).toCompanion(false),
      );

  @override
  Future<void> delete(String id) => (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();

  static Expense? _toDomain(ExpenseRow r) {
    try {
      return Expense(
        id: r.id,
        tripId: r.tripId,
        title: r.title,
        category: enumByName(ExpenseCategory.values, r.category) ?? ExpenseCategory.misc,
        amount: r.amount,
        currency: r.currency,
        kind: enumByName(ExpenseKind.values, r.kind) ?? ExpenseKind.actual,
        isPaid: r.isPaid,
        date: LocalDate.tryParse(r.date),
        activityId: r.activityId,
        isShared: r.isShared,
        notes: r.notes,
        createdAt: r.createdAt,
      );
    } catch (_) {
      return null;
    }
  }
}

class DriftExchangeRateRepository implements ExchangeRateRepository {
  DriftExchangeRateRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$ExchangeRatesTable, ExchangeRateRow> _byTrip(String tripId) => _db.select(_db.exchangeRates)
    ..where((t) => t.tripId.equals(tripId))
    ..orderBy([(t) => OrderingTerm.asc(t.currency)]);

  List<ExchangeRate> _map(List<ExchangeRateRow> rows) => [
    for (final r in rows)
      if (r.rate > 0) ExchangeRate(currency: r.currency, rate: r.rate, source: r.source, updatedAt: r.updatedAt),
  ];

  @override
  Stream<List<ExchangeRate>> watchByTrip(String tripId) => _byTrip(tripId).watch().map(_map);

  @override
  Future<List<ExchangeRate>> findByTrip(String tripId) async => _map(await _byTrip(tripId).get());

  @override
  Future<void> save(String tripId, ExchangeRate r) => _db
      .into(_db.exchangeRates)
      .insertOnConflictUpdate(
        ExchangeRateRow(tripId: tripId, currency: r.currency, rate: r.rate, source: r.source, updatedAt: r.updatedAt),
      );

  @override
  Future<void> delete(String tripId, String currency) =>
      (_db.delete(_db.exchangeRates)..where((t) => t.tripId.equals(tripId) & t.currency.equals(currency))).go();
}
