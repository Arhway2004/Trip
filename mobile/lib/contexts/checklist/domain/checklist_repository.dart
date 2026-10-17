import 'checklist_item.dart';

abstract interface class ChecklistRepository {
  /// Sorted with [compareChecklistItems].
  Stream<List<ChecklistItem>> watchByTrip(String tripId);
  Future<List<ChecklistItem>> findByTrip(String tripId);
  Future<ChecklistItem?> findById(String id);

  /// (done, total) per trip ID.
  Stream<Map<String, (int, int)>> watchProgress();
  Future<int> nextSortOrder(String tripId);

  /// Inserts or replaces.
  Future<void> save(ChecklistItem item);
  Future<void> delete(String id);
}
