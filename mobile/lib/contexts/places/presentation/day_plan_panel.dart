import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_optimizer.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_route.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_settings.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_l10n.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/contexts/places/presentation/location_picker_screen.dart';
import 'package:wanderplan/contexts/places/presentation/paste_location_dialog.dart';
import 'package:wanderplan/contexts/places/presentation/place_category_ui.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

/// What the map found out about one leg of the day.
class LegResult {
  const LegResult(this.leg, this.mode, {this.meters, this.seconds, this.unverified = false});
  final DayLeg leg;

  /// Null for booked flights/trains/ferries and undecided transport.
  final TravelMode? mode;
  final double? meters;

  /// Routed duration (null when not routed).
  final double? seconds;

  /// No road route: drawn straight and labelled unverified.
  final bool unverified;

  /// The time used for planning: the traveller's own estimate, else the route's.
  int? get minutes => leg.manualMinutes ?? (seconds == null ? null : (seconds! / 60).round());
}

String _time(int m) => m >= 1440 ? '${formatMinutes(m - 1440)} (+1)' : formatMinutes(m);

String stopName(AppLocalizations l, DayStop s) {
  final a = s.activity;
  if (a == null) return s.label ?? l.mapPinnedPlace;
  final place = s.isArrival ? a.destination.name : a.location.name;
  return place != null && place != a.title ? '${a.title} · $place' : a.title;
}

/// Start/end points, per-leg travel and the "optimize order" entry point,
/// shown under the map when one day is selected.
class DayPlanPanel extends StatelessWidget {
  const DayPlanPanel({
    super.key,
    required this.plan,
    required this.legs,
    required this.day,
    required this.onEditAnchor,
    required this.onEditLeg,
    required this.onOptimize,
    required this.canOptimize,
  });

  final DayRoutePlan plan;
  final List<LegResult> legs;
  final LocalDate day;
  final void Function(DayAnchor) onEditAnchor;
  final void Function(LegResult) onEditLeg;
  final VoidCallback onOptimize;
  final bool canOptimize;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final small = TextStyle(fontSize: 12, color: c.ink2);

    Widget anchorRow(DayAnchor which) {
      final s = which == DayAnchor.start ? plan.start : plan.end;
      final custom = s != null && s.activity == null;
      final label = which == DayAnchor.start ? l.dayStart : l.dayEnd;
      return InkWell(
        onTap: () => onEditAnchor(which),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(which == DayAnchor.start ? Icons.trip_origin : Icons.sports_score, size: 18, color: c.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s == null ? '$label: ${l.dayAnchorNotSet}' : '$label: ${stopName(l, s)}${custom ? '' : ' (${l.dayAnchorHotel})'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.edit_outlined, size: 16, color: c.ink3),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        anchorRow(DayAnchor.start),
        anchorRow(DayAnchor.end),
        if (legs.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(l.dayLegs, style: Theme.of(context).textTheme.labelLarge),
          for (final r in legs) _legRow(context, r, small),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: Text(l.optimizeOrder),
              onPressed: canOptimize ? onOptimize : null,
            ),
            if (!canOptimize) Text(l.optimizeNeedsTwo, style: TextStyle(fontSize: 11, color: c.ink3)),
          ],
        ),
      ],
    );
  }

  Widget _legRow(BuildContext context, LegResult r, TextStyle small) {
    final l = context.l10n;
    final c = context.colors;
    final leg = r.leg;
    final editable = leg.kind == DayLegKind.road && leg.fixedMode == null;
    final available = leg.availableMinutes(day);
    final short = available != null && r.minutes != null && r.minutes! > available ? r.minutes! - available : null;
    final what = switch (leg.kind) {
      DayLegKind.booked => leg.from.activity!.kind.label(l),
      DayLegKind.undecided => l.legUndecided,
      DayLegKind.road when r.mode == TravelMode.transit && leg.manualMinutes == null => l.legTransitNoTime,
      DayLegKind.road when r.minutes != null => [
        if (r.meters != null) _km(context, r.meters!),
        '${leg.manualMinutes != null ? '${l.legYourEstimate} ' : ''}${formatDuration(l, r.minutes!)}',
      ].join(' · '),
      _ => l.legNoRoute,
    };
    return InkWell(
      onTap: editable ? () => onEditLeg(r) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              leg.kind == DayLegKind.booked ? leg.from.activity!.kind.icon : (r.mode ?? TravelMode.walking).icon,
              size: 18,
              color: r.unverified ? c.warn : c.ink2,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stopName(l, leg.from)} → ${stopName(l, leg.to)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(what, style: small),
                  if (short != null)
                    Badge2(label: l.legTooShort(short), tone: Tone.warn, icon: Icons.timer_off_outlined),
                ],
              ),
            ),
            if (editable) Icon(Icons.tune, size: 16, color: c.ink3),
          ],
        ),
      ),
    );
  }

  static String _km(BuildContext context, double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
}

// --- Start / end point --------------------------------------------------------

