import 'activity.dart';

abstract interface class ActivityRepository {
  /// Chronological ([compareActivities]).
  Stream<List<Activity>> watchByTrip(String tripId);
  Future<List<Activity>> findByTrip(String tripId);
  Future<Activity?> findById(String id);

  /// Inserts or replaces.
  Future<void> save(Activity activity);
  Future<void> delete(String id);
}
