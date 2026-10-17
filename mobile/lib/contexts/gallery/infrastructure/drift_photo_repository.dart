import 'package:drift/drift.dart';
import 'package:wanderplan/contexts/gallery/domain/photo.dart';
import 'package:wanderplan/contexts/gallery/domain/photo_repository.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftPhotoRepository implements PhotoRepository {
  DriftPhotoRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$TripPhotosTable, TripPhotoRow> _byTrip(String tripId) => _db.select(_db.tripPhotos)
    ..where((t) => t.tripId.equals(tripId))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

  @override
  Stream<List<Photo>> watchByTrip(String tripId) => _byTrip(tripId).watch().map((rs) => rs.map(_toDomain).toList());

  @override
  Future<List<Photo>> findByTrip(String tripId) async => (await _byTrip(tripId).get()).map(_toDomain).toList();

  @override
  Future<Photo?> findById(String id) async {
    final r = await (_db.select(_db.tripPhotos)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _toDomain(r);
  }

  @override
  Stream<Map<String, int>> watchCounts() {
    final count = _db.tripPhotos.id.count();
    final q = _db.selectOnly(_db.tripPhotos)
      ..addColumns([_db.tripPhotos.tripId, count])
      ..groupBy([_db.tripPhotos.tripId]);
    return q.watch().map((rows) => {for (final r in rows) r.read(_db.tripPhotos.tripId)!: r.read(count)!});
  }

  @override
  Future<void> insert(Photo p) => _db.into(_db.tripPhotos).insert(_toRow(p).toCompanion(false));

  @override
  Future<void> update(Photo p) => _db.update(_db.tripPhotos).replace(_toRow(p).toCompanion(false));

  @override
  Future<void> delete(String id) => (_db.delete(_db.tripPhotos)..where((t) => t.id.equals(id))).go();

  static Photo _toDomain(TripPhotoRow r) => Photo(
    id: r.id,
    tripId: r.tripId,
    relPath: r.relPath,
    caption: r.caption,
    isFavorite: r.isFavorite,
    createdAt: r.createdAt,
  );

  static TripPhotoRow _toRow(Photo p) => TripPhotoRow(
    id: p.id,
    tripId: p.tripId,
    relPath: p.relPath,
    caption: p.caption,
    isFavorite: p.isFavorite,
    createdAt: p.createdAt,
  );
}