/// Lets the traveller choose where a day starts or ends: the hotel (default),
/// a saved place, a map pin or a pasted link.
Future<void> showDayAnchorSheet(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  required LocalDate day,
  required DayAnchor which,
  GeoPoint? near,
}) async {
  final l = context.l10n;
  final saved = ref.read(savedPlacesProvider(tripId)).value ?? const [];
  final hotels = {
    for (final a in ref.read(tripActivitiesProvider(tripId)).value ?? const <Activity>[])
      if (a.kind.isStay && a.location.point != null && !a.isCancelled) a.location.name ?? a.title: a.location,
  };
  final service = ref.read(itineraryServiceProvider);

  Future<void> set(PlaceRef p) => which == DayAnchor.start
      ? service.setDayAnchors(tripId, day, start: p)
      : service.setDayAnchors(tripId, day, end: p);

  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                which == DayAnchor.start ? l.dayStartTitle : l.dayEndTitle,
                style: Theme.of(c).textTheme.titleMedium,
              ),
              subtitle: Text(formatDate(context, day)),
            ),
            ListTile(
              leading: const Icon(Icons.hotel_outlined),
              title: Text(l.dayAnchorUseHotel),
              onTap: () => Navigator.pop(c, const PlaceRef()),
            ),
            for (final e in hotels.entries)
              ListTile(
                leading: const Icon(Icons.bed_outlined),
                title: Text(e.key),
                onTap: () => Navigator.pop(c, e.value),
              ),
            for (final p in saved)
              ListTile(
                leading: Icon(p.category.icon),
                title: Text(p.name),
                onTap: () => Navigator.pop(c, PlaceRef(name: p.name, point: p.point, source: p.source)),
              ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: Text(l.pickOnMap),
              onTap: () => Navigator.pop(c, 'pick'),
            ),
            ListTile(
              leading: const Icon(Icons.add_link),
              title: Text(l.pasteLocation),
              onTap: () => Navigator.pop(c, 'paste'),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice is PlaceRef) return set(choice);
  if (!context.mounted) return;
  if (choice == 'pick') {
    final r = await pickLocation(context, near: near);
    if (r?.point != null) await set(r!);
  } else if (choice == 'paste') {
    final r = await showPasteLocationDialog(context, near: near);
    if (r != null) await set(PlaceRef(name: l.mapPinnedPlace, point: r.point, source: r.source));
  }
}

// --- One leg ------------------------------------------------------------------

/// Choose how to get from one stop to the next, and optionally your own time.
Future<void> showLegSheet(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  required LocalDate day,
  required LegResult result,
  required TravelMode dayDefault,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _LegSheet(tripId: tripId, day: day, result: result, dayDefault: dayDefault),
);

class _LegSheet extends ConsumerStatefulWidget {
  const _LegSheet({required this.tripId, required this.day, required this.result, required this.dayDefault});
  final String tripId;
  final LocalDate day;
  final LegResult result;
  final TravelMode dayDefault;

  @override
  ConsumerState<_LegSheet> createState() => _LegSheetState();
}

