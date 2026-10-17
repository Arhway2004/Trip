import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:wanderplan/app/service_registry.dart';
import 'package:wanderplan/contexts/budget/application/rate_source.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/application/secret_store.dart';
import 'package:wanderplan/contexts/itinerary/application/booking_reminders.dart';
import 'package:wanderplan/contexts/places/application/location_link_service.dart';
import 'package:wanderplan/contexts/places/application/location_service.dart';
import 'package:wanderplan/contexts/places/application/place_search.dart';
import 'package:wanderplan/contexts/places/application/route_service.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';
import 'package:wanderplan/shared/infrastructure/media/media_storage.dart';

bool _initialized = false;

Future<void> initTestEnvironment() async {
  if (_initialized) return;
  _initialized = true;
  tzdata.initializeTimeZones();
  await initializeDateFormatting();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

Future<MediaStorage> tempMedia() async => MediaStorage(await Directory.systemTemp.createTemp('wanderplan_media_'));

/// One simulated device: database, media folder and all application services.
class TestDevice {
  TestDevice._(this.db, this.media, this.app);

  static Future<TestDevice> create({
    AppDatabase? db,
    MediaStorage? media,
    DateTime Function()? clock,
    RateSource? rates,
    PlaceSearch? places,
    RouteService? routes,
    LocationService? location,
    LinkExpander? links,
    ReminderScheduler? reminders,
    FlightServer? flights,
    SecretStore? secrets,
    String serverUrl = '',
  }) async {
    final d = db ?? memoryDb();
    final m = media ?? await tempMedia();
    final tmp = await Directory.systemTemp.createTemp('wanderplan_tmp_');
    return TestDevice._(
      d,
      m,
      ServiceRegistry.create(
        db: d,
        media: m,
        tempDir: () async => tmp,
        clock: clock ?? DateTime.now,
        // Tests never touch the network.
        rateSource: rates ?? FakeRateSource(const {}),
        placeSearch: places ?? FakePlaceSearch(),
        routeService: routes ?? FakeRouteService(),
        locationService: location ?? const FakeLocationService(null),
        linkExpander: links ?? const OfflineLinkExpander(),
        reminderScheduler: reminders ?? FakeReminderScheduler(),
        flightServer: flights ?? FakeFlightServer(),
        secretStore: secrets ?? MemorySecretStore(),
        serverUrl: serverUrl,
      ),
    );
  }

  final AppDatabase db;
  final MediaStorage media;
  final ServiceRegistry app;

  Future<void> dispose() async {
    await db.close();
    if (await media.root.exists()) await media.root.delete(recursive: true);
  }
}

/// Writes a small fake image file and returns its path.
Future<String> fakeImage([String name = 'photo.jpg']) async {
  final dir = await Directory.systemTemp.createTemp('wanderplan_src_');
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(List.generate(64, (i) => i));
  return f.path;
}

/// Offline stand-in for the live rate API: "1 unit of X = rate base".
class FakeRateSource implements RateSource {
  FakeRateSource(this.rates);
  final Map<String, double> rates;
  final calls = <(String, Set<String>)>[];

  @override
  String get name => 'test-rates';

  @override
  Future<Map<String, double>> fetchRates({required String base, required Set<String> currencies}) async {
    calls.add((base, currencies));
    return {
      for (final c in currencies)
        if (rates[c] != null) c: rates[c]!,
    };
  }
}

/// Offline place search returning canned results.
class FakePlaceSearch implements PlaceSearch {
  FakePlaceSearch({this.results = const [], this.nearbyResults = const {}, this.byQuery = const {}});
  final List<PlaceResult> results;

  /// Answers for specific queries; anything else gets [results].
  final Map<String, List<PlaceResult>> byQuery;
  final Map<PlaceCategory, List<PlaceResult>> nearbyResults;
  final queries = <String>[];

  @override
  String get attribution => 'test';

  @override
  Future<List<PlaceResult>> search(String query, {String? languageCode, GeoPoint? near, int limit = 8}) async {
    queries.add(query);
    return byQuery[query] ?? results;
  }

  @override
  Future<List<PlaceResult>> nearby(
    GeoPoint center,
    PlaceCategory category, {
    String? languageCode,
    int? radiusMeters,
    int limit = 30,
  }) async => nearbyResults[category] ?? const [];
}

/// Offline router: a straight "road" through the waypoints, or a failure.
class FakeRouteService implements RouteService {
  FakeRouteService({this.fail = false});
  final bool fail;
  final calls = <(List<GeoPoint>, TravelMode)>[];

  @override
  String get attribution => 'test-routing';

  @override
  Future<TravelMatrix> matrix(List<GeoPoint> points, TravelMode mode) async {
    if (fail) throw const RoutingException('offline');
    return TravelMatrix(
      [
        for (final a in points) [for (final b in points) a.distanceKmTo(b) * 720.0],
      ],
      source: 'routing:test',
      estimated: false,
    );
  }

  @override
  Future<RouteResult> route(List<GeoPoint> waypoints, TravelMode mode) async {
    calls.add((waypoints, mode));
    if (fail) throw const RoutingException('offline');
    var km = 0.0;
    for (var i = 0; i + 1 < waypoints.length; i++) {
      km += waypoints[i].distanceKmTo(waypoints[i + 1]);
    }
    return RouteResult(
      geometry: waypoints,
      distanceMeters: km * 1000,
      durationSeconds: km * 720,
      mode: mode,
      source: 'routing:test',
    );
  }
}

class FakeLocationService implements LocationService {
  const FakeLocationService(this.point);
  final GeoPoint? point;

  @override
  Future<GeoPoint> current() async => point ?? (throw const LocationException(LocationFailure.denied));
}

/// Short links can't be expanded offline.
class OfflineLinkExpander implements LinkExpander {
  const OfflineLinkExpander();
  @override
  Future<Uri> expand(Uri shortLink) async => throw Exception('offline');
}

/// Records reminders instead of showing notifications.
class FakeReminderScheduler implements ReminderScheduler {
  final scheduled = <int, Reminder>{};
  bool granted = true;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> schedule(Reminder r) async => scheduled[r.id] = r;

  final shown = <Reminder>[];

  @override
  Future<void> showNow(Reminder r) async => shown.add(r);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<List<int>> scheduledFor(String tripId) async => [
    for (final r in scheduled.values)
      if (r.tripId == tripId) r.id,
  ];
}

/// In-memory stand-in for the OS keychain.
class MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// A WanderPlan server in memory: bookings per flight, the server's latest
/// status per flight code (what its scheduled checks found), or a failure.
class FakeFlightServer implements FlightServer {
  FakeFlightServer({Map<String, FlightStatus>? statuses, this.failure, this.user = 'demo@wanderplan.test'})
    : statuses = statuses ?? {};

  /// What the server knows about each flight code (null = not checked yet).
  final Map<String, FlightStatus> statuses;
  FlightLookupFailure? failure;
  final String user;

  /// bookingId → (code, date).
  final bookings_ = <String, (String, LocalDate)>{};
  final calls = <String>[];
  final tokens = <String>{};
  var _next = 0;

  /// Tokens handed out by [signIn]; tokens in [rejected] are refused.
  var signIns = 0;
  final rejected = <String>{};

  RemoteFlight _flight(String code, LocalDate date) =>
      RemoteFlight(flightId: 'f-$code-${date.toIso()}', status: statuses[code], stale: false, lastCheckedAt: null);

  void _call(ServerConnection c, String what) {
    calls.add(what);
    tokens.add(c.token);
    if (failure != null) throw FlightLookupException(failure!);
    if (rejected.contains(c.token)) throw const FlightLookupException(FlightLookupFailure.signInRejected);
  }

  @override
  Future<String> signIn(Uri baseUrl) async {
    calls.add('sign-in ${baseUrl.host}');
    if (failure != null) throw FlightLookupException(failure!);
    return 'token-${signIns++}';
  }

  @override
  Future<String> whoAmI(ServerConnection c) async {
    _call(c, 'me');
    return user;
  }

  @override
  Future<RemoteBooking> watch(ServerConnection c, {required String code, required LocalDate date, required String traveler}) async {
    _call(c, 'watch $code ${date.toIso()}');
    final id = 'b${_next++}';
    bookings_[id] = (code, date);
    return RemoteBooking(bookingId: id, flight: _flight(code, date));
  }

  @override
  Future<void> unwatch(ServerConnection c, String bookingId) async {
    _call(c, 'unwatch $bookingId');
    bookings_.remove(bookingId);
  }

  @override
  Future<List<RemoteBooking>> bookings(ServerConnection c) async {
    _call(c, 'bookings');
    return [for (final e in bookings_.entries) RemoteBooking(bookingId: e.key, flight: _flight(e.value.$1, e.value.$2))];
  }

  @override
  Future<RemoteFlight> refresh(ServerConnection c, String flightId) async {
    _call(c, 'refresh $flightId');
    final e = bookings_.values.firstWhere((v) => 'f-${v.$1}-${v.$2.toIso()}' == flightId);
    return _flight(e.$1, e.$2);
  }
}
