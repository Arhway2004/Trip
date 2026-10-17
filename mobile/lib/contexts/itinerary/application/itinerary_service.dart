import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity_repository.dart';
import 'package:wanderplan/shared/application/unit_of_work.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// Input for creating/editing an activity.
class ActivityDraft {
  ActivityDraft({
    required this.title,
    this.kind = ActivityKind.sightseeing,
    required this.date,
    this.startMinute,
    this.endDate,
    this.endMinute,
    this.location = const PlaceRef(),
    this.destination = const PlaceRef(),
    this.cost,
    this.currency,
    this.bookingStatus = BookingStatus.notBooked,
    this.provider,
    this.serviceNumber,
    this.bookingReference,
    this.bookingUrl,
    this.isLocked = false,
    this.isOptional = false,
    this.notes,
  });

  factory ActivityDraft.fromActivity(Activity a) => ActivityDraft(
    title: a.title,
    kind: a.kind,
    date: a.date,
    startMinute: a.startMinute,
    endDate: a.endDate,
    endMinute: a.endMinute,
    location: a.location,
    destination: a.destination,
    cost: a.cost,
    currency: a.currency,
    bookingStatus: a.bookingStatus,
    provider: a.provider,
    serviceNumber: a.serviceNumber,
    bookingReference: a.bookingReference,
    bookingUrl: a.bookingUrl,
    isLocked: a.isLocked,
    isOptional: a.isOptional,
    notes: a.notes,
  );

  String title;
  ActivityKind kind;
  LocalDate date;

  /// Null (with [endMinute]) while the time is not decided.
  int? startMinute;
  LocalDate? endDate;
  int? endMinute;
  PlaceRef location;
  PlaceRef destination;
  double? cost;
  String? currency;
  BookingStatus bookingStatus;
  String? provider;
  String? serviceNumber;
  String? bookingReference;
  String? bookingUrl;
  bool isLocked;
  bool isOptional;
  String? notes;

  Activity toActivity({
    required String id,
    required String tripId,
    required DateTime createdAt,
    required DateTime now,
  }) => Activity(
    id: id,
    tripId: tripId,
    title: title,
    kind: kind,
    date: date,
    startMinute: startMinute,
    endDate: endDate,
    endMinute: endMinute,
    location: location,
    destination: kind.isTransport ? destination : const PlaceRef(),
    cost: cost,
    currency: (currency ?? '').trim().isEmpty ? null : currency!.trim().toUpperCase(),
    bookingStatus: bookingStatus,
    provider: _clean(provider),
    serviceNumber: _clean(serviceNumber),
    bookingReference: _clean(bookingReference),
    bookingUrl: _clean(bookingUrl),
    isLocked: isLocked,
    isOptional: isOptional,
    notes: _clean(notes),
    createdAt: createdAt,
    updatedAt: now,
  );
}

/// Raised when a change would move a locked (confirmed) booking.
class LockedActivityException extends DomainException {
  const LockedActivityException() : super('This activity is locked');
}

/// Use cases of the Itinerary context.
class ItineraryService {
  ItineraryService({
    required ActivityRepository activities,
    required UnitOfWork uow,
    required IdGenerator ids,
    required Clock clock,
  }) : _activities = activities,
       _uow = uow,
       _ids = ids,
       _clock = clock;

  final ActivityRepository _activities;
  final UnitOfWork _uow;
  final IdGenerator _ids;
  final Clock _clock;

  Stream<List<Activity>> watchActivities(String tripId) => _activities.watchByTrip(tripId);
  Future<List<Activity>> activitiesOf(String tripId) => _activities.findByTrip(tripId);
  Future<Activity?> getActivity(String id) => _activities.findById(id);

  Future<String> addActivity(String tripId, ActivityDraft d) async {
    final now = _clock();
    final a = d.toActivity(id: _ids.newId(), tripId: tripId, createdAt: now, now: now);
    await _activities.save(a);
    return a.id;
  }

  Future<List<String>> addActivities(String tripId, List<ActivityDraft> drafts) =>
      _uow.run(() async => [for (final d in drafts) await addActivity(tripId, d)]);

  Future<void> updateActivity(String id, ActivityDraft d) async {
    final current = await _require(id);
    await _activities.save(d.toActivity(id: id, tripId: current.tripId, createdAt: current.createdAt, now: _clock()));
  }

  /// Moves an activity to a new date/start time keeping its duration.
  /// Locked activities are never moved implicitly.
  /// [startMinute] null keeps an untimed activity untimed (only its date moves).
  Future<void> moveActivity(String id, LocalDate date, int? startMinute) async {
    final a = await _require(id);
    if (a.isLocked) throw const LockedActivityException();
    await _activities.save(a.movedTo(date, startMinute, _clock()));
  }

  Future<void> resizeActivity(String id, int durationMinutes) async {
    final a = await _require(id);
    if (a.isLocked) throw const LockedActivityException();
    await _activities.save(a.resized(durationMinutes, _clock()));
  }

  Future<void> setLocked(String id, bool locked) async =>
      _activities.save((await _require(id)).copyWith(isLocked: locked, updatedAt: _clock()));

  Future<void> deleteActivity(String id) => _activities.delete(id);

  /// Gives every activity of the trip whose location or destination is named
  /// [name] (and has no coordinates yet) the coordinates the user confirmed.
  /// Names are kept as written. Returns how many activities changed.
  Future<int> locateByName(String tripId, String name, GeoPoint point, String source) => _uow.run(() async {
    final key = name.trim();
    var changed = 0;
    final now = _clock();
    for (final a in await _activities.findByTrip(tripId)) {
      final loc = a.location.point == null && a.location.name?.trim() == key;
      final dest = a.kind.isTransport && a.destination.point == null && a.destination.name?.trim() == key;
      if (!loc && !dest) continue;
      await _activities.save(
        a.copyWith(
          location: loc ? PlaceRef(name: a.location.name, point: point, source: source) : null,
          destination: dest ? PlaceRef(name: a.destination.name, point: point, source: source) : null,
          updatedAt: now,
        ),
      );
      changed++;
    }
    return changed;
  });

  Future<void> restoreActivity(Activity a) => _activities.save(a);

  /// Duplicates an activity (e.g. "same lunch spot tomorrow").
  Future<String> duplicateActivity(String id, {LocalDate? toDate}) async {
    final a = await _require(id);
    final now = _clock();
    final copy = (toDate == null ? a : a.movedTo(toDate, a.startMinute, now)).copyWith(
      id: _ids.newId(),
      isLocked: false,
      bookingStatus: BookingStatus.notBooked,
      clearBookingReference: true,
      createdAt: now,
      updatedAt: now,
    );
    await _activities.save(copy);
    return copy.id;
  }

  /// Copies the plan to another trip as a template: bookings are reset.
  Future<Map<String, String>> copyActivities(String fromTripId, String toTripId) async {
    final now = _clock();
    final idMap = <String, String>{};
    for (final a in await _activities.findByTrip(fromTripId)) {
      final id = _ids.newId();
      idMap[a.id] = id;
      await _activities.save(
        a.copyWith(
          id: id,
          tripId: toTripId,
          isLocked: false,
          bookingStatus: a.isCancelled ? BookingStatus.cancelled : BookingStatus.notBooked,
          clearBookingReference: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return idMap;
  }

  Future<Activity> _require(String id) async =>
      await _activities.findById(id) ?? (throw EntityNotFoundException('Activity', id));
}

String? _clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
