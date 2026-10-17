import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/contexts/budget/presentation/budget_providers.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/feasibility.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_l10n.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/shared/domain/countdown.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key, required this.tripId, this.initialDate});

  final String tripId;
  final LocalDate? initialDate;

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  LocalDate? _selected;
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final summary = ref.watch(tripProvider(widget.tripId)).value;
    final days = ref.watch(dayAssessmentsProvider(widget.tripId));
    final now = ref.watch(currentTimeProvider);

    if (days.isNotEmpty && (_selected == null || !days.any((d) => d.date == _selected))) {
      final today = summary == null ? null : todayIn(summary.trip.timeZone, now);
      final want = widget.initialDate ?? today;
      _selected = days.any((d) => d.date == want) ? want : days.first.date;
    }
    final day = days.where((d) => d.date == _selected).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(summary == null ? l.tabTimeline : '${l.tabTimeline} · ${summary.trip.title}'),
        actions: [
          IconButton(
            tooltip: _grid ? l.viewList : l.viewGrid,
            icon: Icon(_grid ? Icons.view_agenda_outlined : Icons.calendar_view_day_outlined),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          IconButton(
            tooltip: l.bookingsTitle,
            icon: const Icon(Icons.confirmation_number_outlined),
            onPressed: () => context.push(Routes.bookings(widget.tripId)),
          ),
          IconButton(
            tooltip: l.tabMap,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(Routes.tripMap(widget.tripId, day: _selected)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newActivity(widget.tripId, date: _selected)),
        icon: const Icon(Icons.add),
        label: Text(l.addActivity),
      ),
      body: days.isEmpty
          ? _NoDays(tripId: widget.tripId)
          : Column(
              children: [
                _DayStrip(
                  days: days,
                  selected: _selected!,
                  tripStart: summary?.start,
                  tripEnd: summary?.end ?? summary?.start,
                  onSelect: (d) => setState(() => _selected = d),
                ),
                Expanded(
                  child: day == null
                      ? const SizedBox()
                      : _grid
                      ? _DayGrid(tripId: widget.tripId, day: day)
                      : _DayList(tripId: widget.tripId, day: day),
                ),
              ],
            ),
    );
  }
}

