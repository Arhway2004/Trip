import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import 'expense.dart';

/// Converts amounts into the trip currency with the trip's own rates.
class CurrencyConverter {
  CurrencyConverter(this.baseCurrency, List<ExchangeRate> rates) : _rates = {for (final r in rates) r.currency: r.rate};

  final String baseCurrency;
  final Map<String, double> _rates;

  /// Null when no rate is known (the amount is then reported as unconverted).
  double? toBase(double amount, String currency) {
    if (currency == baseCurrency) return amount;
    final r = _rates[currency];
    return r == null ? null : amount * r;
  }
}

class CategoryTotals {
  double planned = 0;
  double actual = 0;
}

enum BudgetWarning { overBudgetPlanned, overBudgetActual, missingRates, noCurrency, nearLimit }

/// Everything the budget screen and dashboard show. All money is in
/// [currency]; amounts in currencies without a rate are listed in
/// [unconvertedCurrencies] and excluded from totals rather than guessed.
class BudgetReport {
  BudgetReport._({
    required this.currency,
    required this.totalBudget,
    required this.travelerCount,
    required this.planned,
    required this.actual,
    required this.paid,
    required this.unpaidPlanned,
    required this.byCategory,
    required this.byDayPlanned,
    required this.byDayActual,
    required this.unconvertedCurrencies,
    required this.currenciesInUse,
    required this.actualPerPerson,
  });

  /// Planned = activity costs + planned expenses (each counted once).
  /// Actual = actual expenses. Paid = actual expenses marked paid.
  factory BudgetReport.compute({
    required String? currency,
    required double? totalBudget,
    required int travelerCount,
    required List<Activity> activities,
    required List<Expense> expenses,
    required List<ExchangeRate> rates,
  }) {
    final base = currency;
    final conv = base == null ? null : CurrencyConverter(base, rates);
    final unconverted = <String>{};
    final inUse = <String>{};
    final byCategory = {for (final c in ExpenseCategory.values) c: CategoryTotals()};
    final byDayPlanned = <LocalDate, double>{}, byDayActual = <LocalDate, double>{};
    var planned = 0.0, actual = 0.0, paid = 0.0, unpaidPlanned = 0.0, actualPerPerson = 0.0;

    double? convert(double amount, String? cur) {
      final c = cur ?? base;
      if (c == null || conv == null) return null;
      inUse.add(c);
      final v = conv.toBase(amount, c);
      if (v == null) unconverted.add(c);
      return v;
    }

    for (final a in activities.where((a) => !a.isCancelled && a.cost != null)) {
      final v = convert(a.cost!, a.currency);
      if (v == null) continue;
      planned += v;
      byCategory[ExpenseCategory.forActivity(a.kind)]!.planned += v;
      byDayPlanned.update(a.date, (x) => x + v, ifAbsent: () => v);
      if (a.bookingStatus == BookingStatus.notBooked) unpaidPlanned += v;
    }
    for (final e in expenses) {
      final v = convert(e.amount, e.currency);
      if (v == null) continue;
      if (e.kind == ExpenseKind.planned) {
        planned += v;
        byCategory[e.category]!.planned += v;
        if (e.date != null) byDayPlanned.update(e.date!, (x) => x + v, ifAbsent: () => v);
        if (!e.isPaid) unpaidPlanned += v;
      } else {
        actual += v;
        if (e.isPaid) paid += v;
        byCategory[e.category]!.actual += v;
        if (e.date != null) byDayActual.update(e.date!, (x) => x + v, ifAbsent: () => v);
        actualPerPerson += e.isShared ? v / travelerCount : v;
      }
    }

    return BudgetReport._(
      currency: base,
      totalBudget: totalBudget,
      travelerCount: travelerCount,
      planned: planned,
      actual: actual,
      paid: paid,
      unpaidPlanned: unpaidPlanned,
      byCategory: byCategory,
      byDayPlanned: byDayPlanned,
      byDayActual: byDayActual,
      unconvertedCurrencies: unconverted,
      currenciesInUse: inUse,
      actualPerPerson: actualPerPerson,
    );
  }

  final String? currency;
  final double? totalBudget;
  final int travelerCount;
  final double planned;
  final double actual;
  final double paid;
  final double unpaidPlanned;
  final Map<ExpenseCategory, CategoryTotals> byCategory;
  final Map<LocalDate, double> byDayPlanned;
  final Map<LocalDate, double> byDayActual;
  final Set<String> unconvertedCurrencies;
  final Set<String> currenciesInUse;
  final double actualPerPerson;

  double get plannedPerPerson => planned / travelerCount;
  double? get remainingAfterPlan => totalBudget == null ? null : totalBudget! - planned;
  double? get remainingCash => totalBudget == null ? null : totalBudget! - actual;

  /// Planned vs actual for the whole trip (positive = overspent).
  double get variance => actual - planned;

  List<BudgetWarning> get warnings => [
    if (currency == null) BudgetWarning.noCurrency,
    if (unconvertedCurrencies.isNotEmpty) BudgetWarning.missingRates,
    if (totalBudget != null && planned > totalBudget!) BudgetWarning.overBudgetPlanned,
    if (totalBudget != null && actual > totalBudget!) BudgetWarning.overBudgetActual,
    if (totalBudget != null && planned <= totalBudget! && planned > totalBudget! * 0.9) BudgetWarning.nearLimit,
  ];
}
