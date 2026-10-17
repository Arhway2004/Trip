import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/unlocated_places.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/contexts/places/application/place_search.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/domain/place_lookup.dart';
import 'package:wanderplan/contexts/places/presentation/location_picker_screen.dart';
import 'package:wanderplan/contexts/places/presentation/paste_location_dialog.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

enum _Status { waiting, searching, done, failed, located }

class _Row {
  _Row(this.place) : query = placeQueryVariants(place.name).firstOrNull ?? place.name;
  final UnlocatedPlace place;
  String query;
  _Status status = _Status.waiting;
  List<RankedPlace> matches = const [];
  int? selected;
  String? error;
  bool get placeholder => looksLikePlaceholder(place.name);
}

/// Finds coordinates for activities that only have a place name (e.g. a trip
/// imported from a file). Each name is searched once; matches are ranked by
/// distance to the trip's destinations and nothing is changed until the user
/// accepts a match. Generic names ("Kunming hotel") are never pre-selected.
class LocatePlacesScreen extends ConsumerStatefulWidget {
  const LocatePlacesScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<LocatePlacesScreen> createState() => _LocatePlacesScreenState();
}

class _LocatePlacesScreenState extends ConsumerState<LocatePlacesScreen> {
  List<_Row>? _rows;
  List<GeoPoint> _destinations = const [];
  MapProviderId _provider = MapProviderId.openStreetMap;
  bool _running = false;
  bool _cancelled = false;

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  PlaceSearch get _search => ref.read(mapServicesProvider).searchFor(_provider);
  String get _lang => Localizations.localeOf(context).languageCode;

