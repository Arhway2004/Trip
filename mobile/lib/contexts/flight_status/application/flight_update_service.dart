import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_tracking.dart';
import 'package:wanderplan/contexts/itinerary/application/booking_reminders.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity_repository.dart';
import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/application/secret_store.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/countdown.dart';

/// The result of checking one flight.
class FlightCheck {
  const FlightCheck(this.activity, {this.status, this.changes = const [], this.failure, this.stale = false});
  final Activity activity;
  final FlightStatus? status;
  final List<FlightChange> changes;
  final FlightLookupFailure? failure;

  /// The server's last check failed; [status] is the last known answer.
  final bool stale;

  /// The server has no answer for this flight yet.
  bool get noDataYet => failure == null && status == null;
}

/// Texts for change notifications, in the app's language.
typedef ChangeTexts = ({String Function(Activity) title, String Function(Activity, List<FlightChange>) body});

/// Follows booked flights through WanderPlan's backend. The flight-data
/// provider and its API key live on the server: each planned flight with a
/// flight number becomes a server booking (shared with everyone on that
/// flight), the phone reads the server's cached status (free) and may ask for
/// an urgent refresh. When something changes, the phone shows a notification.
///
/// Nothing to set up on the phone: the server address is part of the build
/// (`WANDERPLAN_API_URL`) and the app signs in by itself.
class FlightUpdateService {
  FlightUpdateService({
    required FlightServer server,
    required SecretStore secrets,
    required FlightStatusRepository statuses,
    required ActivityRepository activities,
    required TripRepository trips,
    required ReminderScheduler notifications,
    required Clock clock,
    String serverUrl = '',
  }) : _server = server,
       _serverUrl = parseServerUrl(serverUrl),
       _secrets = secrets,
       _statuses = statuses,
       _activities = activities,
       _trips = trips,
       _notifications = notifications,
       _clock = clock;

  final FlightServer _server;
  final Uri? _serverUrl;
  final SecretStore _secrets;
  final FlightStatusRepository _statuses;
  final ActivityRepository _activities;
  final TripRepository _trips;
  final ReminderScheduler _notifications;
  final Clock _clock;
  bool _syncing = false;

  static const tokenKey = 'wanderplan_server_token';

  /// Name under which an earlier version kept a provider key on the phone.
  static const legacyProviderKey = 'aviationstack_api_key';

  // --- Connection -------------------------------------------------------------

  /// Whether this build knows a WanderPlan server.
  bool get available => _serverUrl != null;

