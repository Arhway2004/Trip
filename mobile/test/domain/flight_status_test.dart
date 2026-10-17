import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_tracking.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

const dec12 = LocalDate(2026, 12, 12);
final _t = DateTime.utc(2026, 12, 1);

/// The server's `FlightStatus` for MU5103 KMG → XMN (airport wall-clock times).
Map<String, Object?> answer({String phase = 'scheduled', String? depEstimated, String? gate, int? delay, DateTime? at}) => {
  'flight': 'MU5103',
  'date': '2026-12-12',
  'phase': phase,
  'airline': 'China Eastern Airlines',
  'departure': {
    'airport': 'Kunming Changshui International',
    'iata': 'KMG',
    'terminal': '1',
    'gate': ?gate,
    'delay': ?delay,
    'scheduled': '2026-12-12T15:55',
    'estimated': depEstimated ?? '2026-12-12T15:55',
  },
  'arrival': {'airport': 'Xiamen Gaoqi International', 'iata': 'XMN', 'terminal': '3', 'scheduled': '2026-12-12T18:25'},
  'fetchedAt': (at ?? _t).toIso8601String(),
  'provider': 'aviationstack',
};

FlightStatus parse(Map<String, Object?> j) => FlightStatus.fromJson({...j, 'source': j['provider']})!;

Activity flight({String? number = 'MU 5103', BookingStatus status = BookingStatus.booked, ActivityKind kind = ActivityKind.flight}) =>
    Activity(
      id: 'f1',
      tripId: 't',
      title: 'KMG → XMN',
      kind: kind,
      date: dec12,
      serviceNumber: number,
      bookingStatus: status,
      createdAt: _t,
      updatedAt: _t,
    );

void main() {
  test('flight numbers: IATA with or without spaces, ICAO, and junk', () {
    expect(parseFlightNumber('mu 5103'), (code: 'MU5103', icao: false));
    expect(parseFlightNumber('8L-818'), (code: '8L818', icao: false));
    expect(parseFlightNumber('CES5103'), (code: 'CES5103', icao: true));
    expect(parseFlightNumber('G1 train'), isNull);
    expect(parseFlightNumber(null), isNull);
  });

  test('only planned flights with a number are followed', () {
    expect(isTrackable(flight()), isTrue);
    expect(isTrackable(flight(number: null)), isFalse);
    expect(isTrackable(flight(status: BookingStatus.cancelled)), isFalse);
    expect(isTrackable(flight(kind: ActivityKind.train, number: 'G1')), isFalse);
  });

  test('server statuses are read as local airport times and round-trip through storage', () {
    final s = parse(answer(gate: 'B12'));
    expect((s.flightIata, s.flightDate, s.phase, s.airline, s.source), ('MU5103', dec12, FlightPhase.scheduled, 'China Eastern Airlines', 'aviationstack'));
    expect(s.departure.scheduled, const AirportTime(dec12, 15 * 60 + 55));
    expect((s.departure.gate, s.arrival.terminal, s.arrival.baggage), ('B12', '3', null));
    final back = FlightStatus.fromJson(s.toJson())!;
    expect((back.departure.best, back.arrival.iata, back.phase), (s.departure.best, 'XMN', FlightPhase.scheduled));
  });

  test('changes: delay, gate, status; no noise for small shifts or first sight of a normal flight', () {
    final before = parse(answer());
    expect(flightChanges(null, before), isEmpty);
    final small = parse(answer(depEstimated: '2026-12-12T16:00'));
    expect(flightChanges(before, small), isEmpty);
    final later = parse(answer(depEstimated: '2026-12-12T16:40', gate: 'B12', delay: 45));
    final c = flightChanges(before, later);
    expect(c.map((x) => x.kind), [FlightChangeKind.departureTime, FlightChangeKind.departureGate]);
    expect((c.first.from, c.first.to), ('2026-12-12T15:55', '2026-12-12T16:40'));
    final cancelled = parse(answer(phase: 'cancelled'));
    expect(flightChanges(null, cancelled).single.kind, FlightChangeKind.status);
    expect(flightChanges(before, cancelled).first.to, 'cancelled');
  });
}