class _LegSheetState extends ConsumerState<_LegSheet> {
  late TravelMode? _mode = widget.result.leg.chosenMode;
  late final _minutes = TextEditingController(text: widget.result.leg.manualMinutes?.toString() ?? '');

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minutes = int.tryParse(_minutes.text.trim());
    final leg = widget.result.leg;
    final service = ref.read(itineraryServiceProvider);
    if (leg.to.anchor == DayAnchor.end) {
      await service.setEndArrival(widget.tripId, widget.day, _mode, minutes);
    } else if (leg.to.activity != null) {
      await service.setArrival(leg.to.activity!.id, _mode, minutes);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final leg = widget.result.leg;
    final transit = _mode == TravelMode.transit;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.legTitle, style: Theme.of(context).textTheme.titleMedium),
            Text('${stopName(l, leg.from)} → ${stopName(l, leg.to)}', style: TextStyle(color: c.ink2)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(l.legDefault(widget.dayDefault.label(l))),
                  selected: _mode == null,
                  onSelected: (_) => setState(() => _mode = null),
                ),
                for (final m in TravelMode.values)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(m.icon, size: 18),
                    label: Text(m.label(l)),
                    selected: _mode == m,
                    onSelected: (_) => setState(() => _mode = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.legMinutes,
                helperText: transit ? l.legTransitHelp : l.legMinutesHelp,
                helperMaxLines: 3,
                suffixText: 'min',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(onPressed: _save, child: Text(l.actionSave)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Optimize -----------------------------------------------------------------

/// Proposes the order of the day's movable visits with the least travel and
/// lets the traveller apply it. Nothing changes until "Apply".
Future<void> showOptimizeSheet(
  BuildContext context, {
  required String tripId,
  required LocalDate day,
  required MapProviderId provider,
  required TravelMode mode,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _OptimizeSheet(tripId: tripId, day: day, provider: provider, mode: mode, outer: context),
);

class _OptimizeSheet extends ConsumerStatefulWidget {
  const _OptimizeSheet({
    required this.tripId,
    required this.day,
    required this.provider,
    required this.mode,
    required this.outer,
  });
  final String tripId;
  final LocalDate day;
  final MapProviderId provider;
  final TravelMode mode;
  final BuildContext outer;

  @override
  ConsumerState<_OptimizeSheet> createState() => _OptimizeSheetState();
}

class _OptimizeSheetState extends ConsumerState<_OptimizeSheet> {
  TravelMatrix? _matrix;
  Map<GeoPoint, int> _index = const {};
  DayOptimization? _plan;
  int? _dayStart;
  bool _loading = true;
  bool _applying = false;

  List<Activity> get _acts => ref.read(tripActivitiesProvider(widget.tripId)).value ?? const [];
  DaySettings? get _settings =>
      (ref.read(daySettingsProvider(widget.tripId)).value ?? const []).where((s) => s.date == widget.day).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final acts = _acts;
    final settings = _settings;
    final (lastNight, tonight) = defaultDayAnchors(acts, widget.day);
    final points = <GeoPoint>{
      ?settings?.start.point ?? lastNight?.location.point,
      for (final a in acts.where((a) => activityOccursOn(a, widget.day) && !a.kind.isStay)) ...[
        ?a.location.point,
        ?a.destination.point,
      ],
      ?settings?.end.point ?? tonight?.location.point,
    }.toList();
    final matrix = await ref.read(mapServicesProvider).matrix(widget.provider, points, widget.mode);
    if (!mounted) return;
    _matrix = matrix;
    _index = {for (var i = 0; i < points.length; i++) points[i]: i};
    _compute();
  }

  void _compute() {
    final m = _matrix!;
    double travel(GeoPoint a, GeoPoint b) {
      final i = _index[a], j = _index[b];
      final s = i == null || j == null ? null : m.between(i, j);
      return (s ?? a.distanceKmTo(b) * detourFactor / widget.mode.estimateKmh * 3600) / 60;
    }

    setState(() {
      _plan = optimizeDay(
        activities: _acts,
        day: widget.day,
        travel: travel,
        settings: _settings,
        dayStartMinute: _dayStart,
      );
      _dayStart ??= _plan?.dayStartMinute;
      _loading = false;
    });
  }

  Future<void> _apply() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(widget.outer);
    setState(() => _applying = true);
    final n = await ref.read(itineraryServiceProvider).applyDayPlan(widget.day, _plan!);
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(l.optimizeApplied(n))));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final plan = _plan;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(l.routeLoading),
                  ],
                ),
              )
            : plan == null
            ? Padding(padding: const EdgeInsets.all(24), child: Text(l.optimizeNeedsTwo))
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(l.optimizeTitle, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    plan.savedMinutes > 0
                        ? l.optimizeSaves(
                            formatDuration(l, plan.currentTravelMinutes),
                            formatDuration(l, plan.travelMinutes),
                            formatDuration(l, plan.savedMinutes),
                          )
                        : l.optimizeAlreadyBest(formatDuration(l, plan.travelMinutes)),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _matrix!.estimated ? l.optimizeEstimated(widget.mode.label(l)) : l.optimizeRouted(widget.mode.label(l)),
                    style: TextStyle(fontSize: 12, color: c.ink3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(l.optimizeDayStart),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: _dayStart! ~/ 60, minute: _dayStart! % 60),
                          );
                          if (t == null) return;
                          _dayStart = t.hour * 60 + t.minute;
                          _compute();
                        },
                        child: Text(formatMinutes(_dayStart!)),
                      ),
                    ],
                  ),
                  const Divider(),
                  for (final item in plan.items) _itemRow(context, item),
                  const SizedBox(height: 8),
                  Text(l.optimizeKeepsFixed, style: TextStyle(fontSize: 12, color: c.ink3)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _applying ? null : _apply, child: Text(l.optimizeApply)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _itemRow(BuildContext context, PlannedItem item) {
    final l = context.l10n;
    final c = context.colors;
    final a = item.activity;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text('${_time(item.start)}–${_time(item.end)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Icon(a.kind.icon, size: 18, color: a.kind.color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (item.travelMinutes > 0)
                      Text(l.optimizeTravel(formatDuration(l, item.travelMinutes)), style: TextStyle(fontSize: 12, color: c.ink3)),
                    if (item.waitMinutes > 0)
                      Text(l.optimizeWait(formatDuration(l, item.waitMinutes)), style: TextStyle(fontSize: 12, color: c.ink3)),
                    if (item.fixed) Badge2(label: l.optimizeFixed, icon: Icons.lock_outline),
                    if (item.assumedDuration) Badge2(label: l.optimizeAssumed, tone: Tone.info),
                    if (item.closed) Badge2(label: l.optimizeClosed, tone: Tone.bad),
                    if (item.outsideHours) Badge2(label: l.optimizeOutsideHours, tone: Tone.warn),
                    if (item.lateMinutes > 0)
                      Badge2(label: l.optimizeLate(item.lateMinutes), tone: Tone.bad, icon: Icons.warning_amber),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
