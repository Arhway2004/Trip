import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// Per-day choices that aren't activities: where the day starts and ends
/// (default: last night's and tonight's hotel), and how the traveller gets to
/// the end point.
class DaySettings {
  const DaySettings({
    required this.tripId,
    required this.date,
    this.start = const PlaceRef(),
    this.end = const PlaceRef(),
    this.endArrivalMode,
    this.endArrivalMinutes,
  });

  final String tripId;
  final LocalDate date;

  /// Empty = use last night's hotel.
  final PlaceRef start;

  /// Empty = use tonight's hotel.
  final PlaceRef end;
  final TravelMode? endArrivalMode;
  final int? endArrivalMinutes;

  bool get isEmpty => start.isEmpty && end.isEmpty && endArrivalMode == null && endArrivalMinutes == null;

  DaySettings copyWith({
    PlaceRef? start,
    PlaceRef? end,
    TravelMode? endArrivalMode,
    int? endArrivalMinutes,
    bool clearEndArrival = false,
  }) => DaySettings(
    tripId: tripId,
    date: date,
    start: start ?? this.start,
    end: end ?? this.end,
    endArrivalMode: clearEndArrival ? null : (endArrivalMode ?? this.endArrivalMode),
    endArrivalMinutes: clearEndArrival ? null : (endArrivalMinutes ?? this.endArrivalMinutes),
  );
}

abstract interface class DaySettingsRepository {
  Stream<List<DaySettings>> watchByTrip(String tripId);
  Future<List<DaySettings>> findByTrip(String tripId);
  Future<DaySettings?> find(String tripId, LocalDate date);

  /// Inserts or replaces; an empty value removes the row.
  Future<void> save(DaySettings settings);
}
