import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/budget/domain/budget_report.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';

final budgetReportProvider = StreamProvider.family<BudgetReport, String>(
  (ref, tripId) => ref.watch(budgetServiceProvider).watchReport(tripId),
);

final tripExpensesProvider = StreamProvider.family<List<Expense>, String>(
  (ref, tripId) => ref.watch(budgetServiceProvider).watchExpenses(tripId),
);

final tripRatesProvider = StreamProvider.family<List<ExchangeRate>, String>(
  (ref, tripId) => ref.watch(budgetServiceProvider).watchRates(tripId),
);
