import 'saved_place.dart';

abstract interface class SavedPlaceRepository {
  /// Oldest first.
  Stream<List<SavedPlace>> watchByTrip(String tripId);
  Future<List<SavedPlace>> findByTrip(String tripId);
  Future<SavedPlace?> findById(String id);

  /// Inserts or replaces.
  Future<void> save(SavedPlace place);
  Future<void> delete(String id);
}
