import 'package:flutter/material.dart';
import 'package:wanderplan/contexts/budget/domain/expense.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';

extension ExpenseCategoryUi on ExpenseCategory {
  String label(AppLocalizations l) => switch (this) {
    ExpenseCategory.flights => l.catFlights,
    ExpenseCategory.trains => l.catTrains,
    ExpenseCategory.buses => l.catBuses,
    ExpenseCategory.taxis => l.catTaxis,
    ExpenseCategory.transport => l.catTransport,
    ExpenseCategory.hotels => l.catHotels,
    ExpenseCategory.food => l.catFood,
    ExpenseCategory.attractions => l.catAttractions,
    ExpenseCategory.activities => l.catActivities,
    ExpenseCategory.internet => l.catInternet,
    ExpenseCategory.insurance => l.catInsurance,
    ExpenseCategory.shopping => l.catShopping,
    ExpenseCategory.emergency => l.catEmergency,
    ExpenseCategory.misc => l.catMisc,
  };

  IconData get icon => switch (this) {
    ExpenseCategory.flights => Icons.flight,
    ExpenseCategory.trains => Icons.train_outlined,
    ExpenseCategory.buses => Icons.directions_bus_outlined,
    ExpenseCategory.taxis => Icons.local_taxi_outlined,
    ExpenseCategory.transport => Icons.alt_route,
    ExpenseCategory.hotels => Icons.hotel_outlined,
    ExpenseCategory.food => Icons.restaurant_outlined,
    ExpenseCategory.attractions => Icons.confirmation_number_outlined,
    ExpenseCategory.activities => Icons.local_activity_outlined,
    ExpenseCategory.internet => Icons.sim_card_outlined,
    ExpenseCategory.insurance => Icons.health_and_safety_outlined,
    ExpenseCategory.shopping => Icons.shopping_bag_outlined,
    ExpenseCategory.emergency => Icons.emergency_outlined,
    ExpenseCategory.misc => Icons.more_horiz,
  };
}
