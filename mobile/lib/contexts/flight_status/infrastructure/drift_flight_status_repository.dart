import 'dart:convert';

import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftFlightStatusRepository implements FlightStatusRepository {
  DriftFlightStatusRepository(this._db);
  final AppDatabase _db;

  static FlightStatus? _decode(FlightStatusRow r) {
    try {
      return FlightStatus.fromJson((jsonDecode(r.json) as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Map<String, FlightStatus>> watchByTrip(String tripId) =>
      (_db.select(_db.flightStatuses)..where((t) => t.tripId.equals(tripId))).watch().map(
        (rows) => {for (final r in rows) r.activityId: ?_decode(r)},
      );

  @override
  Future<FlightStatus?> find(String activityId) async {
    final r = await (_db.select(
      _db.flightStatuses,
    )..where((t) => t.activityId.equals(activityId))).getSingleOrNull();
    return r == null ? null : _decode(r);
  }

  @override
  Future<void> save(String activityId, String tripId, FlightStatus status) => _db
      .into(_db.flightStatuses)
      .insertOnConflictUpdate(
        FlightStatusRow(
          activityId: activityId,
          tripId: tripId,
          json: jsonEncode(status.toJson()),
          fetchedAt: status.fetchedAt,
        ),
      );

  FlightLink? _link(FlightLinkRow r) {
    final d = LocalDate.tryParse(r.flightDate);
    if (d == null) return null;
    return FlightLink(
      activityId: r.activityId,
      tripId: r.tripId,
      bookingId: r.bookingId,
      flightId: r.flightId,
      code: r.code,
      date: d,
    );
  }

  @override
  Future<List<FlightLink>> links() async => [for (final r in await _db.select(_db.flightLinks).get()) ?_link(r)];

  @override
  Future<FlightLink?> link(String activityId) async {
    final r = await (_db.select(_db.flightLinks)..where((t) => t.activityId.equals(activityId))).getSingleOrNull();
    return r == null ? null : _link(r);
  }

  @override
  Future<void> saveLink(FlightLink l) => _db
      .into(_db.flightLinks)
      .insertOnConflictUpdate(
        FlightLinkRow(
          activityId: l.activityId,
          tripId: l.tripId,
          bookingId: l.bookingId,
          flightId: l.flightId,
          code: l.code,
          flightDate: l.date.toIso(),
        ),
      );

  @override
  Future<void> deleteLink(String activityId) =>
      (_db.delete(_db.flightLinks)..where((t) => t.activityId.equals(activityId))).go();
}
