import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

enum ExpenseCategory {
  flights,
  trains,
  buses,
  taxis,

  /// Journeys whose mode isn't decided yet, transfers, etc.
  transport,
  hotels,
  food,
  attractions,
  activities,
  internet,
  insurance,
  shopping,
  emergency,
  misc;

  static ExpenseCategory forActivity(ActivityKind k) => switch (k) {
    ActivityKind.flight => flights,
    ActivityKind.train => trains,
    ActivityKind.bus || ActivityKind.ferry => buses,
    ActivityKind.transfer => taxis,
    ActivityKind.transport => transport,
    ActivityKind.hotel => hotels,
    ActivityKind.food => food,
    ActivityKind.sightseeing => attractions,
    ActivityKind.activity => activities,
    ActivityKind.shopping => shopping,
    ActivityKind.rest || ActivityKind.other => misc,
  };
}

/// Planned costs are estimates entered in advance; actual costs are money
/// really spent. They are kept separate and never overwrite each other.
enum ExpenseKind { planned, actual }

/// Entity of the Budget context.
class Expense {
  Expense({
    required this.id,
    required this.tripId,
    required String title,
    this.category = ExpenseCategory.misc,
    required this.amount,
    required String currency,
    this.kind = ExpenseKind.actual,
    this.isPaid = true,
    this.date,
    this.activityId,
    this.isShared = true,
    this.notes,
    required this.createdAt,
  }) : title = title.trim(),
       currency = currency.trim().toUpperCase() {
    if (this.title.isEmpty) throw const DomainException('An expense needs a title');
    if (amount < 0 || amount.isNaN) throw const DomainException('Amount cannot be negative');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(this.currency)) throw const DomainException('Use a 3-letter currency code');
  }

  final String id;
  final String tripId;
  final String title;
  final ExpenseCategory category;
  final double amount;
  final String currency;
  final ExpenseKind kind;
  final bool isPaid;
  final LocalDate? date;
  final String? activityId;

  /// Shared expenses are split across all travelers; others are for one person.
  final bool isShared;
  final String? notes;
  final DateTime createdAt;

  Expense copyWith({
    String? id,
    String? tripId,
    bool? isPaid,
    String? activityId,
    bool clearActivity = false,
    DateTime? createdAt,
  }) => Expense(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    title: title,
    category: category,
    amount: amount,
    currency: currency,
    kind: kind,
    isPaid: isPaid ?? this.isPaid,
    date: date,
    activityId: clearActivity ? null : (activityId ?? this.activityId),
    isShared: isShared,
    notes: notes,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// 1 unit of [currency] = [rate] units of the trip currency.
class ExchangeRate {
  ExchangeRate({required this.currency, required this.rate, this.source = 'manual', required this.updatedAt}) {
    if (!(rate > 0)) throw const DomainException('Exchange rate must be positive');
  }

  final String currency;
  final double rate;

  /// `manual` (entered by the user, not verified) or the provider name.
  final String source;
  final DateTime updatedAt;

  bool get isManual => source == 'manual';
}
