import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/contexts/flight_status/presentation/flight_status_l10n.dart';
import 'package:wanderplan/contexts/flight_status/presentation/flight_status_providers.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

/// Settings → Flight updates: whether live updates work. Nothing to fill in:
/// the server is part of the app and it signs in by itself.
class FlightUpdatesSettingsScreen extends ConsumerWidget {
  const FlightUpdatesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final conn = ref.watch(flightConnectionProvider);

    final Widget status = switch (conn) {
      AsyncData(:final value) when value.user != null => Badge2(
        label: l.flightServerConnectedAs(value.user!),
        tone: Tone.good,
        icon: Icons.check_circle_outline,
      ),
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Badge2(label: l.flightUpdatesOff, tone: Tone.warn, icon: Icons.error_outline),
          const SizedBox(height: 8),
          Text(flightFailureText(l, value.failure!), style: TextStyle(color: c.ink2)),
          if (value.available)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.actionRetry),
                onPressed: () => ref.invalidate(flightConnectionProvider),
              ),
            ),
        ],
      ),
      _ => Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(l.flightServerChecking, style: TextStyle(color: c.ink2)),
        ],
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.flightUpdates)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l.flightServerIntro, style: TextStyle(color: c.ink2)),
          const SizedBox(height: 16),
          SectionCard(title: l.flightServerTitle, icon: Icons.cloud_done_outlined, child: status),
          const SizedBox(height: 12),
          SectionCard(
            title: l.flightPrivacyTitle,
            icon: Icons.privacy_tip_outlined,
            child: Text(l.flightServerPrivacy, style: TextStyle(color: c.ink2)),
          ),
        ],
      ),
    );
  }
}
