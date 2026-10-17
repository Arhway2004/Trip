import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_update_service.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../domain/flight_status_test.dart' show answer, parse;
import '../helpers.dart';

void main() {
  setUpAll(initTestEnvironment);
  // Dec 12, 2026, 10:00 in Shanghai.
  var now = DateTime.utc(2026, 12, 12, 2);

  late TestDevice d;
  late FakeFlightServer server;
  late MemorySecretStore secrets;
  late FakeReminderScheduler notifications;
  setUp(() async {
    now = DateTime.utc(2026, 12, 12, 2);
    server = FakeFlightServer();
    secrets = MemorySecretStore();
    notifications = FakeReminderScheduler();
    d = await TestDevice.create(
      clock: () => now,
      flights: server,
      secrets: secrets,
      reminders: notifications,
      serverUrl: 'http://192.168.1.20:8080',
    );
  });
  tearDown(() => d.dispose());

  final texts = (title: (Activity a) => 'Update ${a.serviceNumber}', body: (Activity a, List<FlightChange> c) => c.map((x) => x.kind.name).join(','));

  Future<(String, String)> tripWithFlight({LocalDate date = const LocalDate(2026, 12, 12)}) async {
    final id = await d.app.trips.createTrip(TripDraft(title: 'Yunnan', timeZone: 'Asia/Shanghai'));
    final f = await d.app.itinerary.addActivity(
      id,
      ActivityDraft(title: 'KMG → XMN', kind: ActivityKind.flight, date: date, serviceNumber: 'MU5103', bookingStatus: BookingStatus.booked),
    );
    return (id, f);
  }

  test('server addresses are normalised; bad ones are refused', () {
    expect(FlightUpdateService.parseServerUrl(' 192.168.1.20:8080/ ').toString(), 'http://192.168.1.20:8080');
    expect(FlightUpdateService.parseServerUrl('https://api.example.com').toString(), 'https://api.example.com');
    expect(FlightUpdateService.parseServerUrl('ftp://x'), isNull);
    expect(FlightUpdateService.parseServerUrl(''), isNull);
  });

  test('the app signs in by itself once, keeps the token in the keychain and removes any old provider key', () async {
    final s = d.app.flightUpdates;
    secrets.values[FlightUpdateService.legacyProviderKey] = 'old-key-from-earlier-version';
    expect(s.available, isTrue);

    expect(await s.checkConnection(), 'demo@wanderplan.test');
    expect(server.calls, ['sign-in 192.168.1.20', 'me']);
    expect(secrets.values[FlightUpdateService.tokenKey], 'token-0');
    expect(secrets.values.containsKey(FlightUpdateService.legacyProviderKey), isFalse);

    await s.checkConnection();
    expect(server.signIns, 1, reason: 'the saved token is reused');
  });

  test('a token the server no longer accepts is replaced by signing in again', () async {
    await d.app.flightUpdates.checkConnection();
    server.rejected.add('token-0');
    expect(await d.app.flightUpdates.checkConnection(), 'demo@wanderplan.test');
    expect(secrets.values[FlightUpdateService.tokenKey], 'token-1');
  });

  test('without a server in this build nothing is sent', () async {
    await tripWithFlight();
    final local = await TestDevice.create(flights: server, secrets: MemorySecretStore());
    addTearDown(local.dispose);
    expect(local.app.flightUpdates.available, isFalse);
    expect(await local.app.flightUpdates.sync(), isEmpty);
    await expectLater(local.app.flightUpdates.checkConnection(), throwsA(isA<FlightLookupException>()));
    expect(server.calls, isEmpty);
  });

  test('sync books each planned flight once, reads the server state and announces changes once', () async {
    final (tripId, flightId) = await tripWithFlight();

    // The server hasn't checked it yet.
    expect((await d.app.flightUpdates.sync(texts: texts)).single.noDataYet, isTrue);
    expect(server.bookings_.values.single, ('MU5103', const LocalDate(2026, 12, 12)));

    server.statuses['MU5103'] = parse(answer(at: now));
    final first = await d.app.flightUpdates.sync(texts: texts);
    expect(first.single.changes, isEmpty);
    expect(server.bookings_, hasLength(1), reason: 'no second booking');

    // Later the server's scheduled check finds a delay and the gate.
    now = now.add(const Duration(hours: 2));
    server.statuses['MU5103'] = parse(answer(depEstimated: '2026-12-12T16:40', gate: 'B12', delay: 45, at: now));
    final second = await d.app.flightUpdates.sync(texts: texts);
    expect(second.single.changes.map((c) => c.kind), [FlightChangeKind.departureTime, FlightChangeKind.departureGate]);
    expect(notifications.shown.single.title, 'Update MU5103');
    expect(notifications.shown.single.body, 'departureTime,departureGate');

    // Same server answer again: nothing new to announce.
    expect((await d.app.flightUpdates.sync(texts: texts)).single.changes, isEmpty);
    expect(notifications.shown, hasLength(1));

    final stored = await d.app.flightUpdates.watchStatuses(tripId).first;
    expect(stored[flightId]!.departure.gate, 'B12');
    expect(server.tokens, {'token-0'}, reason: 'one sign-in, reused');
  });

  test('a changed or removed flight drops its server booking', () async {
    final (_, flightId) = await tripWithFlight();
    await d.app.flightUpdates.sync();
    final first = server.bookings_.keys.single;

    await d.app.itinerary.updateActivity(
      flightId,
      ActivityDraft(title: 'KMG → XMN', kind: ActivityKind.flight, date: const LocalDate(2026, 12, 12), serviceNumber: 'MU5104', bookingStatus: BookingStatus.booked),
    );
    await d.app.flightUpdates.sync();
    expect(server.bookings_.keys, isNot(contains(first)));
    expect(server.bookings_.values.single.$1, 'MU5104');

    await d.app.itinerary.deleteActivity(flightId);
    await d.app.flightUpdates.sync();
    expect(server.bookings_, isEmpty);
  });

  test('"Check now" asks the server for a refresh; offline or no data yet is explained', () async {
    final (_, flightId) = await tripWithFlight(date: const LocalDate(2027, 1, 20));
    final r = await d.app.flightUpdates.checkActivity(flightId, texts: texts);
    expect(r.noDataYet, isTrue);
    expect(server.calls.last, startsWith('refresh f-MU5103-2027-01-20'));

    server.failure = FlightLookupFailure.network;
    expect((await d.app.flightUpdates.checkActivity(flightId)).failure, FlightLookupFailure.network);
    expect(await d.app.flightUpdates.sync(), isEmpty, reason: 'offline sync fails quietly');
    expect(server.signIns, 1);
  });
}
