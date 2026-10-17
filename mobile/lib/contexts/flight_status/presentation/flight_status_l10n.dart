import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_update_service.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

extension FlightPhaseUi on FlightPhase {
  String label(AppLocalizations l) => switch (this) {
    FlightPhase.scheduled => l.flightScheduled,
    FlightPhase.active => l.flightInAir,
    FlightPhase.landed => l.flightLanded,
    FlightPhase.cancelled => l.flightCancelled,
    FlightPhase.incident => l.flightIncident,
    FlightPhase.diverted => l.flightDiverted,
    FlightPhase.unknown => l.flightStatusUnknown,
  };

  Tone get tone => switch (this) {
    FlightPhase.cancelled || FlightPhase.incident || FlightPhase.diverted => Tone.bad,
    FlightPhase.landed => Tone.good,
    FlightPhase.active => Tone.info,
    _ => Tone.neutral,
  };
}

String flightFailureText(AppLocalizations l, FlightLookupFailure f) => switch (f) {
  FlightLookupFailure.notConnected => l.flightNotConnected,
  FlightLookupFailure.signInRejected => l.flightSignInRejected,
  FlightLookupFailure.serverNotConfigured => l.flightServerNoKey,
  FlightLookupFailure.quotaReached => l.flightQuotaReached,
  FlightLookupFailure.network => l.flightNetwork,
  FlightLookupFailure.unknown => l.flightUnknownError,
};

String airportTimeText(AirportTime t) => formatMinutes(t.minute);

String _value(String? iso) {
  final t = AirportTime.tryParse(iso);
  return t != null ? airportTimeText(t) : (iso ?? '—');
}

String flightChangeText(AppLocalizations l, FlightChange c) {
  final from = c.kind == FlightChangeKind.status ? null : (c.from == null ? null : _value(c.from));
  final to = c.kind == FlightChangeKind.status ? null : _value(c.to);
  return switch (c.kind) {
    FlightChangeKind.status => l.flightChangeStatus(
      FlightPhase.values.where((p) => p.name == c.to).firstOrNull?.label(l) ?? '${c.to}',
    ),
    FlightChangeKind.departureTime => l.flightChangeDeparture(from ?? '—', to!),
    FlightChangeKind.arrivalTime => l.flightChangeArrival(from ?? '—', to!),
    FlightChangeKind.departureTerminal => l.flightChangeDepTerminal(c.to ?? ''),
    FlightChangeKind.departureGate => l.flightChangeDepGate(c.to ?? ''),
    FlightChangeKind.arrivalTerminal => l.flightChangeArrTerminal(c.to ?? ''),
    FlightChangeKind.arrivalGate => l.flightChangeArrGate(c.to ?? ''),
    FlightChangeKind.baggageBelt => l.flightChangeBaggage(c.to ?? ''),
  };
}

/// Notification texts in the app's language.
ChangeTexts flightChangeTexts(AppLocalizations l) => (
  title: (Activity a) => l.flightNotifyTitle(a.serviceNumber ?? a.title),
  body: (Activity a, List<FlightChange> changes) => changes.map((c) => flightChangeText(l, c)).join(' · '),
);