  /// Normalises "192.168.1.20:8080" → "http://192.168.1.20:8080".
  static Uri? parseServerUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) s = 'http://$s';
    final u = Uri.tryParse(s);
    if (u == null || u.host.isEmpty || !(u.scheme == 'http' || u.scheme == 'https')) return null;
    return u.replace(path: u.path.endsWith('/') ? u.path.substring(0, u.path.length - 1) : u.path);
  }

  /// The server and a token, signing in first if this phone has none yet.
  Future<ServerConnection> _connection() async {
    final url = _serverUrl;
    if (url == null) throw const FlightLookupException(FlightLookupFailure.notConnected);
    var token = await _secrets.read(tokenKey);
    if (token == null || token.isEmpty) {
      token = await _server.signIn(url);
      await _secrets.write(tokenKey, token);
      // A key from an earlier version must not stay on the phone.
      await _secrets.delete(legacyProviderKey);
    }
    return ServerConnection(baseUrl: url, token: token);
  }

  /// Runs [call] signed in. If the server no longer accepts the saved token
  /// (expired, or another server), signs in again once.
  Future<T> _signedIn<T>(Future<T> Function(ServerConnection c) call) async {
    try {
      return await call(await _connection());
    } on FlightLookupException catch (e) {
      if (e.failure != FlightLookupFailure.signInRejected || await _secrets.read(tokenKey) == null) rethrow;
      await _secrets.delete(tokenKey);
      return call(await _connection());
    }
  }

  /// Signs in if needed and returns who the app is signed in as.
  /// Throws [FlightLookupException].
  Future<String> checkConnection() => _signedIn(_server.whoAmI);

  // --- Statuses ---------------------------------------------------------------

  Stream<Map<String, FlightStatus>> watchStatuses(String tripId) => _statuses.watchByTrip(tripId);

  /// "Check now": asks the server for an urgent refresh of this flight.
  Future<FlightCheck> checkActivity(String activityId, {ChangeTexts? texts}) async {
    final a = await _activities.findById(activityId);
    if (a == null || !isTrackable(a)) throw StateError('Not a trackable flight');
    try {
      return await _signedIn((c) async {
        final link = (await _ensureLink(c, a)).link;
        return _record(a, await _server.refresh(c, link.flightId), texts);
      });
    } on FlightLookupException catch (e) {
      return FlightCheck(a, failure: e.failure);
    }
  }

  /// Keeps server bookings in step with the planned flights, then reads every
  /// flight's latest server state (no provider requests) and notifies about
  /// changes. Safe to call often (on app start/resume).
  Future<List<FlightCheck>> sync({ChangeTexts? texts}) async {
    if (_syncing || !available) return const [];
    _syncing = true;
    try {
      return await _signedIn((c) => _sync(c, texts));
    } on FlightLookupException {
      // Offline or the server is down: try again next time; nothing is lost.
      return const [];
    } finally {
      _syncing = false;
    }
  }

  Future<List<FlightCheck>> _sync(ServerConnection c, ChangeTexts? texts) async {
    final now = _clock();
    final wanted = <String, Activity>{};
    for (final trip in await _trips.watchAll().first) {
      if (trip.archived) continue;
      final today = todayIn(trip.timeZone, now);
      for (final a in await _activities.findByTrip(trip.id)) {
        if (isTrackable(a) && today.daysUntil(a.date) >= -1) wanted[a.id] = a;
      }
    }
    // Drop server bookings this phone made for flights no longer planned.
    for (final l in await _statuses.links()) {
      final a = wanted[l.activityId];
      if (a == null || !_sameFlight(l, a)) {
        try {
          await _server.unwatch(c, l.bookingId);
        } on FlightLookupException catch (e) {
          if (e.failure != FlightLookupFailure.unknown) rethrow;
        }
        await _statuses.deleteLink(l.activityId);
      }
    }
    final remote = {for (final b in await _server.bookings(c)) b.bookingId: b.flight};
    final results = <FlightCheck>[];
    for (final a in wanted.values) {
      final link = await _statuses.link(a.id);
      var flight = link == null ? null : remote[link.bookingId];
      if (flight == null) {
        // New flight, or its booking was removed on the server.
        if (link != null) await _statuses.deleteLink(a.id);
        flight = (await _ensureLink(c, a)).flight;
      }
      if (flight != null) results.add(await _record(a, flight, texts));
    }
    return results;
  }

  bool _sameFlight(FlightLink l, Activity a) => l.code == parseFlightNumber(a.serviceNumber)!.code && l.date == a.date;

  /// The server booking for [a], created if needed. Returns the flight's
  /// state when the booking was just created (it comes with the answer).
  Future<({FlightLink link, RemoteFlight? flight})> _ensureLink(ServerConnection c, Activity a) async {
    final existing = await _statuses.link(a.id);
    if (existing != null && _sameFlight(existing, a)) return (link: existing, flight: null);
    if (existing != null) {
      await _server.unwatch(c, existing.bookingId);
      await _statuses.deleteLink(a.id);
    }
    final trip = await _trips.findById(a.tripId);
    final code = parseFlightNumber(a.serviceNumber)!.code;
    final b = await _server.watch(c, code: code, date: a.date, traveler: trip?.title ?? 'WanderPlan');
    final link = FlightLink(
      activityId: a.id,
      tripId: a.tripId,
      bookingId: b.bookingId,
      flightId: b.flight.flightId,
      code: code,
      date: a.date,
    );
    await _statuses.saveLink(link);
    return (link: link, flight: b.flight);
  }

  /// Saves the server's state and notifies about changes since the last one.
  Future<FlightCheck> _record(Activity a, RemoteFlight remote, ChangeTexts? texts) async {
    final status = remote.status;
    if (status == null) return FlightCheck(a, stale: remote.stale);
    final before = await _statuses.find(a.id);
    final same = before != null && before.fetchedAt == status.fetchedAt;
    final changes = same ? const <FlightChange>[] : flightChanges(before?.flightDate == status.flightDate ? before : null, status);
    if (!same) await _statuses.save(a.id, a.tripId, status);
    if (changes.isNotEmpty && texts != null) {
      try {
        await _notifications.showNow(
          Reminder(
            id: BookingReminderService.reminderId('flight:${a.id}'),
            tripId: a.tripId,
            at: _clock().toUtc(),
            title: texts.title(a),
            body: texts.body(a, changes),
          ),
        );
      } catch (_) {
        // The change is saved and shown in the app even if the OS refuses.
      }
    }
    return FlightCheck(a, status: status, changes: changes, stale: remote.stale);
  }
}
