import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

/// WanderPlan's backend: `/v1/bookings`, `/v1/flights/{id}/refresh`, `/v1/me`.
/// Only the sign-in token is sent; the flight-data key never leaves the server.
class BackendFlightServer implements FlightServer {
  BackendFlightServer([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  Future<Map<String, dynamic>> _call(
    ServerConnection c,
    String method,
    String path, {
    Object? body,
  }) => _send(c.baseUrl, method, path, token: c.token, body: body);

  Future<Map<String, dynamic>> _send(Uri baseUrl, String method, String path, {String? token, Object? body}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        '${baseUrl.toString().replaceAll(RegExp(r'/+$'), '')}$path',
        data: body,
        options: Options(
          method: method,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
          // Problem bodies carry the error code; read them ourselves.
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      // Debug builds say why (never the token); release builds stay quiet.
      if (kDebugMode) debugPrint('WanderPlan server: $method $path → ${e.type.name}: ${e.error ?? e.message}');
      throw const FlightLookupException(FlightLookupFailure.network);
    }
    final status = res.statusCode ?? 0;
    final data = res.data is Map ? (res.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
    if (status >= 200 && status < 300) return data;
    throw FlightLookupException(failureFor(status, '${data['code'] ?? ''}'));
  }

  /// Maps an HTTP status + problem code (public for tests).
  static FlightLookupFailure failureFor(int status, String code) => switch ((status, code)) {
    (401, _) || (403, _) => FlightLookupFailure.signInRejected,
  // The server doesn't offer the demo sign-in (e.g. production).
  (404, 'route.not_found') => FlightLookupFailure.signInRejected,
    (503, 'flight.not_configured' || 'flight.provider_config') => FlightLookupFailure.serverNotConfigured,
    (503, 'flight.provider_quota') => FlightLookupFailure.quotaReached,
    (503, _) || (502, _) || (504, _) => FlightLookupFailure.network,
    _ => FlightLookupFailure.unknown,
  };

  @override
  Future<String> signIn(Uri baseUrl) async {
    final r = await _send(baseUrl, 'POST', '/v1/auth/demo');
    final token = r['token'];
    if (token is! String || token.isEmpty) throw const FlightLookupException(FlightLookupFailure.unknown);
    return token;
  }

  @override
  Future<String> whoAmI(ServerConnection c) async {
    final me = await _call(c, 'GET', '/v1/me');
    return '${me['email'] ?? me['name'] ?? me['subject'] ?? me['id'] ?? ''}';
  }

  @override
  Future<RemoteBooking> watch(ServerConnection c, {required String code, required LocalDate date, required String traveler}) async {
    final b = await _call(
      c,
      'POST',
      '/v1/bookings',
      body: {
        'traveler': traveler.length > 200 ? traveler.substring(0, 200) : traveler,
        'segments': [
          {'flight': code, 'date': date.toIso()},
        ],
      },
    );
    return parseBooking(b);
  }

  @override
  Future<void> unwatch(ServerConnection c, String bookingId) async {
    try {
      await _call(c, 'DELETE', '/v1/bookings/$bookingId');
    } on FlightLookupException catch (e) {
      if (e.failure != FlightLookupFailure.unknown) rethrow; // 404: already gone
    }
  }

  @override
  Future<List<RemoteBooking>> bookings(ServerConnection c) async {
    final r = await _call(c, 'GET', '/v1/bookings');
    return [for (final b in ((r['items'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>()) parseBooking(b.cast())];
  }

  @override
  Future<RemoteFlight> refresh(ServerConnection c, String flightId) async =>
      parseFlight(await _call(c, 'POST', '/v1/flights/$flightId/refresh'));

  /// Parses a `Booking` (public for tests). Each phone booking has one flight.
  static RemoteBooking parseBooking(Map<String, dynamic> b) {
    final flights = ((b['flights'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>().toList();
    if (flights.isEmpty) throw const FlightLookupException(FlightLookupFailure.unknown);
    return RemoteBooking(bookingId: '${b['id']}', flight: parseFlight(flights.first.cast()));
  }

  /// Parses a `MonitoredFlight` (public for tests).
  static RemoteFlight parseFlight(Map<String, dynamic> f) {
    final st = f['status'];
    return RemoteFlight(
      flightId: '${f['id']}',
      status: st is Map ? FlightStatus.fromJson({...st.cast<String, Object?>(), 'source': st['provider']}) : null,
      stale: f['stale'] == true,
      lastCheckedAt: DateTime.tryParse('${f['lastCheckedAt']}'),
    );
  }
}
