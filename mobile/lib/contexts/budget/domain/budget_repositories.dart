import 'expense.dart';

abstract interface class ExpenseRepository {
  /// Newest date first; undated last.
  Stream<List<Expense>> watchByTrip(String tripId);
  Future<List<Expense>> findByTrip(String tripId);
  Future<Expense?> findById(String id);
  Future<void> save(Expense expense);
  Future<void> delete(String id);
}

abstract interface class ExchangeRateRepository {
  Stream<List<ExchangeRate>> watchByTrip(String tripId);
  Future<List<ExchangeRate>> findByTrip(String tripId);
  Future<void> save(String tripId, ExchangeRate rate);
  Future<void> delete(String tripId, String currency);
}
