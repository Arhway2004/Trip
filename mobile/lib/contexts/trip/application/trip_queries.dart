import 'package:rxdart/rxdart.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_repository.dart';
import 'package:wanderplan/contexts/gallery/domain/photo_repository.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/domain/countdown.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

enum TripFilter { all, upcoming, traveling, completed, archived }

bool matchesFilter(TripStatus status, TripFilter filter) => switch (filter) {
  TripFilter.all => status != TripStatus.archived,
  TripFilter.upcoming => status == TripStatus.upcoming,
  TripFilter.traveling => status == TripStatus.traveling,
  TripFilter.completed => status == TripStatus.completed,
  TripFilter.archived => status == TripStatus.archived,
};

/// Read model for lists and dashboards: a trip plus stats from other contexts.
class TripSummary {
  const TripSummary({required this.trip, this.photoCount = 0, this.todosDone = 0, this.todosTotal = 0});

  final Trip trip;
  final int photoCount;
  final int todosDone;
  final int todosTotal;

  String get id => trip.id;
  LocalDate? get start => trip.startDate;
  LocalDate? get end => trip.endDate;
  int? get durationDays => trip.durationDays;
  TravelStyle? get travelStyle => trip.travelStyle;
  TripStage get stage => trip.stage;
  BannerConfig get banner => trip.banner;
  List<Destination> get destinations => trip.destinations;
  String? get primaryDestination => trip.primaryDestination;
  List<String> get additionalDestinations => trip.additionalDestinations;
  CountdownState countdown(DateTime now) => trip.countdown(now);
  TripStatus status(DateTime now) => trip.status(now);
}

/// Query side of the Trip context (CQRS-lite).
class TripQueryService {
  TripQueryService({
    required TripRepository trips,
    required PhotoRepository photos,
    required ChecklistRepository checklist,
  }) : _trips = trips,
       _photos = photos,
       _checklist = checklist;

  final TripRepository _trips;
  final PhotoRepository _photos;
  final ChecklistRepository _checklist;

  Stream<List<TripSummary>> watchSummaries() => Rx.combineLatest3(
    _trips.watchAll(),
    _photos.watchCounts(),
    _checklist.watchProgress(),
    (List<Trip> ts, Map<String, int> photos, Map<String, (int, int)> todos) => [
      for (final t in ts)
        TripSummary(
          trip: t,
          photoCount: photos[t.id] ?? 0,
          todosDone: todos[t.id]?.$1 ?? 0,
          todosTotal: todos[t.id]?.$2 ?? 0,
        ),
    ],
  );

  Stream<TripSummary?> watchSummary(String id) =>
      watchSummaries().map((all) => all.where((t) => t.id == id).firstOrNull);
}
