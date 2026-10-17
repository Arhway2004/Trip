import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/image_pick.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/time_zone_picker.dart';
import 'package:wanderplan/shared/domain/currency.dart';
import 'package:wanderplan/contexts/trip/application/trip_draft.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';

/// Creates a trip (when [tripId] is null) or edits an existing one.
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.tripId});

  final String? tripId;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _DestinationFields {
  _DestinationFields([Destination? d])
    : country = TextEditingController(text: d?.country),
      city = TextEditingController(text: d?.city);
  final TextEditingController country;
  final TextEditingController city;

  void dispose() {
    country.dispose();
    city.dispose();
  }
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _currency = TextEditingController();
  final _budget = TextEditingController();
  final List<_DestinationFields> _destinations = [_DestinationFields()];

  late TripDraft _draft = TripDraft(title: '', timeZone: ref.read(deviceTimeZoneProvider));
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.tripId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final details = await ref.read(tripServiceProvider).getTrip(widget.tripId!);
    if (!mounted) return;
    if (details != null) {
      final d = TripDraft.fromTrip(details);
      _title.text = d.title;
      _description.text = d.description ?? '';
      _currency.text = d.currency ?? '';
      _budget.text = d.totalBudget == null ? '' : _trimNumber(d.totalBudget!);
      for (final f in _destinations) {
        f.dispose();
      }
      _destinations
        ..clear()
        ..addAll(d.destinations.map(_DestinationFields.new));
      if (_destinations.isEmpty) _destinations.add(_DestinationFields());
      _draft = d;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _currency.dispose();
    _budget.dispose();
    for (final f in _destinations) {
      f.dispose();
    }
    super.dispose();
  }

  void _touch(VoidCallback fn) => setState(() {
    fn();
    _dirty = true;
  });

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final l = context.l10n;
    _draft
      ..title = _title.text
      ..description = _description.text
      ..currency = _currency.text.trim().isEmpty ? null : _currency.text.trim().toUpperCase()
      ..totalBudget = _budget.text.trim().isEmpty ? null : double.parse(_budget.text.trim().replaceAll(',', ''))
      ..destinations = _destinations.map((f) => Destination(country: f.country.text, city: f.city.text)).toList();

    setState(() => _saving = true);
    try {
      final repo = ref.read(tripServiceProvider);
      if (_isEdit) {
        await repo.updateTrip(widget.tripId!, _draft);
        if (mounted) context.pop();
      } else {
        final id = await repo.createTrip(_draft);
        if (mounted) context.go(Routes.trip(id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.saveFailed('$e'))));
        setState(() => _saving = false);
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    final l = context.l10n;
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.discardChangesTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.keepEditing)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.discard)),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l.editTrip : l.newTrip),
          actions: [TextButton(onPressed: _saving || _loading ? null : _save, child: Text(l.actionSave))],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                onChanged: () => _dirty = true,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    TextFormField(
                      controller: _title,
                      autofocus: !_isEdit,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: l.fieldTitle, hintText: l.fieldTitleHint),
                      validator: (v) => (v == null || v.trim().isEmpty) ? l.titleRequired : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      minLines: 2,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: l.fieldDescription, helperText: l.optional),
                    ),
                    _Section(l.sectionCover),
                    _buildCover(context),
                    _Section(l.sectionDestinations),
                    ..._buildDestinations(context),
                    _Section(l.sectionDates),
                    ..._buildDates(context),
                    _Section(l.sectionDetails),
                    ..._buildDetails(context),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_isEdit ? l.saveTripChanges : l.saveTripCreate),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final l = context.l10n;
    final picked = _draft.coverImageSourcePath;
    Future<void> pick(ImageSource source) async {
      final path = await pickSingleImage(context, source);
      if (path != null) _touch(() => _draft.coverImageSourcePath = path);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (picked != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(aspectRatio: 2, child: Image.file(File(picked), fit: BoxFit.cover, cacheWidth: 800)),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_outlined),
              label: Text(l.coverPick),
            ),
            OutlinedButton.icon(
              onPressed: () => pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l.coverCamera),
            ),
            if (picked != null)
              TextButton(onPressed: () => _touch(() => _draft.coverImageSourcePath = null), child: Text(l.coverRemove)),
          ],
        ),
        Text(l.coverHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  List<Widget> _buildDestinations(BuildContext context) {
    final l = context.l10n;
    return [
      for (var i = 0; i < _destinations.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _destinations[i].city,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l.fieldCity, helperText: i == 0 ? l.mainDestination : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _destinations[i].country,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l.fieldCountry),
                ),
              ),
              IconButton(
                tooltip: l.removeDestination,
                onPressed: _destinations.length == 1 ? null : () => _touch(() => _destinations.removeAt(i).dispose()),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => _touch(() => _destinations.add(_DestinationFields())),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(l.addDestination),
        ),
      ),
    ];
  }

  List<Widget> _buildDates(BuildContext context) {
    final l = context.l10n;
    final d = _draft;
    final time = parseTimeOfDay(d.departureTime);
    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(d.startDate == null ? l.pickDates : formatDateRange(context, d.startDate, d.endDate)),
              onPressed: () async {
                final now = DateTime.now();
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 30),
                  lastDate: DateTime(now.year + 30),
                  initialDateRange: d.startDate == null
                      ? null
                      : DateTimeRange(start: d.startDate!.toDateTime(), end: (d.endDate ?? d.startDate!).toDateTime()),
                );
                if (range != null) {
                  _touch(() {
                    d.startDate = LocalDate.fromDateTime(range.start);
                    d.endDate = LocalDate.fromDateTime(range.end);
                  });
                }
              },
            ),
          ),
          if (d.startDate != null)
            IconButton(
              tooltip: l.clearDates,
              icon: const Icon(Icons.clear),
              onPressed: () => _touch(() {
                d.startDate = null;
                d.endDate = null;
                d.departureTime = null;
                d.datesConfirmed = false;
              }),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.datesConfirmed),
        subtitle: Text(l.datesConfirmedHelp),
        value: d.datesConfirmed,
        onChanged: d.startDate == null ? null : (v) => _touch(() => d.datesConfirmed = v),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: d.startDate != null,
        leading: const Icon(Icons.schedule),
        title: Text(l.departureTime),
        subtitle: Text(time == null ? '${l.notSet} · ${l.optional}' : formatTimeOfDay(time.$1, time.$2)),
        trailing: time == null
            ? null
            : IconButton(icon: const Icon(Icons.clear), onPressed: () => _touch(() => d.departureTime = null)),
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: time.$1, minute: time.$2),
          );
          if (picked != null) _touch(() => d.departureTime = formatTimeOfDay(picked.hour, picked.minute));
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.public),
        title: Text(l.fieldTimeZone),
        subtitle: Text('${d.timeZone.replaceAll('_', ' ')} (${utcOffsetLabel(d.timeZone)})\n${l.timeZoneHelp}'),
        isThreeLine: true,
        onTap: () async {
          final z = await showTimeZonePicker(context, current: d.timeZone);
          if (z != null) _touch(() => d.timeZone = z);
        },
      ),
    ];
  }

  List<Widget> _buildDetails(BuildContext context) {
    final l = context.l10n;
    final d = _draft;
    return [
      Row(
        children: [
          Expanded(child: Text(l.fieldTravelers, style: Theme.of(context).textTheme.bodyLarge)),
          IconButton.outlined(
            onPressed: d.travelerCount <= 1 ? null : () => _touch(() => d.travelerCount--),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${d.travelerCount}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton.outlined(
            onPressed: d.travelerCount >= 999 ? null : () => _touch(() => d.travelerCount++),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: _currency.text),
              optionsBuilder: (v) {
                final q = v.text.trim().toUpperCase();
                return q.isEmpty ? const Iterable.empty() : isoCurrencyCodes.where((c) => c.startsWith(q));
              },
              onSelected: (c) => _currency.text = c,
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextFormField(
                controller: controller,
                focusNode: focus,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z]'))],
                decoration: InputDecoration(labelText: l.fieldCurrency, counterText: ''),
                onChanged: (v) => _currency.text = v,
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return _budget.text.trim().isEmpty ? null : l.budgetNeedsCurrency;
                  return isValidCurrencyCode(s) ? null : l.currencyInvalid;
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.fieldBudget, helperText: l.optional),
              validator: (v) {
                final s = (v ?? '').trim().replaceAll(',', '');
                if (s.isEmpty) return null;
                final n = double.tryParse(s);
                return (n == null || n < 0) ? l.budgetInvalid : null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(l.fieldTravelStyle, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final s in TravelStyle.values)
            ChoiceChip(
              label: Text(s.label(l)),
              selected: d.travelStyle == s,
              onSelected: (sel) => _touch(() => d.travelStyle = sel ? s : null),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(l.fieldStage, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<TripStage>(
        segments: [for (final s in TripStage.values) ButtonSegment(value: s, label: Text(s.label(l)))],
        selected: {d.stage},
        onSelectionChanged: (s) => _touch(() => d.stage = s.first),
      ),
      const SizedBox(height: 4),
      Text(l.stageHelp, style: Theme.of(context).textTheme.bodySmall),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
  );
}

String _trimNumber(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
