import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

/// Drift adapter for [TripRepository]. Maps the `trips`, `trip_destinations`
/// and `trip_banners` tables to the Trip aggregate.
class DriftTripRepository implements TripRepository {
  DriftTripRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Stream<List<Trip>> watchAll() {
    final trips = (_db.select(
      _db.trips,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.desc(t.createdAt)])).watch();
    final dests = (_db.select(_db.tripDestinations)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();
    final banners = _db.select(_db.tripBanners).watch();
    return Rx.combineLatest3(trips, dests, banners, (
      List<TripRow> ts,
      List<TripDestinationRow> ds,
      List<TripBannerRow> bs,
    ) {
      final bannerBy = {for (final b in bs) b.tripId: b};
      final destBy = <String, List<Destination>>{};
      for (final d in ds) {
        (destBy[d.tripId] ??= []).add(Destination(country: d.country, city: d.city));
      }
      return [for (final t in ts) TripMapper.toDomain(t, destBy[t.id] ?? const [], bannerBy[t.id])];
    });
  }

  @override
  Stream<Trip?> watchById(String id) => watchAll().map((all) => all.where((t) => t.id == id).firstOrNull);

  @override
  Future<Trip?> findById(String id) async {
    final row = await (_db.select(_db.trips)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final ds =
        await (_db.select(_db.tripDestinations)
              ..where((t) => t.tripId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final b = await (_db.select(_db.tripBanners)..where((t) => t.tripId.equals(id))).getSingleOrNull();
    return TripMapper.toDomain(row, [for (final d in ds) Destination(country: d.country, city: d.city)], b);
  }

  @override
  Future<void> insertFirst(Trip trip) => _db.transaction(() async {
    await _db.customUpdate('UPDATE trips SET sort_order = sort_order + 1', updates: {_db.trips});
    await _db.into(_db.trips).insert(TripMapper.toRow(trip.copyWith(sortOrder: 0)).toCompanion(false));
    await _writeChildren(trip);
  });

  @override
  Future<void> save(Trip trip) => _db.transaction(() async {
    await _db.update(_db.trips).replace(TripMapper.toRow(trip).toCompanion(false));
    await (_db.delete(_db.tripDestinations)..where((t) => t.tripId.equals(trip.id))).go();
    await _writeChildren(trip);
  });

  Future<void> _writeChildren(Trip trip) async {
    var i = 0;
    for (final d in trip.destinations.where((d) => !d.isEmpty)) {
      await _db
          .into(_db.tripDestinations)
          .insert(
            TripDestinationsCompanion.insert(
              id: _uuid.v4(),
              tripId: trip.id,
              country: Value(_blankToNull(d.country)),
              city: Value(_blankToNull(d.city)),
              sortOrder: Value(i++),
            ),
          );
    }
    // toCompanion(false) so NULL fields (e.g. a removed image) are written.
    await _db
        .into(_db.tripBanners)
        .insertOnConflictUpdate(TripMapper.bannerToRow(trip.id, trip.banner).toCompanion(false));
  }

  @override
  Future<void> delete(String id) => (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> reorder(List<String> orderedIds) => _db.transaction(() async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(
        _db.trips,
      )..where((t) => t.id.equals(orderedIds[i]))).write(TripsCompanion(sortOrder: Value(i)));
    }
  });

  @override
  Future<void> deleteAll() => _db.delete(_db.trips).go();
}

/// Row ↔ aggregate translation, kept out of the domain.
abstract final class TripMapper {
  static Trip toDomain(TripRow t, List<Destination> destinations, TripBannerRow? b) => Trip(
    id: t.id,
    title: t.title,
    description: t.description,
    startDate: LocalDate.tryParse(t.startDate),
    endDate: LocalDate.tryParse(t.endDate),
    departureTime: t.departureTime,
    datesConfirmed: t.datesConfirmed,
    timeZone: t.timeZone,
    travelerCount: t.travelerCount,
    currency: t.currency,
    totalBudget: t.totalBudget,
    travelStyle: enumByName(TravelStyle.values, t.travelStyle),
    stage: enumByName(TripStage.values, t.stage) ?? TripStage.planning,
    archived: t.archived,
    sortOrder: t.sortOrder,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    destinations: destinations,
    banner: b == null ? BannerConfig.defaultFor(t.id) : bannerToDomain(b),
  );

  static TripRow toRow(Trip t) => TripRow(
    id: t.id,
    title: t.title,
    description: _blankToNull(t.description),
    startDate: t.startDate?.toIso(),
    endDate: t.endDate?.toIso(),
    departureTime: t.startDate == null ? null : t.departureTime,
    datesConfirmed: t.datesConfirmed,
    timeZone: t.timeZone,
    travelerCount: t.travelerCount,
    currency: t.currency?.toUpperCase(),
    totalBudget: t.totalBudget,
    travelStyle: t.travelStyle?.name,
    stage: t.stage.name,
    archived: t.archived,
    sortOrder: t.sortOrder,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  );

  static BannerConfig bannerToDomain(TripBannerRow r) => BannerConfig(
    kind: enumByName(BannerKind.values, r.kind) ?? BannerKind.gradient,
    imagePath: r.imagePath,
    scale: r.scale,
    alignX: r.alignX,
    alignY: r.alignY,
    colorA: r.colorA,
    colorB: r.colorB,
    showTitle: r.showTitle,
    titlePlacement: enumByName(TitlePlacement.values, r.titlePlacement) ?? TitlePlacement.bottomLeft,
    textColor: r.textColor,
    style: enumByName(BannerStyle.values, r.style) ?? BannerStyle.classic,
  );

  static TripBannerRow bannerToRow(String tripId, BannerConfig c) => TripBannerRow(
    tripId: tripId,
    kind: c.kind.name,
    imagePath: c.imagePath,
    scale: c.scale,
    alignX: c.alignX,
    alignY: c.alignY,
    colorA: c.colorA,
    colorB: c.colorB,
    showTitle: c.showTitle,
    titlePlacement: c.titlePlacement.name,
    textColor: c.textColor,
    style: c.style.name,
  );
}

String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
