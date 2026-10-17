import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';

/// Last known status per flight activity of a trip.
final flightStatusesProvider = StreamProvider.family<Map<String, FlightStatus>, String>(
  (ref, tripId) => ref.watch(flightUpdateServiceProvider).watchStatuses(tripId),
);

/// The app's connection to the WanderPlan server: who it is signed in as, or
/// why it can't connect. Signs in by itself the first time.
final flightConnectionProvider = FutureProvider<({bool available, String? user, FlightLookupFailure? failure})>((
  ref,
) async {
  final s = ref.watch(flightUpdateServiceProvider);
  if (!s.available) return (available: false, user: null, failure: FlightLookupFailure.notConnected);
  try {
    return (available: true, user: await s.checkConnection(), failure: null);
  } on FlightLookupException catch (e) {
    return (available: true, user: null, failure: e.failure);
  }
});
