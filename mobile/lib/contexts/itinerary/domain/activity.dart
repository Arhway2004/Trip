import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

enum ActivityKind {
  sightseeing,
  food,
  activity,
  shopping,
  rest,
  flight,
  train,
  bus,
  transfer,
  ferry,

  /// A journey whose mode (flight, train, bus…) hasn't been decided yet.
  transport,
  hotel,
  other;

  bool get isTransport => switch (this) {
    flight || train || bus || transfer || ferry || transport => true,
    _ => false,
  };

  /// Hotel stays span nights and don't block the day's schedule.
  bool get isStay => this == hotel;

  /// Time to be at the departure point before departure, as a rule of thumb.
  int get recommendedBufferMinutes => switch (this) {
    flight => 120,
    train => 30,
    bus || ferry => 20,
    _ => 0,
  };
}

enum BookingStatus { notBooked, booked, confirmed, cancelled }

/// A named place with optional verified coordinates.
class PlaceRef {
  const PlaceRef({this.name, this.point, this.source});

  final String? name;

  /// Null until the user picks it on a map or from a place search.
  final GeoPoint? point;

  /// `map`, `search:<provider>` or `import`.
  final String? source;

  bool get isEmpty => (name ?? '').trim().isEmpty && point == null;

  /// Same place for scheduling purposes.
  bool sameAs(PlaceRef o) {
    if (point != null && o.point != null) return point!.distanceKmTo(o.point!) < 0.2;
    final a = name?.trim().toLowerCase(), b = o.name?.trim().toLowerCase();
    return a != null && a.isNotEmpty && a == b;
  }
}

/// One entry on the itinerary: a visit, meal, transport segment or hotel stay.
/// Entity of the Itinerary context. Times are local to the trip time zone.
///
/// The time may be unknown ([hasTime] false) while a schedule isn't
/// confirmed: the app never invents a placeholder time. Untimed activities
/// keep their date(s) but are left out of overlap and buffer checks, and their
/// day is reported as needing information.
class Activity {
  Activity({
    required this.id,
    required this.tripId,
    required String title,
    this.kind = ActivityKind.sightseeing,
    required this.date,
    this.startMinute,
    LocalDate? endDate,
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
    required this.createdAt,
    required this.updatedAt,
  }) : title = title.trim(),
       endDate = (endDate == null || endDate == date) ? null : endDate {
    if (this.title.isEmpty) throw const DomainException('An activity needs a title');
    if ((startMinute == null) != (endMinute == null)) {
      throw const DomainException('Set both a start and an end time, or neither');
    }
    if (hasTime) {
      if (startMinute! < 0 || startMinute! >= _day || endMinute! < 0 || endMinute! > _day) {
        throw const DomainException('Times must be within the day');
      }
      if (endAbsolute <= startAbsolute) throw const DomainException('An activity must end after it starts');
    } else if (lastDate < date) {
      throw const DomainException('An activity must end after it starts');
    }
    if (cost != null && cost! < 0) throw const DomainException('Cost cannot be negative');
  }

  static const _day = 24 * 60;

  final String id;
  final String tripId;
  final String title;
  final ActivityKind kind;
  final LocalDate date;

  /// Minutes after midnight; null while the time is not decided.
  final int? startMinute;

  /// Only set when the activity ends on a later day (overnight trains, hotel stays).
  final LocalDate? endDate;
  final int? endMinute;

  /// Where it happens, or the departure point for transport.
  final PlaceRef location;

  /// Arrival point for transport.
  final PlaceRef destination;
  final double? cost;
  final String? currency;
  final BookingStatus bookingStatus;
  final String? provider;
  final String? serviceNumber;
  final String? bookingReference;
  final String? bookingUrl;
  final bool isLocked;
  final bool isOptional;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  LocalDate get lastDate => endDate ?? date;
  bool get hasTime => startMinute != null;

  /// Absolute minutes for ordering. An untimed activity spans its whole day(s).
  int get startAbsolute => date.epochDay * _day + (startMinute ?? 0);
  int get endAbsolute => lastDate.epochDay * _day + (endMinute ?? _day);

  /// Null while the time is not decided.
  int? get durationMinutes => hasTime ? endAbsolute - startAbsolute : null;
  bool get isCancelled => bookingStatus == BookingStatus.cancelled;

