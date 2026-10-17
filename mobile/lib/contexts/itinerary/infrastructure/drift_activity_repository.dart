import 'package:drift/drift.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity_repository.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftActivityRepository implements ActivityRepository {
  DriftActivityRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$ActivitiesTable, ActivityRow> _byTrip(String tripId) =>
      _db.select(_db.activities)..where((t) => t.tripId.equals(tripId));

  List<Activity> _map(List<ActivityRow> rows) =>
      rows.map(toDomain).whereType<Activity>().toList()..sort(compareActivities);

  @override
  Stream<List<Activity>> watchByTrip(String tripId) => _byTrip(tripId).watch().map(_map);

  @override
  Future<List<Activity>> findByTrip(String tripId) async => _map(await _byTrip(tripId).get());

  @override
  Future<Activity?> findById(String id) async {
    final r = await (_db.select(_db.activities)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : toDomain(r);
  }

  @override
  Future<void> save(Activity a) => _db.into(_db.activities).insertOnConflictUpdate(toRow(a).toCompanion(false));

  @override
  Future<void> delete(String id) => (_db.delete(_db.activities)..where((t) => t.id.equals(id))).go();

  /// Rows that violate domain invariants (e.g. edited externally) are skipped.
  static Activity? toDomain(ActivityRow r) {
    final date = LocalDate.tryParse(r.date);
    if (date == null) return null;
    try {
      return Activity(
        id: r.id,
        tripId: r.tripId,
        title: r.title,
        kind: enumByName(ActivityKind.values, r.kind) ?? ActivityKind.other,
        date: date,
        startMinute: r.hasTime ? r.startMinute : null,
        endDate: LocalDate.tryParse(r.endDate),
        endMinute: r.hasTime ? r.endMinute : null,
        location: PlaceRef(
          name: r.locationName,
          point: GeoPoint.tryCreate(r.latitude, r.longitude),
          source: r.coordinateSource,
        ),
        destination: PlaceRef(
          name: r.endLocationName,
          point: GeoPoint.tryCreate(r.endLatitude, r.endLongitude),
          source: r.coordinateSource,
        ),
        cost: r.cost,
        currency: r.currency,
        bookingStatus: enumByName(BookingStatus.values, r.bookingStatus) ?? BookingStatus.notBooked,
        provider: r.provider,
        serviceNumber: r.serviceNumber,
        bookingReference: r.bookingReference,
        bookingUrl: r.bookingUrl,
        isLocked: r.isLocked,
        isOptional: r.isOptional,
        notes: r.notes,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static ActivityRow toRow(Activity a) => ActivityRow(
    id: a.id,
    tripId: a.tripId,
    title: a.title,
    kind: a.kind.name,
    date: a.date.toIso(),
    startMinute: a.startMinute ?? 0,
    endDate: a.endDate?.toIso(),
    endMinute: a.endMinute ?? 0,
    hasTime: a.hasTime,
    locationName: a.location.name,
    latitude: a.location.point?.latitude,
    longitude: a.location.point?.longitude,
    endLocationName: a.destination.name,
    endLatitude: a.destination.point?.latitude,
    endLongitude: a.destination.point?.longitude,
    coordinateSource: a.location.source ?? a.destination.source,
    cost: a.cost,
    currency: a.currency,
    bookingStatus: a.bookingStatus.name,
    provider: a.provider,
    serviceNumber: a.serviceNumber,
    bookingReference: a.bookingReference,
    bookingUrl: a.bookingUrl,
    isLocked: a.isLocked,
    isOptional: a.isOptional,
    notes: a.notes,
    createdAt: a.createdAt,
    updatedAt: a.updatedAt,
  );
}
