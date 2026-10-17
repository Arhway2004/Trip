import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_repository.dart';
import 'package:wanderplan/shared/application/unit_of_work.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// Input for adding or editing a checklist item.
class TodoDraft {
  TodoDraft({required this.title, this.notes, this.category = TodoCategory.other, this.dueDate, this.isDone = false});
  String title;
  String? notes;
  TodoCategory category;
  LocalDate? dueDate;

  /// Only used when importing existing lists.
  bool isDone;
}

/// Use cases of the Checklist ("Before you go") context.
class ChecklistService {
  ChecklistService({
    required ChecklistRepository items,
    required UnitOfWork uow,
    required IdGenerator ids,
    required Clock clock,
  }) : _items = items,
       _uow = uow,
       _ids = ids,
       _clock = clock;

  final ChecklistRepository _items;
  final UnitOfWork _uow;
  final IdGenerator _ids;
  final Clock _clock;

  Stream<List<ChecklistItem>> watchItems(String tripId) => _items.watchByTrip(tripId);
  Future<List<ChecklistItem>> itemsOf(String tripId) => _items.findByTrip(tripId);

  /// Adds items in order; blank titles are ignored. Returns the new IDs.
  Future<List<String>> addItems(String tripId, List<TodoDraft> drafts) => _uow.run(() async {
    var order = await _items.nextSortOrder(tripId);
    final now = _clock();
    final ids = <String>[];
    for (final d in drafts.where((d) => d.title.trim().isNotEmpty)) {
      final item = ChecklistItem(
        id: _ids.newId(),
        tripId: tripId,
        title: d.title.trim(),
        notes: _blankToNull(d.notes),
        category: d.category,
        dueDate: d.dueDate,
        isDone: d.isDone,
        doneAt: d.isDone ? now : null,
        sortOrder: order++,
        createdAt: now,
      );
      await _items.save(item);
      ids.add(item.id);
    }
    return ids;
  });

  Future<void> updateItem(String id, TodoDraft d) async {
    final item = await _items.findById(id);
    if (item == null || d.title.trim().isEmpty) return;
    await _items.save(
      item.edit(title: d.title.trim(), notes: _blankToNull(d.notes), category: d.category, dueDate: d.dueDate),
    );
  }

  Future<void> setDone(String id, bool done) async {
    final item = await _items.findById(id);
    if (item != null) await _items.save(item.markDone(done, _clock()));
  }

  Future<void> deleteItem(String id) => _items.delete(id);

  /// Re-inserts an item removed by [deleteItem] ("Undo").
  Future<void> restoreItem(ChecklistItem item) => _items.save(item);

  /// Copies every item to [toTripId], unchecked (trip duplication).
  Future<void> copyItems(String fromTripId, String toTripId) async {
    final now = _clock();
    for (final i in await _items.findByTrip(fromTripId)) {
      await _items.save(i.copyAsNew(id: _ids.newId(), tripId: toTripId, at: now));
    }
  }
}

String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
