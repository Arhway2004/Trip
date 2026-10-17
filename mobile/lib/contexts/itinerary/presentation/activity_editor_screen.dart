import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_l10n.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/contexts/places/presentation/location_picker_screen.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/shared/domain/currency.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

/// Creates or edits an itinerary activity (including flights, trains and hotel stays).
class ActivityEditorScreen extends ConsumerStatefulWidget {
  const ActivityEditorScreen({super.key, required this.tripId, this.activityId, this.initialDate, this.initialKind});

  final String tripId;
  final String? activityId;
  final LocalDate? initialDate;
  final ActivityKind? initialKind;

  @override
  ConsumerState<ActivityEditorScreen> createState() => _ActivityEditorScreenState();
}

class _ActivityEditorScreenState extends ConsumerState<ActivityEditorScreen> {
  final _title = TextEditingController();
  final _cost = TextEditingController();
  final _currency = TextEditingController();
  final _provider = TextEditingController();
  final _serviceNumber = TextEditingController();
  final _bookingRef = TextEditingController();
  final _bookingUrl = TextEditingController();
  final _notes = TextEditingController();
  final _locationName = TextEditingController();
  final _destinationName = TextEditingController();

  ActivityDraft? _d;
  bool _endTouched = false;

  /// When true the activity is saved without times (schedule not confirmed).
  bool _timeTbd = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.activityId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trip = await ref.read(tripServiceProvider).getTrip(widget.tripId);
    final existing = _isEdit ? await ref.read(itineraryServiceProvider).getActivity(widget.activityId!) : null;
    if (!mounted) return;
    final d =
        existing != null
              ? ActivityDraft.fromActivity(existing)
              : _defaults(
                  widget.initialKind ?? ActivityKind.sightseeing,
                  widget.initialDate ?? trip?.startDate ?? LocalDate.fromDateTime(DateTime.now()),
                )
          ..currency ??= trip?.currency;
    _title.text = d.title;
    _cost.text = d.cost == null ? '' : _trim(d.cost!);
    _currency.text = d.currency ?? '';
    _provider.text = d.provider ?? '';
    _serviceNumber.text = d.serviceNumber ?? '';
    _bookingRef.text = d.bookingReference ?? '';
    _bookingUrl.text = d.bookingUrl ?? '';
    _notes.text = d.notes ?? '';
    _locationName.text = d.location.name ?? '';
    _destinationName.text = d.destination.name ?? '';
    _timeTbd = existing != null && !existing.hasTime;
    if (d.startMinute == null || d.endMinute == null) {
      // Working values for the pickers only; saved as "no time" while _timeTbd is on.
      final defaults = _defaults(d.kind, d.date);
      d.startMinute = defaults.startMinute;
      d.endMinute = defaults.endMinute;
      if (d.kind.isStay) d.endDate ??= defaults.endDate;
    }
    setState(() {
      _d = d;
      _endTouched = existing != null;
    });
  }

  static ActivityDraft _defaults(ActivityKind kind, LocalDate date) {
    final d = ActivityDraft(title: '', kind: kind, date: date, startMinute: 9 * 60, endMinute: 10 * 60);
    _applyKindTiming(d);
    return d;
  }

  /// Sensible default durations per type; only used until the user sets an end.
  static void _applyKindTiming(ActivityDraft d) {
    if (d.kind.isStay) {
      d.startMinute = 15 * 60;
      d.endDate = d.date.addDays(1);
      d.endMinute = 11 * 60;
      return;
    }
    d.endDate = null;
    final length = switch (d.kind) {
      ActivityKind.food => 60,
      ActivityKind.flight => 180,
      ActivityKind.train || ActivityKind.bus => 120,
      ActivityKind.transfer => 30,
      ActivityKind.rest => 60,
      _ => 120,
    };
    final end = (d.startMinute ?? 9 * 60) + length;
    d.endMinute = end > 24 * 60 ? 24 * 60 : end;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _cost,
      _currency,
      _provider,
      _serviceNumber,
      _bookingRef,
      _bookingUrl,
      _notes,
      _locationName,
      _destinationName,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  GeoPoint? _nearPoint() {
    final acts = ref.read(tripActivitiesProvider(widget.tripId)).value ?? const [];
    for (final a in acts) {
      if (a.location.point != null) return a.location.point;
      if (a.destination.point != null) return a.destination.point;
    }
    return null;
  }

  Future<void> _save() async {
    final d = _d!;
    final l = context.l10n;
    d
      ..title = _title.text
      ..cost = _cost.text.trim().isEmpty ? null : double.tryParse(_cost.text.trim().replaceAll(',', ''))
      ..currency = _currency.text.trim().isEmpty ? null : _currency.text.trim().toUpperCase()
      ..provider = _provider.text
      ..serviceNumber = _serviceNumber.text
      ..bookingReference = _bookingRef.text
      ..bookingUrl = _bookingUrl.text
      ..notes = _notes.text
      ..location = PlaceRef(name: _blank(_locationName.text), point: d.location.point, source: d.location.source)
      ..destination = PlaceRef(
        name: _blank(_destinationName.text),
        point: d.destination.point,
        source: d.destination.source,
      );

    if (d.title.trim().isEmpty) return setState(() => _error = l.titleRequired);
    if (d.currency != null && !isValidCurrencyCode(d.currency!)) return setState(() => _error = l.currencyInvalid);
    if (_timeTbd) {
      d
        ..startMinute = null
        ..endMinute = null;
      if (d.endDate != null && d.endDate! < d.date) return setState(() => _error = l.endBeforeStart);
    } else {
      final endAbs = (d.endDate ?? d.date).epochDay * 1440 + d.endMinute!;
      if (endAbs <= d.date.epochDay * 1440 + d.startMinute!) return setState(() => _error = l.endBeforeStart);
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final svc = ref.read(itineraryServiceProvider);
      if (_isEdit) {
        await svc.updateActivity(widget.activityId!, d);
      } else {
        await svc.addActivity(widget.tripId, d);
      }
      if (mounted) Navigator.pop(context);
    } on DomainException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteActivityTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.actionDelete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(itineraryServiceProvider).deleteActivity(widget.activityId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editActivity : l.addActivity),
        actions: [
          if (_isEdit) IconButton(tooltip: l.actionDelete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: d == null || _saving ? null : _save, child: Text(l.actionSave)),
        ],
      ),
      body: d == null ? const Center(child: CircularProgressIndicator()) : _form(context, d),
    );
  }

  Widget _form(BuildContext context, ActivityDraft d) {
    final l = context.l10n;
    final c = context.colors;
    final theme = Theme.of(context);
    final trip = ref.watch(tripProvider(widget.tripId)).value?.trip;
    final isTransport = d.kind.isTransport;
    final isStay = d.kind.isStay;

    Future<void> pickDate({required bool end}) async {
      final initial = end ? (d.endDate ?? d.date) : d.date;
      final first = DateTime(initial.year - 2);
      final picked = await showDatePicker(
        context: context,
        firstDate: first,
        lastDate: DateTime(initial.year + 5),
        initialDate: initial.toDateTime(),
      );
      if (picked == null) return;
      setState(() {
        final v = LocalDate.fromDateTime(picked);
        if (end) {
          d.endDate = v == d.date ? null : v;
        } else {
          final shift = d.endDate == null ? 0 : d.date.daysUntil(d.endDate!);
          d.date = v;
          if (shift > 0) d.endDate = v.addDays(shift);
        }
      });
    }

    Future<void> pickTime({required bool end}) async {
      final m = end ? (d.endMinute == 1440 ? 1439 : d.endMinute!) : d.startMinute!;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      );
      if (picked == null) return;
      setState(() {
        final v = picked.hour * 60 + picked.minute;
        if (end) {
          d.endMinute = v == 0 && d.endDate == null ? 1440 : v;
          _endTouched = true;
        } else {
          final duration =
              (d.endDate ?? d.date).epochDay * 1440 + d.endMinute! - (d.date.epochDay * 1440 + d.startMinute!);
          d.startMinute = v;
          if (!_endTouched && !isStay) {
            final e = v + (duration > 0 ? duration : 60);
            d.endMinute = e > 1440 ? 1440 : e;
          }
        }
      });
    }

    // Label on its own line, then date + time; wraps on narrow screens and long labels.
    Widget whenRow(
      String label,
      LocalDate date,
      int minute, {
      required bool end,
      bool showDate = true,
      bool showTime = true,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge?.copyWith(color: c.ink2)),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (showDate)
              TextButton.icon(
                onPressed: () => pickDate(end: end),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(formatDate(context, date)),
              ),
            if (showTime)
              OutlinedButton(
                onPressed: () => pickTime(end: end),
                child: Text(minute == 1440 ? '24:00' : formatMinutes(minute)),
              )
            else
              Badge2(label: l.timeTbd, tone: Tone.warn, icon: Icons.schedule),
          ],
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        if (_error != null) ...[
          Badge2(label: _error!, tone: Tone.bad, icon: Icons.error_outline),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in ActivityKind.values)
              ChoiceChip(
                showCheckmark: false,
                avatar: Icon(k.icon, size: 18, color: d.kind == k ? k.color : c.ink3),
                label: Text(k.label(l)),
                selected: d.kind == k,
                onSelected: (_) => setState(() {
                  d.kind = k;
                  if (!_isEdit && !_endTouched) _applyKindTiming(d);
                  if (k.isStay && d.endDate == null) d.endDate = d.date.addDays(1);
                  if (!k.isStay && !_endTouched) d.endDate = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: !_isEdit,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.activityTitle),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l.fieldDate,
          icon: Icons.schedule,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.timeTbdToggle),
                subtitle: Text(l.timeTbdHelp),
                value: _timeTbd,
                onChanged: (v) => setState(() => _timeTbd = v),
              ),
              whenRow(isStay ? l.fieldCheckIn : l.fieldStart, d.date, d.startMinute!, end: false, showTime: !_timeTbd),
              const SizedBox(height: 4),
              if (!_timeTbd || isStay || d.endDate != null)
                whenRow(
                  isStay ? l.fieldCheckOut : l.fieldEnd,
                  d.endDate ?? d.date,
                  d.endMinute!,
                  end: true,
                  showTime: !_timeTbd,
                ),
              if (isStay && d.endDate != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Badge2(label: l.nightsCount(d.date.daysUntil(d.endDate!)), tone: Tone.brand),
                ),
              if (trip?.startDate != null && (d.date < trip!.startDate! || d.date > (trip.endDate ?? trip.startDate!)))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Badge2(label: l.outsideTrip, tone: Tone.warn, icon: Icons.warning_amber_rounded),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.fieldLocation,
          icon: Icons.place_outlined,
          child: Column(
            children: [
              _LocationField(
                label: isTransport ? l.fieldFrom : l.fieldLocation,
                controller: _locationName,
                place: d.location,
                onPick: () async {
                  final r = await pickLocation(
                    context,
                    initial: PlaceRef(
                      name: _blank(_locationName.text),
                      point: d.location.point,
                      source: d.location.source,
                    ),
                    near: d.location.point ?? _nearPoint(),
                  );
                  if (r != null) {
                    setState(() => d.location = r);
                    _locationName.text = r.name ?? '';
                  }
                },
              ),
              if (isTransport) ...[
                const SizedBox(height: 12),
                _LocationField(
                  label: l.fieldTo,
                  controller: _destinationName,
                  place: d.destination,
                  onPick: () async {
                    final r = await pickLocation(
                      context,
                      initial: PlaceRef(
                        name: _blank(_destinationName.text),
                        point: d.destination.point,
                        source: d.destination.source,
                      ),
                      near: d.destination.point ?? d.location.point ?? _nearPoint(),
                    );
                    if (r != null) {
                      setState(() => d.destination = r);
                      _destinationName.text = r.name ?? '';
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.fieldBooking,
          icon: Icons.confirmation_number_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cost,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l.fieldCost),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _currency,
                      maxLength: 3,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z]'))],
                      decoration: InputDecoration(labelText: l.fieldCurrency, counterText: ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in BookingStatus.values)
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(s.label(l)),
                      selected: d.bookingStatus == s,
                      onSelected: (_) => setState(() => d.bookingStatus = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _provider,
                decoration: InputDecoration(labelText: l.fieldProvider),
              ),
              if (isTransport) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _serviceNumber,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: l.fieldServiceNumber),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _bookingRef,
                decoration: InputDecoration(
                  labelText: l.fieldBookingRef,
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bookingUrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: l.fieldBookingUrl),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.fieldOptional),
          subtitle: Text(l.optionalHelp),
          value: d.isOptional,
          onChanged: (v) => setState(() => d.isOptional = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.fieldLocked),
          subtitle: Text(l.lockedHelp),
          value: d.isLocked,
          onChanged: (v) => setState(() => d.isLocked = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(labelText: l.fieldNotes),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l.actionSave)),
      ],
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({required this.label, required this.controller, required this.place, required this.onPick});

  final String label;
  final TextEditingController controller;
  final PlaceRef place;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Badge2(
              label: place.point == null ? l.notOnMap : l.onMap,
              tone: place.point == null ? Tone.neutral : Tone.good,
              icon: place.point == null ? Icons.location_off_outlined : Icons.location_on_outlined,
            ),
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(l.pickOnMap),
            ),
          ],
        ),
      ],
    );
  }
}

String? _blank(String s) => s.trim().isEmpty ? null : s.trim();
String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
