import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/contexts/flight_status/presentation/flight_status_section.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_l10n.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

/// All flights, trains, buses, ferries and hotel stays of a trip in one list.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final acts = ref.watch(tripActivitiesProvider(tripId)).value ?? const <Activity>[];
    final transport = acts.where((a) => a.kind.isTransport && a.kind != ActivityKind.transfer).toList();
    final stays = acts.where((a) => a.kind.isStay).toList();

    Widget addButton(ActivityKind k) => ActionChip(
      avatar: Icon(k.icon, size: 18, color: k.color),
      label: Text(k.label(l)),
      onPressed: () => context.push(Routes.newActivity(tripId, kind: k)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.bookingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in [
                ActivityKind.flight,
                ActivityKind.train,
                ActivityKind.bus,
                ActivityKind.ferry,
                ActivityKind.hotel,
              ])
                addButton(k),
            ],
          ),
          const SizedBox(height: 16),
          if (transport.isEmpty && stays.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.bookingsEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.ink3),
              ),
            ),
          if (transport.isNotEmpty)
            SectionCard(
              title: l.bookingsTransport,
              icon: Icons.flight_takeoff,
              child: Column(
                children: [for (final a in transport) _BookingRow(tripId: tripId, a: a)],
              ),
            ),
          if (stays.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: l.bookingsStays,
              icon: Icons.hotel_outlined,
              child: Column(
                children: [for (final a in stays) _BookingRow(tripId: tripId, a: a)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.tripId, required this.a});
  final String tripId;
  final Activity a;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final route = [a.location.name, a.destination.name].where((s) => s != null && s.isNotEmpty).join(' → ');
    final when = a.kind.isStay
        ? '${formatDate(context, a.date)} → ${formatDate(context, a.lastDate)} · ${l.nightsCount(a.nights.length)}'
        : !a.hasTime
        ? '${formatDate(context, a.date)} · ${l.timeTbd}'
        : '${formatDate(context, a.date)} ${formatMinutes(a.startMinute!)} → '
              '${a.endDate == null ? '' : '${formatDate(context, a.lastDate)} '}${formatMinutes(a.endMinute!)}'
              ' · ${formatDuration(l, a.durationMinutes!)}';
    return InkWell(
      onTap: () => context.push(Routes.editActivity(tripId, a.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(a.kind.icon, color: a.kind.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      a.title,
                      if (a.serviceNumber != null) a.serviceNumber!,
                      if (a.provider != null) a.provider!,
                    ].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (route.isNotEmpty) Text(route, style: TextStyle(color: c.ink2, fontSize: 13)),
                  Text(when, style: TextStyle(color: c.ink3, fontSize: 12)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      Badge2(label: a.bookingStatus.label(l), tone: a.bookingStatus.tone),
                      if (a.cost != null && a.currency != null)
                        Badge2(label: formatMoney(context, a.cost!, a.currency!)),
                      if (a.bookingReference != null) Badge2(icon: Icons.lock_outline, label: a.bookingReference!),
                    ],
                  ),
                  if (a.kind == ActivityKind.flight && !a.isCancelled) FlightStatusSection(activity: a),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