  /// Nights covered by a hotel stay (check-in date up to the day before check-out).
  List<LocalDate> get nights => kind.isStay && lastDate > date ? date.through(lastDate.addDays(-1)) : const [];

  /// Where the traveller is after this activity.
  PlaceRef get endPlace => kind.isTransport && !destination.isEmpty ? destination : location;

  /// Minutes of this activity that fall on [day] (for day timelines).
  /// Null for untimed activities (they have no place on a time grid).
  (int start, int end)? spanOn(LocalDate day) {
    if (!hasTime) return null;
    final dayStart = day.epochDay * _day, dayEnd = dayStart + _day;
    final s = startAbsolute < dayStart ? dayStart : startAbsolute;
    final e = endAbsolute > dayEnd ? dayEnd : endAbsolute;
    return e > s ? (s - dayStart, e - dayStart) : null;
  }

  Activity copyWith({
    String? id,
    String? tripId,
    String? title,
    ActivityKind? kind,
    LocalDate? date,
    int? startMinute,
    LocalDate? endDate,
    bool clearEndDate = false,
    int? endMinute,
    bool clearTimes = false,
    PlaceRef? location,
    PlaceRef? destination,
    double? cost,
    bool clearCost = false,
    String? currency,
    BookingStatus? bookingStatus,
    String? bookingReference,
    bool clearBookingReference = false,
    bool? isLocked,
    bool? isOptional,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Activity(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    date: date ?? this.date,
    startMinute: clearTimes ? null : (startMinute ?? this.startMinute),
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    endMinute: clearTimes ? null : (endMinute ?? this.endMinute),
    location: location ?? this.location,
    destination: destination ?? this.destination,
    cost: clearCost ? null : (cost ?? this.cost),
    currency: currency ?? this.currency,
    bookingStatus: bookingStatus ?? this.bookingStatus,
    provider: provider,
    serviceNumber: serviceNumber,
    bookingReference: clearBookingReference ? null : (bookingReference ?? this.bookingReference),
    bookingUrl: bookingUrl,
    isLocked: isLocked ?? this.isLocked,
    isOptional: isOptional ?? this.isOptional,
    notes: notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Same activity moved so it starts at [newStart] on [newDate], keeping its
  /// duration. An untimed activity keeps no time unless [newStart] is given
  /// (then it gets a 1-hour slot); otherwise only its dates shift.
  Activity movedTo(LocalDate newDate, int? newStart, DateTime now) {
    if (!hasTime && newStart == null) {
      final span = date.daysUntil(lastDate);
      return copyWith(date: newDate, endDate: newDate.addDays(span), updatedAt: now);
    }
    newStart ??= startMinute!;
    final duration = durationMinutes ?? 60;
    final endAbs = newDate.epochDay * _day + newStart + duration;
    final endDay = endAbs ~/ _day;
    var endMin = endAbs % _day;
    var endDate = LocalDate.fromDateTime(DateTime.utc(1970).add(Duration(days: endDay)));
    if (endMin == 0 && endDay > newDate.epochDay) {
      endDate = endDate.addDays(-1);
      endMin = _day;
    }
    return copyWith(date: newDate, startMinute: newStart, endDate: endDate, endMinute: endMin, updatedAt: now);
  }

  /// Same start, new duration (minimum 15 minutes). Untimed activities are unchanged.
  Activity resized(int newDurationMinutes, DateTime now) {
    if (!hasTime) return this;
    final d = newDurationMinutes < 15 ? 15 : newDurationMinutes;
    final endAbs = startAbsolute + d;
    final endDay = endAbs ~/ _day;
    var endMin = endAbs % _day;
    var end = LocalDate.fromDateTime(DateTime.utc(1970).add(Duration(days: endDay)));
    if (endMin == 0) {
      end = end.addDays(-1);
      endMin = _day;
    }
    return copyWith(endDate: end, endMinute: endMin, updatedAt: now);
  }
}

/// Chronological order; hotel stays sort after same-time activities.
int compareActivities(Activity a, Activity b) {
  final c = a.startAbsolute.compareTo(b.startAbsolute);
  if (c != 0) return c;
  if (a.kind.isStay != b.kind.isStay) return a.kind.isStay ? 1 : -1;
  return a.createdAt.compareTo(b.createdAt);
}
