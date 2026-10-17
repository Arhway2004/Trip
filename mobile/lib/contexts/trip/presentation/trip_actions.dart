import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/contexts/trip/presentation/widgets/trip_card.dart';

/// Shared handlers for trip actions offered on cards and the dashboard.
Future<void> runTripAction(BuildContext context, WidgetRef ref, TripSummary trip, TripCardAction action) async {
  final l = context.l10n;
  final repo = ref.read(tripServiceProvider);
  final messenger = ScaffoldMessenger.of(context);

  switch (action) {
    case TripCardAction.edit:
      context.push(Routes.editTrip(trip.id));
    case TripCardAction.banner:
      context.push(Routes.banner(trip.id));
    case TripCardAction.duplicate:
      await repo.duplicateTrip(trip.id, titleSuffix: l.duplicateSuffix);
      messenger.showSnackBar(SnackBar(content: Text(l.tripDuplicated)));
    case TripCardAction.archive:
      final archive = !trip.trip.archived;
      await repo.setArchived(trip.id, archive);
      messenger.showSnackBar(SnackBar(content: Text(archive ? l.tripArchived : l.tripUnarchived)));
    case TripCardAction.delete:
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.deleteTripTitle),
          content: Text(l.deleteTripBody(trip.trip.title)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.actionCancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.actionDelete),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (context.mounted && GoRouterState.of(context).uri.path.startsWith(Routes.trip(trip.id))) {
        context.go(Routes.trips);
      }
      await repo.deleteTrip(trip.id);
      messenger.showSnackBar(SnackBar(content: Text(l.tripDeleted)));
  }
}