class _NoDays extends StatelessWidget {
  const _NoDays({required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_timeline_outlined, size: 56, color: context.colors.ink3),
            const SizedBox(height: 12),
            Text(l.timelineNoDays, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.editTrip(tripId)),
              icon: const Icon(Icons.date_range),
              label: Text(l.pickDates),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.days, required this.selected, required this.onSelect, this.tripStart, this.tripEnd});

  final List<DayAssessment> days;
  final LocalDate selected;
  final LocalDate? tripStart;
  final LocalDate? tripEnd;
  final ValueChanged<LocalDate> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final locale = context.localeTag;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final on = d.date == selected;
          final inTrip = tripStart != null && d.date >= tripStart! && d.date <= tripEnd!;
          final (_, fg) = d.status.tone.colors(c);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(d.date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: on ? c.brand : c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? c.brand : c.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    inTrip
                        ? l.dayN(tripStart!.daysUntil(d.date) + 1)
                        : DateFormat.E(locale).format(d.date.toDateTime()),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : c.ink2),
                  ),
                  Text(
                    DateFormat.MMMd(locale).format(d.date.toDateTime()),
                    style: TextStyle(fontSize: 12, color: on ? Colors.white70 : c.ink3),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 22,
                    height: 6,
                    decoration: BoxDecoration(
                      color: d.status == DayStatus.empty ? c.line : (on ? Colors.white : fg),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Header with the day's status, cost and the specific reasons behind it.
class _DayHeader extends ConsumerWidget {
  const _DayHeader({required this.tripId, required this.day});
  final String tripId;
  final DayAssessment day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final theme = Theme.of(context);
    final report = ref.watch(budgetReportProvider(tripId)).value;
    final cost = report?.byDayPlanned[day.date];
    final count = day.activities.where((a) => a.date == day.date).length;

    return SectionCard(
      title: DateFormat.yMMMMEEEEd(context.localeTag).format(day.date.toDateTime()),
      icon: Icons.today_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Badge2(label: day.status.label(l), tone: day.status.tone, icon: day.status.icon),
              if (count > 0) Badge2(label: l.activitiesCount(count)),
              if (cost != null && cost > 0 && report?.currency != null)
                Badge2(icon: Icons.payments_outlined, label: formatMoney(context, cost, report!.currency!)),
            ],
          ),
          if (day.issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final i in day.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _IssueRow(tripId: tripId, issue: i),
              ),
            Text(l.feasibilityNote, style: theme.textTheme.bodySmall?.copyWith(color: c.ink3)),
          ],
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.tripId, required this.issue});
  final String tripId;
  final ScheduleIssue issue;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = issue.severity.tone.colors(context.colors);
    final target = issue.activityIds.isEmpty ? null : issue.activityIds.last;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: target == null ? null : () => context.push(Routes.editActivity(tripId, target)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                switch (issue.severity) {
                  IssueSeverity.error => Icons.error_outline,
                  IssueSeverity.warning => Icons.warning_amber_rounded,
                  IssueSeverity.info => Icons.info_outline,
                },
                size: 18,
                color: fg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(issueText(context.l10n, issue), style: TextStyle(color: fg, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- list

class _DayList extends ConsumerWidget {
  const _DayList({required this.tripId, required this.day});
  final String tripId;
  final DayAssessment day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final stays = day.activities.where((a) => a.kind.isStay).toList();
    final items = day.activities.where((a) => !a.kind.isStay).toList();

    final children = <Widget>[
      _DayHeader(tripId: tripId, day: day),
      const SizedBox(height: 12),
      for (final s in stays) ...[_StayTile(tripId: tripId, stay: s, day: day.date), const SizedBox(height: 8)],
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            l.timelineEmptyDay,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.ink3),
          ),
        ),
    ];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        final gap = items[i].startAbsolute - items[i - 1].endAbsolute;
        if (gap > 0) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(left: 64, top: 2, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.more_vert, size: 16, color: c.ink3),
                  const SizedBox(width: 4),
                  Text(l.freeTime(formatDuration(l, gap)), style: TextStyle(color: c.ink3, fontSize: 12)),
                ],
              ),
            ),
          );
        }
      }
      children.add(_ActivityTile(tripId: tripId, activity: items[i], day: day.date));
      children.add(const SizedBox(height: 8));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 104), children: children);
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.tripId, required this.activity, required this.day});
  final String tripId;
  final Activity activity;
  final LocalDate day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.colors;
    final theme = Theme.of(context);
    final a = activity;
    final span = a.spanOn(day);
    final place = a.kind.isTransport
        ? [a.location.name, a.destination.name].where((s) => s != null && s.isNotEmpty).join(' → ')
        : a.location.name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (span == null)
                  Text(
                    l.timeTbd,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(color: c.warn),
                  )
                else ...[
                  Text(formatMinutes(span.$1), style: theme.textTheme.labelLarge),
                  Text(
                    span.$2 == 1440 ? '24:00' : formatMinutes(span.$2),
                    style: theme.textTheme.labelSmall?.copyWith(color: c.ink3),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: c.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(Routes.editActivity(tripId, a.id)),
              onLongPress: () => _activityMenu(context, ref, a),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 5, color: a.isCancelled ? c.ink3 : a.kind.color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(a.kind.icon, size: 18, color: a.kind.color),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    [a.title, if (a.serviceNumber != null) a.serviceNumber!].join(' · '),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      decoration: a.isCancelled ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                if (a.isLocked) Icon(Icons.lock_outline, size: 16, color: c.ink3),
                              ],
                            ),
                            if (place != null && place.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      a.location.point != null ? Icons.location_on : Icons.location_on_outlined,
                                      size: 14,
                                      color: a.location.point != null ? c.brand : c.ink3,
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        place,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(color: c.ink2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (a.durationMinutes case final mins?)
                                  Badge2(label: formatDuration(l, mins))
                                else
                                  Badge2(label: l.notScheduled, tone: Tone.warn, icon: Icons.schedule),
                                if (a.kind.isTransport || a.kind.isStay || a.bookingStatus != BookingStatus.notBooked)
                                  Badge2(label: a.bookingStatus.label(l), tone: a.bookingStatus.tone),
                                if (a.isOptional) Badge2(label: l.fieldOptional, tone: Tone.info),
                                if (a.cost != null && (a.currency != null))
                                  Badge2(
                                    icon: Icons.payments_outlined,
                                    label: formatMoney(context, a.cost!, a.currency!),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StayTile extends StatelessWidget {
  const _StayTile({required this.tripId, required this.stay, required this.day});
  final String tripId;
  final Activity stay;
  final LocalDate day;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final nights = stay.nights.length;
    final idx = stay.nights.indexOf(day);
    return Material(
      color: ActivityKind.hotel.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.hotel_outlined, color: ActivityKind.hotel.color),
        title: Text(stay.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (stay.date == day) '${l.fieldCheckIn} ${stay.hasTime ? formatMinutes(stay.startMinute!) : l.timeTbd}',
            if (stay.lastDate == day) '${l.fieldCheckOut} ${stay.hasTime ? formatMinutes(stay.endMinute!) : l.timeTbd}',
            if (idx >= 0) '${idx + 1}/$nights · ${l.nightsCount(nights)}',
            stay.bookingStatus.label(l),
          ].join(' · '),
        ),
        trailing: stay.isLocked ? Icon(Icons.lock_outline, size: 16, color: c.ink3) : null,
        onTap: () => context.push(Routes.editActivity(tripId, stay.id)),
      ),
    );
  }
}

