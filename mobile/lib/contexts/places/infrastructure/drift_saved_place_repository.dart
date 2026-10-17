import 'package:drift/drift.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/saved_place.dart';
import 'package:wanderplan/contexts/places/domain/saved_place_repository.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftSavedPlaceRepository implements SavedPlaceRepository {
  DriftSavedPlaceRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$SavedPlacesTable, SavedPlaceRow> _byTrip(String tripId) => _db.select(_db.savedPlaces)
    ..where((t) => t.tripId.equals(tripId))
    ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

  List<SavedPlace> _map(List<SavedPlaceRow> rows) => rows.map(toDomain).whereType<SavedPlace>().toList();

  @override
  Stream<List<SavedPlace>> watchByTrip(String tripId) => _byTrip(tripId).watch().map(_map);

  @override
  Future<List<SavedPlace>> findByTrip(String tripId) async => _map(await _byTrip(tripId).get());

  @override
  Future<SavedPlace?> findById(String id) async {
    final r = await (_db.select(_db.savedPlaces)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : toDomain(r);
  }

  @override
  Future<void> save(SavedPlace p) => _db.into(_db.savedPlaces).insertOnConflictUpdate(
    SavedPlaceRow(
      id: p.id,
      tripId: p.tripId,
      name: p.name,
      category: p.category.name,
      latitude: p.point.latitude,
      longitude: p.point.longitude,
      address: p.address,
      coordinateSource: p.source,
      notes: p.notes,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    ).toCompanion(false),
  );

  @override
  Future<void> delete(String id) => (_db.delete(_db.savedPlaces)..where((t) => t.id.equals(id))).go();

  /// Rows that violate domain invariants are skipped.
  static SavedPlace? toDomain(SavedPlaceRow r) {
    final point = GeoPoint.tryCreate(r.latitude, r.longitude);
    if (point == null) return null;
    try {
      return SavedPlace(
        id: r.id,
        tripId: r.tripId,
        name: r.name,
        category: enumByName(PlaceCategory.values, r.category) ?? PlaceCategory.other,
        point: point,
        address: r.address,
        source: r.coordinateSource,
        notes: r.notes,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );
    } catch (_) {
      return null;
    }
  }
}
