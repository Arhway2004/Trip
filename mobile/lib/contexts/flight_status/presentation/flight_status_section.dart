import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/contexts/flight_status/domain/flight_tracking.dart';
import 'package:wanderplan/contexts/flight_status/presentation/flight_status_l10n.dart';
import 'package:wanderplan/contexts/flight_status/presentation/flight_status_providers.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

/// Live status of one planned flight (under its booking row).
class FlightStatusSection extends ConsumerStatefulWidget {
  const FlightStatusSection({super.key, required this.activity});
  final Activity activity;

  @override
  ConsumerState<FlightStatusSection> createState() => _FlightStatusSectionState();
}

class _FlightStatusSectionState extends ConsumerState<FlightStatusSection> {
  bool _checking = false;

  Future<void> _checkNow() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checking = true);
    try {
      final r = await ref
          .read(flightUpdateServiceProvider)
          .checkActivity(widget.activity.id, texts: flightChangeTexts(l));
      final msg = r.failure != null
          ? flightFailureText(l, r.failure!)
          : r.noDataYet
          ? l.flightNoDataYet
          : r.changes.isEmpty
          ? l.flightNoChanges
          : r.changes.map((c) => flightChangeText(l, c)).join(' · ');
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final a = widget.activity;
    final small = TextStyle(fontSize: 12, color: c.ink2);

    if (!isTrackable(a)) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(l.flightNeedsNumber, style: TextStyle(fontSize: 12, color: c.ink3)),
      );
    }
    final available = ref.watch(flightUpdateServiceProvider).available;
    final status = ref.watch(flightStatusesProvider(a.tripId)).value?[a.id];
    final checkButton = TextButton.icon(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      icon: _checking
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.sync, size: 18),
      label: Text(l.flightCheckNow),
      onPressed: _checking ? null : _checkNow,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Badge2(label: status.phase.label(l), tone: status.phase.tone, icon: Icons.flight),
                if ((status.departure.delayMinutes ?? 0) >= significantTimeChangeMinutes)
                  Badge2(label: l.flightDelayed(status.departure.delayMinutes!), tone: Tone.warn),
              ],
            ),
            const SizedBox(height: 4),
            Text(_endLine(l.flightDep, status.departure), style: small),
            Text(_endLine(l.flightArr, status.arrival), style: small),
            Text(
              l.flightChecked(DateFormat.MMMd(context.localeTag).add_Hm().format(status.fetchedAt.toLocal())),
              style: TextStyle(fontSize: 11, color: c.ink3),
            ),
          ],
          if (available)
            checkButton
          else
            Text(l.flightNotConnected, style: TextStyle(fontSize: 12, color: c.ink3)),
        ],
      ),
    );
  }

  String _endLine(String label, FlightEnd e) {
    final l = context.l10n;
    final planned = e.scheduled == null ? null : airportTimeText(e.scheduled!);
    final best = e.best == null ? null : airportTimeText(e.best!);
    return [
      '$label ${e.iata ?? ''}'.trim(),
      if (best != null) best == planned || planned == null ? best : '$planned → $best',
      if (e.terminal != null) l.flightTerminal(e.terminal!),
      if (e.gate != null) l.flightGate(e.gate!),
      if (e.baggage != null) l.flightBelt(e.baggage!),
    ].join(' · ');
  }
}
