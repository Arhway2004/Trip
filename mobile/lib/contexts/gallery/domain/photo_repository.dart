import 'photo.dart';

abstract interface class PhotoRepository {
  /// Newest first.
  Stream<List<Photo>> watchByTrip(String tripId);
  Future<List<Photo>> findByTrip(String tripId);
  Future<Photo?> findById(String id);

  /// Photo count per trip ID (trips without photos are absent).
  Stream<Map<String, int>> watchCounts();
  Future<void> insert(Photo photo);
  Future<void> update(Photo photo);
  Future<void> delete(String id);
}
