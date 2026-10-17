import 'package:flutter/material.dart';

import 'package:wanderplan/l10n/gen/app_localizations.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';

extension TodoCategoryL10n on TodoCategory {
  String label(AppLocalizations l) => switch (this) {
    TodoCategory.documents => l.todoCatDocuments,
    TodoCategory.bookings => l.todoCatBookings,
    TodoCategory.packing => l.todoCatPacking,
    TodoCategory.health => l.todoCatHealth,
    TodoCategory.money => l.todoCatMoney,
    TodoCategory.connectivity => l.todoCatConnectivity,
    TodoCategory.home => l.todoCatHome,
    TodoCategory.other => l.todoCatOther,
  };

  IconData get icon => switch (this) {
    TodoCategory.documents => Icons.badge_outlined,
    TodoCategory.bookings => Icons.confirmation_number_outlined,
    TodoCategory.packing => Icons.luggage_outlined,
    TodoCategory.health => Icons.health_and_safety_outlined,
    TodoCategory.money => Icons.payments_outlined,
    TodoCategory.connectivity => Icons.sim_card_outlined,
    TodoCategory.home => Icons.home_outlined,
    TodoCategory.other => Icons.checklist,
  };
}

extension TodoSuggestionL10n on TodoSuggestion {
  String label(AppLocalizations l) => switch (this) {
    TodoSuggestion.passport => l.sugPassport,
    TodoSuggestion.entryRequirements => l.sugEntryRequirements,
    TodoSuggestion.insurance => l.sugInsurance,
    TodoSuggestion.medication => l.sugMedication,
    TodoSuggestion.confirmStay => l.sugConfirmStay,
    TodoSuggestion.checkIn => l.sugCheckIn,
    TodoSuggestion.airportTransport => l.sugAirportTransport,
    TodoSuggestion.bankCards => l.sugBankCards,
    TodoSuggestion.localCash => l.sugLocalCash,
    TodoSuggestion.simCard => l.sugSimCard,
    TodoSuggestion.offlineCopies => l.sugOfflineCopies,
    TodoSuggestion.chargers => l.sugChargers,
    TodoSuggestion.homeArrangements => l.sugHomeArrangements,
  };
}

String todoDueLabel(AppLocalizations l, TodoDue due) => switch (due) {
  TodoNoDue() => l.todoNoDueDate,
  TodoDueIn(:final days) => l.todoDueIn(days),
  TodoOverdue(:final days) => l.todoOverdue(days),
};
