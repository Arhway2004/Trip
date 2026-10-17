import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// Input (command DTO) for creating or editing a trip. Only [title] is required.
class TripDraft {
  TripDraft({
    required this.title,
    this.description,
    this.destinations = const [],
    this.startDate,
    this.endDate,
    this.departureTime,
    this.datesConfirmed = false,
    required this.timeZone,
    this.travelerCount = 1,
    this.currency,
    this.totalBudget,
    this.travelStyle,
    this.stage = TripStage.planning,
    this.coverImageSourcePath,
  });

  factory TripDraft.fromTrip(Trip t) => TripDraft(
    title: t.title,
    description: t.description,
    destinations: t.destinations,
    startDate: t.startDate,
    endDate: t.endDate,
    departureTime: t.departureTime,
    datesConfirmed: t.datesConfirmed,
    timeZone: t.timeZone,
    travelerCount: t.travelerCount,
    currency: t.currency,
    totalBudget: t.totalBudget,
    travelStyle: t.travelStyle,
    stage: t.stage,
  );

  String title;
  String? description;
  List<Destination> destinations;
  LocalDate? startDate;
  LocalDate? endDate;
  String? departureTime;
  bool datesConfirmed;
  String timeZone;
  int travelerCount;
  String? currency;
  double? totalBudget;
  TravelStyle? travelStyle;
  TripStage stage;

  /// Optional picked image to import as the cover when saving.
  String? coverImageSourcePath;

  /// Applies the draft onto [base] (or builds a new trip when [base] is null).
  Trip toTrip({required String id, required DateTime now, Trip? base, required BannerConfig banner}) => Trip(
    id: id,
    title: title,
    description: (description ?? '').trim().isEmpty ? null : description!.trim(),
    startDate: startDate,
    endDate: endDate,
    departureTime: startDate == null ? null : departureTime,
    datesConfirmed: startDate != null && datesConfirmed,
    timeZone: timeZone,
    travelerCount: travelerCount,
    currency: (currency ?? '').trim().isEmpty ? null : currency!.trim().toUpperCase(),
    totalBudget: totalBudget,
    travelStyle: travelStyle,
    stage: stage,
    archived: base?.archived ?? false,
    sortOrder: base?.sortOrder ?? 0,
    createdAt: base?.createdAt ?? now,
    updatedAt: now,
    destinations: destinations.where((d) => !d.isEmpty).toList(),
    banner: banner,
  );
}
