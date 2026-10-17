import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/contexts/trip/presentation/banner/trip_banner_view.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/contexts/trip/presentation/widgets/trip_action_rail.dart';

import 'package:wanderplan/shared/presentation/atlas.dart';

enum TripCardAction { edit, banner, duplicate, archive, delete }

class TripCard extends ConsumerWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onAction,
    this.index = 1,
  });
  final TripSummary trip;
  final VoidCallback onTap;
  final ValueChanged<TripCardAction> onAction;
  final int index;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n, c = context.colors;
    final now = ref.watch(currentTimeProvider),
        t = trip.trip,
        status = trip.status(ref.watch(currentTimeProvider));
    Widget fact(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.ink2),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: TextStyle(fontSize: 12, color: c.ink2)),
        ),
      ],
    );
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 194,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TripBannerView(
                    config: trip.banner,
                    title: t.title,
                    subtitle: trip.primaryDestination,
                    contentPadding: const EdgeInsets.fromLTRB(20, 60, 70, 20),
                  ),
                  Positioned(
                    left: 20,
                    top: 20,
                    child: Text(
                      '${l.atlasJourney.toUpperCase()} / ${index.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE617382A),
                        border: Border.all(color: Colors.white38),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(status.icon, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            status.label(l),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 57,
                    bottom: 10,
                    child: Center(
                      child: TripActionRail(
                        tripId: trip.id,
                        buttonSize: 36,
                        spacing: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const FolioDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 13, 8, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!trip.banner.showTitle)
                              Text(
                                t.title,
                                style: atlasEditorial(context, size: 26),
                              ),
                            Text(
                              countdownHeadline(l, trip.countdown(now)),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.brandStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Menu(archived: t.archived, onAction: onAction),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      children: [
                        fact(
                          Icons.event_outlined,
                          formatDateRange(context, trip.start, trip.end),
                        ),
                        if (trip.durationDays != null)
                          fact(Icons.schedule, l.daysCount(trip.durationDays!)),
                        fact(
                          Icons.group_outlined,
                          l.travelersCount(t.travelerCount),
                        ),
                        if (trip.todosTotal > 0)
                          fact(
                            Icons.checklist,
                            '${l.todosShort} ${trip.todosDone}/${trip.todosTotal}',
                          ),
                        if (t.totalBudget != null && t.currency != null)
                          fact(
                            Icons.savings_outlined,
                            formatMoney(context, t.totalBudget!, t.currency!),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.archived, required this.onAction});
  final bool archived;
  final ValueChanged<TripCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    PopupMenuItem<TripCardAction> item(
      TripCardAction a,
      IconData icon,
      String label,
    ) => PopupMenuItem(
      value: a,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        contentPadding: EdgeInsets.zero,
      ),
    );
    return PopupMenuButton<TripCardAction>(
      icon: Icon(Icons.more_horiz, color: context.colors.ink2),
      onSelected: onAction,
      itemBuilder: (_) => [
        item(TripCardAction.edit, Icons.edit_outlined, l.actionEdit),
        item(
          TripCardAction.banner,
          Icons.wallpaper_outlined,
          l.actionEditBanner,
        ),
        item(TripCardAction.duplicate, Icons.copy_outlined, l.actionDuplicate),
        item(
          TripCardAction.archive,
          archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          archived ? l.actionUnarchive : l.actionArchive,
        ),
        item(TripCardAction.delete, Icons.delete_outline, l.actionDelete),
      ],
    );
  }
}
