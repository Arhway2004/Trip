import 'package:wanderplan/shared/domain/local_date.dart';

/// Live state of a flight as reported by a flight-data provider.
enum FlightPhase { scheduled, active, landed, cancelled, incident, diverted, unknown }

/// A time as shown at the airport ("2026-12-12T15:55"), without converting
/// zones: providers report local airport time, and it is shown as such.
class AirportTime {
  const AirportTime(this.date, this.minute);
  final LocalDate date;
  final int minute;

  /// Reads the date and clock time of an ISO string, ignoring any offset.
  static AirportTime? tryParse(Object? v) {
    final m = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2})').firstMatch('${v ?? ''}');
    final d = m == null ? null : LocalDate.tryParse(m.group(1));
    if (d == null) return null;
    return AirportTime(d, int.parse(m!.group(2)!) * 60 + int.parse(m.group(3)!));
  }

  /// Minutes from [o] to this time (dates included).
  int minutesSince(AirportTime o) => (date.epochDay - o.date.epochDay) * 1440 + minute - o.minute;

  String toIso() => '${date.toIso()}T${formatMinutes(minute)}';

  @override
  bool operator ==(Object other) => other is AirportTime && other.date == date && other.minute == minute;

  @override
  int get hashCode => Object.hash(date, minute);
}

/// One end of a flight.
class FlightEnd {
  const FlightEnd({
    this.airport,
    this.iata,
    this.terminal,
    this.gate,
    this.baggage,
    this.delayMinutes,
    this.scheduled,
    this.estimated,
    this.actual,
  });

  final String? airport;
  final String? iata;
  final String? terminal;
  final String? gate;

  /// Baggage belt (arrival only).
  final String? baggage;
  final int? delayMinutes;
  final AirportTime? scheduled;
  final AirportTime? estimated;
  final AirportTime? actual;

  /// The best current time: actual, else estimated, else scheduled.
  AirportTime? get best => actual ?? estimated ?? scheduled;

  Map<String, Object?> toJson() => {
    'airport': airport,
    'iata': iata,
    'terminal': terminal,
    'gate': gate,
    'baggage': baggage,
    'delay': delayMinutes,
    'scheduled': scheduled?.toIso(),
    'estimated': estimated?.toIso(),
    'actual': actual?.toIso(),
  };

  static FlightEnd fromJson(Map<String, Object?> j) => FlightEnd(
    airport: j['airport'] as String?,
    iata: j['iata'] as String?,
    terminal: j['terminal'] as String?,
    gate: j['gate'] as String?,
    baggage: j['baggage'] as String?,
    delayMinutes: (j['delay'] as num?)?.toInt(),
    scheduled: AirportTime.tryParse(j['scheduled']),
    estimated: AirportTime.tryParse(j['estimated']),
    actual: AirportTime.tryParse(j['actual']),
  );
}

/// A snapshot of one flight on one date, as the provider reported it.
class FlightStatus {
  const FlightStatus({
    required this.flightIata,
    required this.flightDate,
    required this.phase,
    required this.departure,
    required this.arrival,
    required this.fetchedAt,
    this.airline,
    this.source = 'aviationstack',
  });

  final String flightIata;

  /// Departure date at the departure airport.
  final LocalDate flightDate;
  final FlightPhase phase;
  final FlightEnd departure;
  final FlightEnd arrival;
  final String? airline;

  /// When the app received it (UTC).
  final DateTime fetchedAt;
  final String source;

  bool get isFinal => phase == FlightPhase.landed || phase == FlightPhase.cancelled || phase == FlightPhase.diverted;

  Map<String, Object?> toJson() => {
    'flight': flightIata,
    'date': flightDate.toIso(),
    'phase': phase.name,
    'airline': airline,
    'departure': departure.toJson(),
    'arrival': arrival.toJson(),
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'source': source,
  };