Future<void> _activityMenu(BuildContext context, WidgetRef ref, Activity a) async {
  final l = context.l10n;
  final svc = ref.read(itineraryServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.editActivity),
            onTap: () => Navigator.pop(c, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: Text(l.duplicateToNextDay),
            onTap: () => Navigator.pop(c, 'dup'),
          ),
          ListTile(
            leading: Icon(a.isLocked ? Icons.lock_open : Icons.lock_outline),
            title: Text(a.isLocked ? '${l.fieldLocked} ✓' : l.fieldLocked),
            onTap: () => Navigator.pop(c, 'lock'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l.actionDelete),
            onTap: () => Navigator.pop(c, 'del'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'edit':
      context.push(Routes.editActivity(a.tripId, a.id));
    case 'dup':
      await svc.duplicateActivity(a.id, toDate: a.date.addDays(1));
    case 'lock':
      await svc.setLocked(a.id, !a.isLocked);
    case 'del':
      await svc.deleteActivity(a.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.activityDeleted),
          action: SnackBarAction(label: l.undo, onPressed: () => svc.restoreActivity(a)),
        ),
      );
  }
}

// --------------------------------------------------------------------- grid

const _hourHeight = 64.0;
const _snap = 15;

class _DayGrid extends ConsumerStatefulWidget {
  const _DayGrid({required this.tripId, required this.day});
  final String tripId;
  final DayAssessment day;

  @override
  ConsumerState<_DayGrid> createState() => _DayGridState();
}

class _DayGridState extends ConsumerState<_DayGrid> {
  // Default visible range starts at 06:00 (the full 00:00–24:00 day scrolls).
  final _scroll = ScrollController(initialScrollOffset: 6 * _hourHeight);
  String? _draggingId;
  double _dragDy = 0;
  bool _resizing = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _snapMinutes(double dy) => ((dy / _hourHeight * 60) / _snap).round() * _snap;

