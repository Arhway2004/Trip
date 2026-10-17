import 'package:flutter/material.dart';
import 'package:wanderplan/shared/presentation/atlas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/domain/countdown.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/time_zone_picker.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';
import 'package:wanderplan/contexts/trip/presentation/banner/trip_banner_view.dart';
import 'package:wanderplan/contexts/gallery/presentation/gallery_providers.dart';
import 'package:wanderplan/contexts/gallery/presentation/photo_thumbnail.dart';
import 'package:wanderplan/contexts/sharing/presentation/share_trip_sheet.dart';
import 'package:wanderplan/contexts/checklist/presentation/checklist_providers.dart';
import 'package:wanderplan/contexts/checklist/domain/checklist_item.dart';
import 'package:wanderplan/contexts/budget/presentation/budget_providers.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/feasibility.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_l10n.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/contexts/checklist/presentation/checklist_l10n.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_actions.dart';
import 'package:wanderplan/contexts/trip/presentation/widgets/trip_action_rail.dart';
import 'package:wanderplan/contexts/trip/presentation/widgets/trip_card.dart';

class TripDashboardScreen extends ConsumerWidget {
  const TripDashboardScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ref
        .watch(tripProvider(tripId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('$e')),
          ),
          data: (trip) => trip == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: Center(child: Text(l.tripNotFound)),
                )
              : _Dashboard(trip: trip),
        );
  }
}

