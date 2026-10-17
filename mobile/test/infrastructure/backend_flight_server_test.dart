import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/contexts/flight_status/infrastructure/backend_flight_server.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

import '../domain/flight_status_test.dart' show answer;

/// Plays the WanderPlan server: canned status + JSON per request (no network).
class _FakeHttp implements HttpClientAdapter {
  _FakeHttp(this.respond);
  final (int, Object) Function(RequestOptions o) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o);
    final (code, json) = respond(o);
    return ResponseBody.fromString(jsonEncode(json), code, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final c = ServerConnection(baseUrl: Uri.parse('http://192.168.1.20:8080/'), token: 'test-token');
  final flight = {
    'id': 'f-1',
    'flight': 'MU5103',
    'date': '2026-12-12',
    'status': answer(gate: 'B12', at: DateTime.utc(2026, 12, 12, 2)),
    'lastCheckedAt': '2026-12-12T02:00:00Z',
    'stale': true,
    'changes': <Object>[],
  };

  test('problem responses map to what the traveller can do about them', () {
    expect(BackendFlightServer.failureFor(401, 'auth.invalid_token'), FlightLookupFailure.signInRejected);
    expect(BackendFlightServer.failureFor(503, 'flight.not_configured'), FlightLookupFailure.serverNotConfigured);
    expect(BackendFlightServer.failureFor(503, 'flight.provider_config'), FlightLookupFailure.serverNotConfigured);
    expect(BackendFlightServer.failureFor(503, 'flight.provider_quota'), FlightLookupFailure.quotaReached);
    expect(BackendFlightServer.failureFor(502, ''), FlightLookupFailure.network);
    expect(BackendFlightServer.failureFor(404, 'not_found'), FlightLookupFailure.unknown);
  });

  test('a monitored flight is read with its status, stale flag and check time', () {
    final f = BackendFlightServer.parseFlight(flight);
    expect((f.flightId, f.stale, f.lastCheckedAt), ('f-1', true, DateTime.utc(2026, 12, 12, 2)));
    expect((f.status!.flightIata, f.status!.departure.gate, f.status!.phase, f.status!.source), ('MU5103', 'B12', FlightPhase.scheduled, 'aviationstack'));
    expect(BackendFlightServer.parseFlight({...flight, 'status': null}).status, isNull);
  });

  test('watch posts one segment with the bearer token; only the server is called', () async {
    final http = _FakeHttp((o) => (201, {'id': 'b-1', 'traveler': 'Yunnan', 'flights': [flight]}));
    final s = BackendFlightServer(Dio()..httpClientAdapter = http);
    final b = await s.watch(c, code: 'MU5103', date: const LocalDate(2026, 12, 12), traveler: 'Yunnan');
    expect((b.bookingId, b.flight.flightId), ('b-1', 'f-1'));
    final r = http.requests.single;
    expect((r.method, r.uri.toString()), ('POST', 'http://192.168.1.20:8080/v1/bookings'));
    expect(r.headers['Authorization'], 'Bearer test-token');
    expect(r.data, {
      'traveler': 'Yunnan',
      'segments': [
        {'flight': 'MU5103', 'date': '2026-12-12'},
      ],
    });
  });

  test('errors come back as failures; a booking already gone is fine to unwatch', () async {
    final http = _FakeHttp(
      (o) => o.method == 'DELETE'
          ? (404, {'code': 'not_found'})
          : (503, {'code': 'flight.not_configured', 'title': 'Flight monitoring is not configured'}),
    );
    final s = BackendFlightServer(Dio()..httpClientAdapter = http);
    await expectLater(
      s.refresh(c, 'f-1'),
      throwsA(isA<FlightLookupException>().having((e) => e.failure, 'failure', FlightLookupFailure.serverNotConfigured)),
    );
    await s.unwatch(c, 'b-1');
    expect(http.requests.map((r) => '${r.method} ${r.uri.path}'), ['POST /v1/flights/f-1/refresh', 'DELETE /v1/bookings/b-1']);
  });

  test('sign-in asks the server for the demo account without a token', () async {
    final http = _FakeHttp((o) => (200, {'token': 'demo-token', 'email': 'demo@wanderplan.test'}));
    final s = BackendFlightServer(Dio()..httpClientAdapter = http);
    expect(await s.signIn(Uri.parse('http://192.168.1.20:8080')), 'demo-token');
    final r = http.requests.single;
    expect((r.method, r.uri.toString(), r.headers['Authorization']), ('POST', 'http://192.168.1.20:8080/v1/auth/demo', null));

    final prod = BackendFlightServer(Dio()..httpClientAdapter = _FakeHttp((o) => (404, {'code': 'route.not_found'})));
    await expectLater(
      prod.signIn(Uri.parse('https://api.example.com')),
      throwsA(isA<FlightLookupException>().having((e) => e.failure, 'failure', FlightLookupFailure.signInRejected)),
    );
  });
}