  /// Builds the list once the plan has loaded, then searches in the background.
  void _start(List<Activity> acts, Trip trip) {
    if (_rows != null) return;
    _provider = resolveMapProvider(
      ref.read(mapProviderPreferenceProvider),
      countries: [for (final d in trip.destinations) d.country],
    );
    _rows = [for (final p in unlocatedPlaces(acts)) _Row(p)];
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchAll(trip.destinations));
  }

  Future<void> _searchAll(List<Destination> destinations) async {
    setState(() => _running = true);
    // Locate the trip's destination cities first, to rank matches by them.
    final points = <GeoPoint>[];
    for (final d in destinations) {
      final q = [?d.city, ?d.country].where((s) => s.trim().isNotEmpty).join(', ');
      if (q.isEmpty || _cancelled) continue;
      try {
        final r = await _search.search(q, languageCode: _lang, limit: 1);
        if (r.isNotEmpty) points.add(r.first.point);
      } catch (_) {
        // Ranking simply has fewer anchors.
      }
    }
    if (_cancelled) return;
    setState(() => _destinations = points);
    for (final row in _rows!) {
      if (_cancelled) return;
      await _searchRow(row);
    }
    if (mounted) setState(() => _running = false);
  }

  Future<void> _searchRow(_Row row, {String? custom}) async {
    setState(() {
      row.status = _Status.searching;
      row.error = null;
      if (custom != null) row.query = custom;
    });
    try {
      var results = const <RankedPlace>[];
      for (final q in custom != null ? [custom] : placeQueryVariants(row.place.name)) {
        if (_cancelled) return;
        final found = await _search.search(q, languageCode: _lang, limit: 6);
        if (found.isNotEmpty) {
          row.query = q;
          results = rankByDestinations(found, _destinations);
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        row.matches = results;
        row.status = _Status.done;
        final best = results.firstOrNull;
        row.selected = best != null && best.isNearDestination && !row.placeholder ? 0 : null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          row.status = _Status.failed;
          row.error = '$e';
        });
      }
    }
  }

  Future<void> _accept(_Row row, GeoPoint point, String source) async {
    await ref.read(itineraryServiceProvider).locateByName(widget.tripId, row.place.name, point, source);
    if (mounted) setState(() => row.status = _Status.located);
  }

  Future<void> _acceptAll() async {
    for (final row in _rows!.where((r) => r.status == _Status.done && r.selected != null)) {
      final m = row.matches[row.selected!].place;
      await _accept(row, m.point, m.source);
    }
  }

  Future<void> _refine(_Row row) async {
    final q = await showDialog<String>(context: context, builder: (_) => _RefineDialog(initial: row.query));
    if (q != null && q.trim().length >= 2) await _searchRow(row, custom: q.trim());
  }

  Future<void> _pick(_Row row) async {
    final near = row.selected != null
        ? row.matches[row.selected!].place.point
        : row.matches.firstOrNull?.place.point ?? _destinations.firstOrNull;
    final r = await pickLocation(context, initial: PlaceRef(name: row.place.name), near: near);
    if (r?.point != null) await _accept(row, r!.point!, r.source ?? 'map');
  }

  Future<void> _pasteLink(_Row row) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final r = await showPasteLocationDialog(
      context,
      near: row.matches.firstOrNull?.place.point ?? _destinations.firstOrNull,
    );
    if (r == null) return;
    await _accept(row, r.point, r.source);
    final note = resolvedLocationNote(l, r);
    if (note != null) messenger.showSnackBar(SnackBar(content: Text('${row.place.name}: $note')));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final acts = ref.watch(tripActivitiesProvider(widget.tripId)).value;
    final trip = ref.watch(tripProvider(widget.tripId)).value?.trip;
    // Both are needed: destinations rank the matches.
    if (acts != null && trip != null) _start(acts, trip);
    final rows = _rows;
    final searched = rows?.where((r) => r.status != _Status.waiting && r.status != _Status.searching).length ?? 0;
    final ready = rows?.where((r) => r.status == _Status.done && r.selected != null).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(l.locateTitle)),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
          ? Center(child: Text(l.locateAllDone))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Text(l.locateIntro, style: TextStyle(color: c.ink2)),
                const SizedBox(height: 8),
                if (_running) ...[
                  LinearProgressIndicator(value: rows.isEmpty ? null : searched / rows.length),
                  const SizedBox(height: 4),
                  Text(l.locateProgress(searched, rows.length), style: TextStyle(fontSize: 12, color: c.ink3)),
                ],
                const SizedBox(height: 8),
                for (final row in rows) _rowCard(context, row),
                const SizedBox(height: 8),
                Text(_search.attribution, style: TextStyle(fontSize: 11, color: c.ink3)),
              ],
            ),
      bottomNavigationBar: rows == null || rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.done_all),
                  label: Text(l.locateUseAll(ready)),
                  onPressed: ready == 0 ? null : _acceptAll,
                ),
              ),
            ),
    );
  }

  Widget _rowCard(BuildContext context, _Row row) {
    final l = context.l10n;
    final c = context.colors;
    final titles = row.place.activities.map((a) => a.title).toSet().take(3).join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(row.place.name, style: Theme.of(context).textTheme.titleSmall)),
                if (row.status == _Status.located) Badge2(label: l.locateLocated, tone: Tone.good, icon: Icons.check),
                if (row.status == _Status.searching)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            Text(
              '${l.locateUsedBy(row.place.activities.length)} · $titles',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.ink3),
            ),
            if (row.placeholder && row.status != _Status.located)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Badge2(label: l.locatePlaceholder, tone: Tone.warn, icon: Icons.help_outline),
              ),
            if (row.status == _Status.failed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.searchFailed(row.error ?? ''), style: TextStyle(color: c.bad, fontSize: 13)),
              ),
            if (row.status == _Status.done && row.matches.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.locateNoMatch(row.query), style: TextStyle(color: c.ink2, fontSize: 13)),
              ),
            if (row.status == _Status.done && row.matches.isNotEmpty)
              RadioGroup<int>(
                groupValue: row.selected,
                onChanged: (v) => setState(() => row.selected = v),
                child: Column(
                  children: [
                    for (var i = 0; i < row.matches.length && i < 4; i++)
                      RadioListTile<int>(
                        value: i,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(row.matches[i].place.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.matches[i].place.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (!row.matches[i].isNearDestination)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Badge2(
                                  label: l.locateFar(row.matches[i].kmToDestination!.round()),
                                  tone: Tone.warn,
                                  icon: Icons.wrong_location_outlined,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (row.status == _Status.done || row.status == _Status.failed || row.status == _Status.waiting)
              Wrap(
                spacing: 4,
                children: [
                  if (row.selected != null)
                    FilledButton.tonal(
                      onPressed: () {
                        final m = row.matches[row.selected!].place;
                        _accept(row, m.point, m.source);
                      },
                      child: Text(l.locateUse),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(l.locateSearchAgain),
                    onPressed: () => _refine(row),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_link, size: 18),
                    label: Text(l.pasteLink),
                    onPressed: () => _pasteLink(row),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: Text(l.pickOnMap),
                    onPressed: () => _pick(row),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// "Search again" with a custom text. Owns its controller so it is disposed
/// only after the dialog's closing animation, never while still on screen.
class _RefineDialog extends StatefulWidget {
  const _RefineDialog({required this.initial});
  final String initial;

  @override
  State<_RefineDialog> createState() => _RefineDialogState();
}

class _RefineDialogState extends State<_RefineDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.locateSearchAgain),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(helperText: l.locateRefineHelp),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(l.locateSearch)),
      ],
    );
  }
}