class _Dashboard extends ConsumerStatefulWidget {
  const _Dashboard({required this.trip});
  final TripSummary trip;

  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final l = context.l10n;
    final t = trip.trip;
    final banner = trip.banner;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const AtlasBrand(),
        toolbarHeight: 68,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.line),
        ),
        actions: [
          IconButton(
            tooltip: l.shareTrip,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => showShareTripSheet(context, trip),
          ),
          IconButton(
            tooltip: l.actionEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.editTrip(trip.id)),
          ),
          PopupMenuButton<TripCardAction>(
            onSelected: (a) => runTripAction(context, ref, trip, a),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: TripCardAction.banner,
                child: Text(l.actionEditBanner),
              ),
              PopupMenuItem(
                value: TripCardAction.duplicate,
                child: Text(l.actionDuplicate),
              ),
              PopupMenuItem(
                value: TripCardAction.archive,
                child: Text(t.archived ? l.actionUnarchive : l.actionArchive),
              ),
              PopupMenuItem(
                value: TripCardAction.delete,
                child: Text(l.actionDelete),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 264,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TripBannerView(
                            config: banner,
                            title: t.title,
                            subtitle: trip.primaryDestination,
                            titleScale: 1.2,
                            contentPadding: const EdgeInsets.fromLTRB(
                              24,
                              60,
                              24,
                              24,
                            ),
                          ),
                          Positioned(
                            left: 24,
                            top: 24,
                            child: Text(
                              l.atlasJourney.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                sliver: SliverList.list(
                  children: [
                    TripQuickActions(tripId: trip.id),
                    const SizedBox(height: 16),
                    _CountdownHero(trip: trip),
                    const SizedBox(height: 12),
                    _Kpis(trip: trip),
                    const SizedBox(height: 16),
                    _PlanCard(trip: trip),
                    const SizedBox(height: 16),
                    _TodosCard(trip: trip),
                    const SizedBox(height: 16),
                    _OverviewCard(trip: trip),
                    const SizedBox(height: 16),
                    _PhotosCard(trip: trip),
                    const SizedBox(height: 16),
                    _ToolsCard(trip: trip),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownHero extends ConsumerWidget {
  const _CountdownHero({required this.trip});
  final TripSummary trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final theme = Theme.of(context);
    final now = ref.watch(currentTimeProvider);
    final cd = trip.countdown(now);
    final status = trip.status(now);
    final time = parseTimeOfDay(trip.trip.departureTime);

    String? sub;
    if (trip.start != null && cd is CountdownBeforeDeparture) {
      final date = formatDate(context, trip.start!);
      sub = time == null
          ? l.departsOn(date)
          : l.departsOnAt(date, formatTimeOfDay(time.$1, time.$2));
      if (!trip.trip.datesConfirmed) sub = '$sub · ${l.datesFlexible}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(appRadius),
        color: c.surface,
        border: Border.all(color: c.line),
        boxShadow: softShadow(theme.brightness),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(status.icon, color: c.brand, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  countdownHeadline(l, cd),
                  style: atlasEditorial(context, size: 28),
                ),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: c.ink2,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.brandSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    status.label(l),
                    style: TextStyle(
                      color: c.brandStrong,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpis extends ConsumerWidget {
  const _Kpis({required this.trip});
  final TripSummary trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final report = ref.watch(budgetReportProvider(trip.id)).value;
    final t = trip.trip;
    final hasBudget = t.totalBudget != null && t.currency != null;
    final tiles = [
      KpiTile(
        icon: Icons.schedule,
        label: l.kpiDuration,
        value: trip.durationDays == null
            ? '—'
            : l.daysCount(trip.durationDays!),
        sub: trip.start == null ? l.datesUndecided : null,
      ),
      KpiTile(
        icon: Icons.group_outlined,
        label: l.fieldTravelers,
        value: '${t.travelerCount}',
      ),
      KpiTile(
        icon: Icons.savings_outlined,
        label: l.budgetTitle,
        value: hasBudget
            ? formatMoney(context, t.totalBudget!, t.currency!)
            : '—',
        sub:
            report != null &&
                t.currency != null &&
                (report.planned > 0 || report.actual > 0)
            ? '${l.budgetPlanned} ${formatMoney(context, report.planned, t.currency!)} · '
                  '${l.budgetSpent} ${formatMoney(context, report.actual, t.currency!)}'
            : (hasBudget ? null : l.budgetNotSet),
        tone: hasBudget && report != null && report.planned > t.totalBudget!
            ? Tone.bad
            : null,
        onTap: () => context.push(Routes.tripBudget(trip.id)),
      ),
      KpiTile(
        icon: Icons.checklist,
        label: l.todosShort,
        value: trip.todosTotal == 0
            ? '—'
            : '${trip.todosDone}/${trip.todosTotal}',
        tone: trip.todosTotal > 0 && trip.todosDone == trip.todosTotal
            ? Tone.good
            : null,
        onTap: () => context.push(Routes.todos(trip.id)),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = MediaQuery.textScalerOf(context).scale(14) > 18
            ? 1
            : box.maxWidth >= 640
            ? 4
            : 2;
        final w = (box.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final k in tiles) SizedBox(width: w, child: k)],
        );
      },
    );
  }
}

/// Next activity and how many days need attention, straight from the itinerary.
class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.trip});
  final TripSummary trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final theme = Theme.of(context);
    final acts =
        ref.watch(tripActivitiesProvider(trip.id)).value ?? const <Activity>[];
    final days = ref.watch(dayAssessmentsProvider(trip.id));
    final now = ref.watch(currentTimeProvider);
    final today = todayIn(trip.trip.timeZone, now);
    final nowMinute =
        today.epochDay * 1440 + minuteOfDayIn(trip.trip.timeZone, now);
    final upcoming = acts
        .where(
          (a) => !a.isCancelled && !a.kind.isStay && a.endAbsolute >= nowMinute,
        )
        .toList();
    final next = upcoming.isEmpty ? null : upcoming.first;
    final attention = days
        .where(
          (d) =>
              d.status == DayStatus.tight || d.status == DayStatus.unrealistic,
        )
        .length;
    final planned = days.where((d) => d.status != DayStatus.empty).length;

    return SectionCard(
      title: l.tabTimeline,
      icon: Icons.view_timeline_outlined,
      actionLabel: l.viewAll,
      onTap: () => context.push(Routes.tripTimeline(trip.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (acts.isEmpty)
            Text(
              l.noActivitiesYet,
              style: theme.textTheme.bodyMedium?.copyWith(color: c.ink2),
            )
          else ...[
            Badge2(
              icon: attention > 0
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              tone: attention > 0
                  ? Tone.warn
                  : (planned > 0 ? Tone.good : Tone.neutral),
              label: attention > 0
                  ? l.daysNeedAttention(attention)
                  : l.allDaysOk,
            ),
            if (next != null) ...[
              const SizedBox(height: 12),
              Text(
                l.nextUp,
                style: theme.textTheme.labelMedium?.copyWith(color: c.ink3),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () =>
                    context.push(Routes.editActivity(trip.id, next.id)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: next.kind.color.withValues(alpha: 0.12),
                      child: Icon(
                        next.kind.icon,
                        size: 18,
                        color: next.kind.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            next.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${formatDate(context, next.date)} · ${activityTimeText(l, next)}'
                            '${next.location.name == null ? '' : ' · ${next.location.name}'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: c.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(Routes.newActivity(trip.id, date: today)),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.addActivity),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.tripMap(trip.id)),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(l.tabMap),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodosCard extends ConsumerWidget {
  const _TodosCard({required this.trip});
  final TripSummary trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final theme = Theme.of(context);
    final todos = ref.watch(tripTodosProvider(trip.id)).value ?? const [];
    final open = todos.where((t) => !t.isDone).toList();
    final today = todayIn(trip.trip.timeZone, ref.watch(currentTimeProvider));
    final done = todos.length - open.length;

    return SectionCard(
      title: l.todosTitle,
      icon: Icons.checklist,
      accent: true,
      actionLabel: l.viewAll,
      onTap: () => context.push(Routes.todos(trip.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (todos.isEmpty)
            Text(
              l.todosEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(color: c.ink2),
            )
          else ...[
            Text(
              open.isEmpty
                  ? l.todosAllDone
                  : l.todosProgress(done, todos.length),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: done / todos.length,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
            if (open.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l.todosNextUp,
                style: theme.textTheme.labelMedium?.copyWith(color: c.ink3),
              ),
              for (final t in open.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked,
                        size: 18,
                        color: c.ink3,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (t.dueDate case final due?)
                        Builder(
                          builder: (context) {
                            final status = todoDue(due: due, today: today);
                            return Badge2(
                              label: todoDueLabel(l, status),
                              tone: status is TodoOverdue
                                  ? Tone.bad
                                  : Tone.neutral,
                            );
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.trip});
  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = trip.trip;
    final theme = Theme.of(context);
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: c.brandStrong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );

    return SectionCard(
      title: l.overview,
      icon: Icons.info_outline,
      actionLabel: l.actionEdit,
      onAction: () => context.push(Routes.editTrip(trip.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip.destinations.isNotEmpty)
            row(
              Icons.place_outlined,
              trip.destinations.map(destinationLabel).join(' → '),
            ),
          row(
            Icons.event_outlined,
            formatDateRange(context, trip.start, trip.end),
          ),
          row(
            Icons.public,
            '${t.timeZone.replaceAll('_', ' ')} (${utcOffsetLabel(t.timeZone)})',
          ),
          if (trip.travelStyle != null)
            row(Icons.style_outlined, trip.travelStyle!.label(l)),
          if (t.description != null) ...[
            const Divider(height: 24),
            Text(
              t.description!,
              style: theme.textTheme.bodyMedium?.copyWith(color: c.ink2),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotosCard extends ConsumerWidget {
  const _PhotosCard({required this.trip});
  final TripSummary trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final photos = ref.watch(tripPhotosProvider(trip.id)).value ?? const [];
    return SectionCard(
      title: '${l.photosTitle} · ${l.photoCount(photos.length)}',
      icon: Icons.photo_library_outlined,
      actionLabel: l.openGallery,
      onTap: () => context.push(Routes.gallery(trip.id)),
      child: photos.isEmpty
          ? Text(l.galleryEmpty, style: TextStyle(color: context.colors.ink2))
          : SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length.clamp(0, 12),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(
                  width: 84,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PhotoThumbnail(relPath: photos[i].relPath, size: 84),
                  ),
                ),
              ),
            ),
    );
  }
}

/// All of a trip's tools in one grid. Tools from later phases are visible
/// but disabled and marked "Soon" rather than leading to fake screens.
class _ToolsCard extends StatelessWidget {
  const _ToolsCard({required this.trip});
  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id = trip.id;
    final tools = <(IconData, String, String?)>[
      (Icons.map_outlined, l.tabMap, Routes.tripMap(id)),
      (Icons.view_timeline_outlined, l.tabTimeline, Routes.tripTimeline(id)),
      (
        Icons.account_balance_wallet_outlined,
        l.tabBudget,
        Routes.tripBudget(id),
      ),
      (Icons.checklist, l.todosShort, Routes.todos(id)),
      (Icons.photo_library_outlined, l.moreGallery, Routes.gallery(id)),
      (Icons.wallpaper_outlined, l.actionEditBanner, Routes.banner(id)),
      (
        Icons.flight_outlined,
        l.moreFlights,
        Routes.newActivity(id, kind: ActivityKind.flight),
      ),
      (
        Icons.confirmation_number_outlined,
        l.bookingsTitle,
        Routes.bookings(id),
      ),
      (
        Icons.hotel_outlined,
        l.moreHotels,
        Routes.newActivity(id, kind: ActivityKind.hotel),
      ),
      (Icons.attractions_outlined, l.moreAttractions, null),
      (Icons.receipt_long_outlined, l.moduleExpense, Routes.tripBudget(id)),
      (Icons.menu_book_outlined, l.moreJournal, null),
    ];
    return SectionCard(
      title: l.tripTools,
      icon: Icons.apps,
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = MediaQuery.textScalerOf(context).scale(14) > 18
              ? 1
              : box.maxWidth >= 700
              ? 3
              : 2;
          final width = (box.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, label, route) in tools)
                SizedBox(
                  width: width,
                  child: _ToolTile(icon: icon, label: label, route: route),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = route != null;
    return Material(
      color: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => context.push(route!) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: enabled ? c.brand : c.ink3),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: enabled ? c.ink : c.ink3),
                      ),
                      if (!enabled)
                        Text(
                          context.l10n.soon,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: c.ink3),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
