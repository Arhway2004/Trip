import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

enum FlightLookupFailure {
  /// This build of the app has no WanderPlan server address.
  notConnected,

  /// The server refused to sign the app in.
  signInRejected,

  /// The server has no flight-data key configured.
  serverNotConfigured,

  /// The server's flight-data plan is out of requests.
  quotaReached,

  /// Offline, timeout or the server is down.
  network,
  unknown,
}

class FlightLookupException implements Exception {
  const FlightLookupException(this.failure);
  final FlightLookupFailure failure;

  // Never include server messages or tokens.
  @override
  String toString() => 'FlightLookupException: ${failure.name}';
}

/// Where the phone reaches WanderPlan's backend, and how it signs in. The
/// flight-data provider's API key stays on the server and is never here.
class ServerConnection {
  const ServerConnection({required this.baseUrl, required this.token});
  final Uri baseUrl;
  final String token;
}

/// A flight as the server knows it (shared with everyone who booked it).
class RemoteFlight {
  const RemoteFlight({required this.flightId, required this.status, required this.stale, this.lastCheckedAt});
  final String flightId;

  /// Null until the server's first successful check.
  final FlightStatus? status;

  /// The server's last check failed; [status] is the last known answer.
  final bool stale;
  final DateTime? lastCheckedAt;
}

class RemoteBooking {
  const RemoteBooking({required this.bookingId, required this.flight});
  final String bookingId;
  final RemoteFlight flight;
}

/// Port: the backend's flight-monitoring API (bookings → shared flights).
/// Reads never cost a provider request; only [refresh] may.
abstract interface class FlightServer {
  /// Signs the app in by itself and returns its token. Development servers
  /// hand out the shared demo account; production will use a real login.
  Future<String> signIn(Uri baseUrl);

  /// Who the token belongs to (connection check).
  Future<String> whoAmI(ServerConnection c);
  Future<RemoteBooking> watch(ServerConnection c, {required String code, required LocalDate date, required String traveler});
  Future<void> unwatch(ServerConnection c, String bookingId);
  Future<List<RemoteBooking>> bookings(ServerConnection c);
  Future<RemoteFlight> refresh(ServerConnection c, String flightId);
}

/// Which server booking follows which planned flight on this phone.
class FlightLink {
  const FlightLink({
    required this.activityId,
    required this.tripId,
    required this.bookingId,
    required this.flightId,
    required this.code,
    required this.date,
  });
  final String activityId;
  final String tripId;
  final String bookingId;
  final String flightId;
  final String code;
  final LocalDate date;
}

/// Last known status per itinerary activity, and the server links.
abstract interface class FlightStatusRepository {
  Stream<Map<String, FlightStatus>> watchByTrip(String tripId);
  Future<FlightStatus?> find(String activityId);
  Future<void> save(String activityId, String tripId, FlightStatus status);

  Future<List<FlightLink>> links();
  Future<FlightLink?> link(String activityId);
  Future<void> saveLink(FlightLink link);
  Future<void> deleteLink(String activityId);
}
