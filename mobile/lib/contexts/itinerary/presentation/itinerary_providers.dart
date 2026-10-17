import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_settings.dart';
import 'package:wanderplan/contexts/itinerary/domain/feasibility.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';

final tripActivitiesProvider = StreamProvider.family<List<Activity>, String>(
  (ref, tripId) => ref.watch(itineraryServiceProvider).watchActivities(tripId),
);

/// Day-by-day assessment of the plan, recomputed when activities or trip dates change.
final dayAssessmentsProvider = Provider.family<List<DayAssessment>, String>((ref, tripId) {
  final trip = ref.watch(tripProvider(tripId)).value?.trip;
  final acts = ref.watch(tripActivitiesProvider(tripId)).value ?? const <Activity>[];
  return assessItinerary(activities: acts, tripStart: trip?.startDate, tripEnd: trip?.endDate);
});

/// Per-day start/end points and end-leg travel choices of a trip.
final daySettingsProvider = StreamProvider.family<List<DaySettings>, String>(
  (ref, tripId) => ref.watch(itineraryServiceProvider).watchDaySettings(tripId),
);