  static FlightStatus? fromJson(Map<String, Object?> j) {
    final date = LocalDate.tryParse(j['date'] as String?);
    final fetched = DateTime.tryParse('${j['fetchedAt']}');
    if (date == null || fetched == null) return null;
    return FlightStatus(
      flightIata: '${j['flight']}',
      flightDate: date,
      phase: FlightPhase.values.where((p) => p.name == j['phase']).firstOrNull ?? FlightPhase.unknown,
      airline: j['airline'] as String?,
      departure: FlightEnd.fromJson((j['departure'] as Map?)?.cast<String, Object?>() ?? const {}),
      arrival: FlightEnd.fromJson((j['arrival'] as Map?)?.cast<String, Object?>() ?? const {}),
      fetchedAt: fetched.toUtc(),
      source: '${j['source'] ?? 'aviationstack'}',
    );
  }
}

/// What changed between two snapshots of the same flight.
enum FlightChangeKind {
  status,
  departureTime,
  arrivalTime,
  departureTerminal,
  departureGate,
  arrivalTerminal,
  arrivalGate,
  baggageBelt,
}

class FlightChange {
  const FlightChange(this.kind, this.from, this.to);
  final FlightChangeKind kind;
  final String? from;
  final String? to;
}

/// Time changes smaller than this aren't worth a notification.
const significantTimeChangeMinutes = 10;

/// Changes the traveller should hear about. Without an earlier snapshot only
/// bad news is reported (cancelled/diverted or a significant delay).
List<FlightChange> flightChanges(FlightStatus? before, FlightStatus now) {
  final changes = <FlightChange>[];
  if (before == null) {
    if (now.phase == FlightPhase.cancelled || now.phase == FlightPhase.diverted) {
      changes.add(FlightChange(FlightChangeKind.status, null, now.phase.name));
    }
    final dep = now.departure;
    if (dep.scheduled != null && dep.best != null && dep.best!.minutesSince(dep.scheduled!) >= significantTimeChangeMinutes) {
      changes.add(FlightChange(FlightChangeKind.departureTime, dep.scheduled!.toIso(), dep.best!.toIso()));
    }
    return changes;
  }
  if (before.phase != now.phase) changes.add(FlightChange(FlightChangeKind.status, before.phase.name, now.phase.name));

  void time(FlightChangeKind k, AirportTime? a, AirportTime? b) {
    if (a == null || b == null) return;
    if (b.minutesSince(a).abs() >= significantTimeChangeMinutes) changes.add(FlightChange(k, a.toIso(), b.toIso()));
  }

  void text(FlightChangeKind k, String? a, String? b) {
    final x = a?.trim(), y = b?.trim();
    if ((y ?? '').isEmpty || x == y) return;
    changes.add(FlightChange(k, (x ?? '').isEmpty ? null : x, y));
  }

  time(FlightChangeKind.departureTime, before.departure.best, now.departure.best);
  time(FlightChangeKind.arrivalTime, before.arrival.best, now.arrival.best);
  text(FlightChangeKind.departureTerminal, before.departure.terminal, now.departure.terminal);
  text(FlightChangeKind.departureGate, before.departure.gate, now.departure.gate);
  text(FlightChangeKind.arrivalTerminal, before.arrival.terminal, now.arrival.terminal);
  text(FlightChangeKind.arrivalGate, before.arrival.gate, now.arrival.gate);
  text(FlightChangeKind.baggageBelt, before.arrival.baggage, now.arrival.baggage);
  return changes;
}

/// A flight number as written ("8L 818", "mu5103", "CES5103") → the code to
/// query: IATA (2 letters/digits + number) or ICAO (3 letters + number).
({String code, bool icao})? parseFlightNumber(String? raw) {
  final s = (raw ?? '').toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
  final iata = RegExp(r'^([A-Z0-9]{2})(\d{1,4}[A-Z]?)$').firstMatch(s);
  if (iata != null && RegExp('[A-Z]').hasMatch(iata.group(1)!)) return (code: s, icao: false);
  if (RegExp(r'^[A-Z]{3}\d{1,4}[A-Z]?$').hasMatch(s)) return (code: s, icao: true);
  return null;
}
