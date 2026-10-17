import 'package:drift/drift.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_settings.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftDaySettingsRepository implements DaySettingsRepository {
  DriftDaySettingsRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$DayPlansTable, DayPlanRow> _byTrip(String tripId) =>
      _db.select(_db.dayPlans)..where((t) => t.tripId.equals(tripId));

  @override
  Stream<List<DaySettings>> watchByTrip(String tripId) =>
      _byTrip(tripId).watch().map((rows) => rows.map(toDomain).whereType<DaySettings>().toList());

  @override
  Future<List<DaySettings>> findByTrip(String tripId) async =>
      (await _byTrip(tripId).get()).map(toDomain).whereType<DaySettings>().toList();

  @override
  Future<DaySettings?> find(String tripId, LocalDate date) async {
    final r = await (_db.select(
      _db.dayPlans,
    )..where((t) => t.tripId.equals(tripId) & t.date.equals(date.toIso()))).getSingleOrNull();
    return r == null ? null : toDomain(r);
  }

  @override
  Future<void> save(DaySettings s) async {
    if (s.isEmpty) {
      await (_db.delete(_db.dayPlans)..where((t) => t.tripId.equals(s.tripId) & t.date.equals(s.date.toIso()))).go();
      return;
    }
    await _db
        .into(_db.dayPlans)
        .insertOnConflictUpdate(
          DayPlanRow(
            tripId: s.tripId,
            date: s.date.toIso(),
            startName: s.start.name,
            startLat: s.start.point?.latitude,
            startLng: s.start.point?.longitude,
            startSource: s.start.source,
            endName: s.end.name,
            endLat: s.end.point?.latitude,
            endLng: s.end.point?.longitude,
            endSource: s.end.source,
            endArrivalMode: s.endArrivalMode?.name,
            endArrivalMinutes: s.endArrivalMinutes,
          ),
        );
  }

  static DaySettings? toDomain(DayPlanRow r) {
    final date = LocalDate.tryParse(r.date);
    if (date == null) return null;
    return DaySettings(
      tripId: r.tripId,
      date: date,
      start: PlaceRef(name: r.startName, point: GeoPoint.tryCreate(r.startLat, r.startLng), source: r.startSource),
      end: PlaceRef(name: r.endName, point: GeoPoint.tryCreate(r.endLat, r.endLng), source: r.endSource),
      endArrivalMode: enumByName(TravelMode.values, r.endArrivalMode),
      endArrivalMinutes: r.endArrivalMinutes,
    );
  }
}
