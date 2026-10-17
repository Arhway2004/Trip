import 'trip.dart';

/// Persistence port for the Trip aggregate (trip + destinations + banner).
abstract interface class TripRepository {
  /// All trips in manual order, newest first among equal order.
  Stream<List<Trip>> watchAll();
  Stream<Trip?> watchById(String id);
  Future<Trip?> findById(String id);

  /// Inserts a new trip at the top of the manual order.
  Future<void> insertFirst(Trip trip);

  /// Replaces the trip, its destinations and its banner.
  Future<void> save(Trip trip);
  Future<void> delete(String id);

  /// Persists a manual order for [orderedIds] (a subset keeps relative order).
  Future<void> reorder(List<String> orderedIds);
  Future<void> deleteAll();
}