  Future<void> _commit(Activity a, (int, int) span) async {
    final delta = _snapMinutes(_dragDy);
    final resizing = _resizing;
    setState(() {
      _draggingId = null;
      _dragDy = 0;
      _resizing = false;
    });
    if (delta == 0) return;
    final svc = ref.read(itineraryServiceProvider);
    try {
      if (resizing) {
        await svc.resizeActivity(a.id, (a.durationMinutes ?? 60) + delta);
      } else {
        final start = (span.$1 + delta).clamp(0, 24 * 60 - _snap);
        // Blocks are drawn per day; moving keeps the activity on this day.
        await svc.moveActivity(a.id, widget.day.date, a.date == widget.day.date ? start : a.startMinute);
      }
    } on LockedActivityException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.lockedCannotMove)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final blocks = <(Activity, (int, int))>[
      for (final a in widget.day.activities.where((a) => !a.kind.isStay))
        if (a.spanOn(widget.day.date) case final s?) (a, s),
    ];
    final lanes = _assignLanes(blocks.map((b) => b.$2).toList());
    final untimed = widget.day.activities.where((a) => !a.kind.isStay && !a.hasTime).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(l.dragHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.ink3)),
        ),
        // Activities without a decided time can't sit on the grid; list them so nothing is hidden.
        if (untimed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.notScheduled, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.warn)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in untimed)
                      ActionChip(
                        avatar: Icon(a.kind.icon, size: 16, color: a.kind.color),
                        label: Text(a.title, overflow: TextOverflow.ellipsis),
                        onPressed: () => context.push(Routes.editActivity(widget.tripId, a.id)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 104),
            child: SizedBox(
              height: 24 * _hourHeight,
              child: LayoutBuilder(
                builder: (context, box) {
                  const gutter = 56.0;
                  final width = box.maxWidth - gutter - 16;
                  return Stack(
                    children: [
                      for (var h = 0; h <= 24; h++)
                        Positioned(
                          top: h * _hourHeight,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              SizedBox(
                                width: gutter - 8,
                                child: Text(
                                  h == 24 ? '' : '${h.toString().padLeft(2, '0')}:00',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 11, color: c.ink3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Divider(height: 1, color: c.line)),
                            ],
                          ),
                        ),
                      for (var i = 0; i < blocks.length; i++)
                        _block(context, blocks[i].$1, blocks[i].$2, lanes[i], gutter, width),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _block(BuildContext context, Activity a, (int, int) span, (int, int) lane, double gutter, double width) {
    final c = context.colors;
    final dragging = _draggingId == a.id;
    var top = span.$1 / 60 * _hourHeight;
    var height = (span.$2 - span.$1) / 60 * _hourHeight;
    if (dragging) {
      final snapped = _snapMinutes(_dragDy) / 60 * _hourHeight;
      if (_resizing) {
        height = (height + snapped).clamp(_snap / 60 * _hourHeight, 24 * _hourHeight - top);
      } else {
        top = (top + snapped).clamp(0.0, 24 * _hourHeight - height);
      }
    }
    final laneWidth = width / lane.$2;
    final color = a.isCancelled ? c.ink3 : a.kind.color;
    final previewStart = dragging && !_resizing ? (span.$1 + _snapMinutes(_dragDy)).clamp(0, 1440) : span.$1;

    return Positioned(
      top: top,
      left: gutter + lane.$1 * laneWidth,
      width: laneWidth - 4,
      height: height < 22 ? 22 : height,
      child: GestureDetector(
        onTap: () => context.push(Routes.editActivity(widget.tripId, a.id)),
        onLongPressStart: (_) => setState(() {
          _draggingId = a.id;
          _dragDy = 0;
          _resizing = false;
        }),
        onLongPressMoveUpdate: (d) => setState(() => _dragDy = d.offsetFromOrigin.dy),
        onLongPressEnd: (_) => _commit(a, span),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: color.withValues(alpha: dragging ? 0.3 : 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: dragging ? softShadow(Theme.of(context).brightness) : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 6, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(a.kind.icon, size: 14, color: color),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (a.isLocked) const Icon(Icons.lock_outline, size: 12),
                      ],
                    ),
                    if (height > 38)
                      Text(
                        '${formatMinutes(previewStart)}–${span.$2 == 1440 ? '24:00' : formatMinutes(span.$2)}',
                        style: TextStyle(fontSize: 11, color: c.ink2),
                      ),
                  ],
                ),
              ),
              if (!a.isLocked)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 14,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => setState(() {
                      _draggingId = a.id;
                      _dragDy = 0;
                      _resizing = true;
                    }),
                    onVerticalDragUpdate: (d) => setState(() => _dragDy += d.delta.dy),
                    onVerticalDragEnd: (_) => _commit(a, span),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 4,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Assigns (lane index, lanes in cluster) so overlapping blocks sit side by side.
List<(int, int)> _assignLanes(List<(int, int)> spans) {
  final order = List.generate(spans.length, (i) => i)..sort((a, b) => spans[a].$1.compareTo(spans[b].$1));
  final result = List<(int, int)>.filled(spans.length, (0, 1));
  var cluster = <int>[];
  var laneEnds = <int>[];
  var clusterEnd = -1;

  void flush() {
    final n = laneEnds.length;
    for (final i in cluster) {
      result[i] = (result[i].$1, n);
    }
    cluster = [];
    laneEnds = [];
  }

  for (final i in order) {
    final (s, e) = spans[i];
    if (s >= clusterEnd && cluster.isNotEmpty) flush();
    var lane = laneEnds.indexWhere((end) => end <= s);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(e);
    } else {
      laneEnds[lane] = e;
    }
    result[i] = (lane, 1);
    cluster.add(i);
    clusterEnd = cluster.length == 1 ? e : (e > clusterEnd ? e : clusterEnd);
  }
  if (cluster.isNotEmpty) flush();
  return result;
}
