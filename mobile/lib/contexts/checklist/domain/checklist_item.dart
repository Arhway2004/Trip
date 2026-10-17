import 'package:wanderplan/shared/domain/local_date.dart';

enum TodoCategory { documents, bookings, packing, health, money, connectivity, home, other }

/// Generic starter tasks the user may opt into. They carry no destination
/// facts (no visa rules, prices, etc.), only reminders to check things.
enum TodoSuggestion {
  passport(TodoCategory.documents),
  entryRequirements(TodoCategory.documents),
  insurance(TodoCategory.health),
  medication(TodoCategory.health),
  confirmStay(TodoCategory.bookings),
  checkIn(TodoCategory.bookings),
  airportTransport(TodoCategory.bookings),
  bankCards(TodoCategory.money),
  localCash(TodoCategory.money),
  simCard(TodoCategory.connectivity),
  offlineCopies(TodoCategory.connectivity),
  chargers(TodoCategory.packing),
  homeArrangements(TodoCategory.home);

  const TodoSuggestion(this.category);
  final TodoCategory category;
}

/// A "Before you go" task. Entity of the Checklist context.
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.tripId,
    required this.title,
    this.notes,
    this.category = TodoCategory.other,
    this.dueDate,
    this.isDone = false,
    this.doneAt,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String title;
  final String? notes;
  final TodoCategory category;

  /// Local date in the trip's time zone.
  final LocalDate? dueDate;
  final bool isDone;
  final DateTime? doneAt;
  final int sortOrder;
  final DateTime createdAt;

  ChecklistItem markDone(bool done, DateTime at) => ChecklistItem(
    id: id,
    tripId: tripId,
    title: title,
    notes: notes,
    category: category,
    dueDate: dueDate,
    isDone: done,
    doneAt: done ? at : null,
    sortOrder: sortOrder,
    createdAt: createdAt,
  );

  ChecklistItem copyAsNew({required String id, required String tripId, required DateTime at}) => ChecklistItem(
    id: id,
    tripId: tripId,
    title: title,
    notes: notes,
    category: category,
    dueDate: dueDate,
    sortOrder: sortOrder,
    createdAt: at,
  );

  ChecklistItem edit({required String title, String? notes, required TodoCategory category, LocalDate? dueDate}) =>
      ChecklistItem(
        id: id,
        tripId: tripId,
        title: title,
        notes: notes,
        category: category,
        dueDate: dueDate,
        isDone: isDone,
        doneAt: doneAt,
        sortOrder: sortOrder,
        createdAt: createdAt,
      );
}

sealed class TodoDue {
  const TodoDue();
}

class TodoNoDue extends TodoDue {
  const TodoNoDue();
}

class TodoDueIn extends TodoDue {
  const TodoDueIn(this.days);
  final int days;
}

class TodoOverdue extends TodoDue {
  const TodoOverdue(this.days);
  final int days;
}

/// Due status of an open task relative to [today] (in the trip time zone).
TodoDue todoDue({required LocalDate? due, required LocalDate today}) {
  if (due == null) return const TodoNoDue();
  final d = today.daysUntil(due);
  return d < 0 ? TodoOverdue(-d) : TodoDueIn(d);
}

/// Open tasks first (earliest due date first, undated last), then done ones.
int compareChecklistItems(ChecklistItem a, ChecklistItem b) {
  if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
  if ((a.dueDate == null) != (b.dueDate == null)) return a.dueDate == null ? 1 : -1;
  if (a.dueDate != null) {
    final c = a.dueDate!.compareTo(b.dueDate!);
    if (c != 0) return c;
  }
  final o = a.sortOrder.compareTo(b.sortOrder);
  return o != 0 ? o : a.createdAt.compareTo(b.createdAt);
}
