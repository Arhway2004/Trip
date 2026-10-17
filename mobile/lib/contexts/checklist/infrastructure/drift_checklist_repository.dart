import 'package:drift/drift.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_repository.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftChecklistRepository implements ChecklistRepository {
  DriftChecklistRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$TripTodosTable, TripTodoRow> _byTrip(String tripId) =>
      _db.select(_db.tripTodos)..where((t) => t.tripId.equals(tripId));

  List<ChecklistItem> _sorted(List<TripTodoRow> rows) => rows.map(_toDomain).toList()..sort(compareChecklistItems);

  @override
  Stream<List<ChecklistItem>> watchByTrip(String tripId) => _byTrip(tripId).watch().map(_sorted);

  @override
  Future<List<ChecklistItem>> findByTrip(String tripId) async => _sorted(await _byTrip(tripId).get());

  @override
  Future<ChecklistItem?> findById(String id) async {
    final r = await (_db.select(_db.tripTodos)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _toDomain(r);
  }

  @override
  Stream<Map<String, (int, int)>> watchProgress() {
    final total = _db.tripTodos.id.count();
    final done = _db.tripTodos.id.count(filter: _db.tripTodos.isDone.equals(true));
    final q = _db.selectOnly(_db.tripTodos)
      ..addColumns([_db.tripTodos.tripId, total, done])
      ..groupBy([_db.tripTodos.tripId]);
    return q.watch().map(
      (rows) => {for (final r in rows) r.read(_db.tripTodos.tripId)!: (r.read(done)!, r.read(total)!)},
    );
  }

  @override
  Future<int> nextSortOrder(String tripId) async {
    final max = _db.tripTodos.sortOrder.max();
    final q = _db.selectOnly(_db.tripTodos)
      ..addColumns([max])
      ..where(_db.tripTodos.tripId.equals(tripId));
    return ((await q.getSingle()).read(max) ?? -1) + 1;
  }

  @override
  Future<void> save(ChecklistItem item) =>
      _db.into(_db.tripTodos).insertOnConflictUpdate(_toRow(item).toCompanion(false));

  @override
  Future<void> delete(String id) => (_db.delete(_db.tripTodos)..where((t) => t.id.equals(id))).go();

  static ChecklistItem _toDomain(TripTodoRow r) => ChecklistItem(
    id: r.id,
    tripId: r.tripId,
    title: r.title,
    notes: r.notes,
    category: enumByName(TodoCategory.values, r.category) ?? TodoCategory.other,
    dueDate: LocalDate.tryParse(r.dueDate),
    isDone: r.isDone,
    doneAt: r.doneAt,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
  );

  static TripTodoRow _toRow(ChecklistItem i) => TripTodoRow(
    id: i.id,
    tripId: i.tripId,
    title: i.title,
    notes: i.notes,
    category: i.category.name,
    dueDate: i.dueDate?.toIso(),
    isDone: i.isDone,
    doneAt: i.doneAt,
    sortOrder: i.sortOrder,
    createdAt: i.createdAt,
  );
}
