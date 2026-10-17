import 'package:wanderplan/shared/domain/countdown.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import 'banner.dart';

export 'banner.dart';

enum TripStatus { dreaming, planning, upcoming, traveling, completed, archived }

enum TripStage { dreaming, planning }

enum TravelStyle { relaxed, balanced, packed, budget, comfort, luxury, adventure, family }

/// A city/country stop, ordered within the trip (first = main destination).
class Destination {
  const Destination({this.country, this.city});
  final String? country;
  final String? city;

  bool get isEmpty => (country ?? '').trim().isEmpty && (city ?? '').trim().isEmpty;
  String get label => [city, country].where((s) => s != null && s.trim().isNotEmpty).join(', ');

  @override
  bool operator ==(Object other) => other is Destination && other.country == country && other.city == city;
  @override
  int get hashCode => Object.hash(country, city);
}

String destinationLabel(Destination d) => d.label;

/// Aggregate root of the Trip context. Owns its destinations and banner;
/// photos and checklist items live in their own contexts and refer to it by ID.
class Trip {
  Trip({
    required this.id,
    required String title,
    this.description,
    this.startDate,
    LocalDate? endDate,
    this.departureTime,
    this.datesConfirmed = false,
    required this.timeZone,
    int travelerCount = 1,
    this.currency,
    this.totalBudget,
    this.travelStyle,
    this.stage = TripStage.planning,
    this.archived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.destinations = const [],
    required this.banner,
  }) : title = title.trim(),
       endDate = startDate == null ? null : endDate,
       travelerCount = travelerCount.clamp(1, maxTravelers) {
    if (this.title.isEmpty) throw const DomainException('A trip needs a title');
    if (totalBudget != null && totalBudget! < 0) throw const DomainException('Budget cannot be negative');
  }

  static const maxTravelers = 999;

  final String id;
  final String title;
  final String? description;

  /// Local calendar dates in [timeZone]. Null while undecided.
  final LocalDate? startDate;
  final LocalDate? endDate;

  /// Optional local departure time `HH:mm` on [startDate].
  final String? departureTime;
  final bool datesConfirmed;

  /// IANA time-zone identifier.
  final String timeZone;
  final int travelerCount;

  /// ISO 4217 code.
  final String? currency;
  final double? totalBudget;
  final TravelStyle? travelStyle;
  final TripStage stage;
  final bool archived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Destination> destinations;
  final BannerConfig banner;

  /// Inclusive number of days, or null while dates are undecided.
  int? get durationDays {
    final s = startDate;
    if (s == null) return null;
    final e = endDate ?? s;
    return e < s ? 1 : s.daysUntil(e) + 1;
  }

  String? get primaryDestination => destinations.isEmpty ? null : destinations.first.label;
  List<String> get additionalDestinations => destinations.skip(1).map((d) => d.label).toList();

  CountdownState countdown(DateTime now) => computeCountdown(
    start: startDate,
    end: endDate,
    departureTime: startDate == null ? null : departureTime,
    timeZone: timeZone,
    now: now,
  );

  TripStatus status(DateTime now) =>
      computeTripStatus(archived: archived, stage: stage, datesConfirmed: datesConfirmed, countdown: countdown(now));

  Trip copyWith({
    String? id,
    String? title,
    String? description,
    LocalDate? startDate,
    LocalDate? endDate,
    bool clearDates = false,
    String? departureTime,
    bool clearDepartureTime = false,
    bool? datesConfirmed,
    String? timeZone,
    int? travelerCount,
    String? currency,
    double? totalBudget,
    TravelStyle? travelStyle,
    TripStage? stage,
    bool? archived,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Destination>? destinations,
    BannerConfig? banner,
  }) => Trip(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    startDate: clearDates ? null : (startDate ?? this.startDate),
    endDate: clearDates ? null : (endDate ?? this.endDate),
    departureTime: clearDates || clearDepartureTime ? null : (departureTime ?? this.departureTime),
    datesConfirmed: clearDates ? false : (datesConfirmed ?? this.datesConfirmed),
    timeZone: timeZone ?? this.timeZone,
    travelerCount: travelerCount ?? this.travelerCount,
    currency: currency ?? this.currency,
    totalBudget: totalBudget ?? this.totalBudget,
    travelStyle: travelStyle ?? this.travelStyle,
    stage: stage ?? this.stage,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    destinations: destinations ?? this.destinations,
    banner: banner ?? this.banner,
  );
}

/// Archived wins; then dates decide traveling/completed; confirmed future
/// dates make a trip upcoming; otherwise the user's planning stage is used.
TripStatus computeTripStatus({
  required bool archived,
  required TripStage stage,
  required bool datesConfirmed,
  required CountdownState countdown,
}) {
  if (archived) return TripStatus.archived;
  return switch (countdown) {
    CountdownDuringTrip() => TripStatus.traveling,
    CountdownCompleted() => TripStatus.completed,
    CountdownBeforeDeparture() when datesConfirmed => TripStatus.upcoming,
    _ => stage == TripStage.dreaming ? TripStatus.dreaming : TripStatus.planning,
  };
}
