import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/contexts/itinerary/presentation/navigation_links.dart';
import 'package:wanderplan/contexts/places/application/saved_place_service.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/saved_place.dart';
import 'package:wanderplan/contexts/places/presentation/place_category_ui.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

/// Details of a place on the map: a search/nearby result, a pin the user
/// dropped (source `map`, name editable) or a saved place. Lets the user save
/// or remove it, put it on a day of the plan, and navigate there.
Future<void> showPlaceSheet(
  BuildContext context, {
  required String tripId,
  PlaceResult? result,
  SavedPlace? saved,
}) {
  assert((result == null) != (saved == null));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlaceSheet(tripId: tripId, result: result, saved: saved, outer: context),
  );
}

/// Human-readable origin of a place's coordinates.
String coordinateSourceLabel(AppLocalizations l, String? source) {
  if (source == null) return l.sourcePinned;
  if (source == 'import') return l.sourceImported;
  if (source == 'pluscode') return l.sourcePlusCode;
  if (source == 'coordinates') return l.sourceCoordinates;
  if (source.startsWith('link:')) {
    return l.sourceLink(switch (source) {
      'link:amap' => 'Amap',
      'link:apple' => 'Apple Maps',
      _ => 'Google Maps',
    });
  }
  if (source.startsWith('search:amap')) return l.sourceSearch('Amap');
  if (source.startsWith('search:')) return l.sourceSearch('OpenStreetMap');
  return l.sourcePinned;
}

class _PlaceSheet extends ConsumerStatefulWidget {
  const _PlaceSheet({required this.tripId, required this.outer, this.result, this.saved});

  final String tripId;
  final PlaceResult? result;
  final SavedPlace? saved;

  /// The map screen's context, for snackbars after the sheet closes.
  final BuildContext outer;

  @override
  ConsumerState<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<_PlaceSheet> {
  late final _name = TextEditingController(text: widget.saved?.name ?? widget.result!.name);
  late PlaceCategory _category = widget.saved?.category ?? widget.result!.category ?? PlaceCategory.attraction;

  /// A pin or pasted location without a provider name: the user names it.
  bool get _isDroppedPin => widget.saved == null && widget.result!.name.isEmpty;
  GeoPoint get _point => widget.saved?.point ?? widget.result!.point;
  String? get _source => widget.saved?.source ?? widget.result!.source;
  String? get _address {
    final String? a = widget.saved != null ? widget.saved!.address : widget.result!.address;
    return a == null || a.isEmpty ? null : a;
  }

  String get _currentName => _name.text.trim().isEmpty ? context.l10n.mapPinnedPlace : _name.text.trim();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Saved version of this place (it may have been saved earlier from search).
  SavedPlace? _savedMatch(List<SavedPlace> all) {
    if (widget.saved != null) return all.where((p) => p.id == widget.saved!.id).firstOrNull ?? widget.saved;
    final n = widget.result!.name.toLowerCase();
    return all.where((p) => p.name.toLowerCase() == n && p.point.distanceKmTo(_point) < 0.03).firstOrNull;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(widget.outer);
    final l = context.l10n;
    await ref
        .read(savedPlaceServiceProvider)
        .savePlace(
          widget.tripId,
          SavedPlaceDraft(
            name: _currentName,
            point: _point,
            category: _category,
            address: _address,
            source: _source,
          ),
        );
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(l.placeSaved)));
  }

  Future<void> _remove(SavedPlace p) async {
    final messenger = ScaffoldMessenger.of(widget.outer);
    final l = context.l10n;
    final service = ref.read(savedPlaceServiceProvider);
    await service.removePlace(p.id);
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.placeRemoved),
        action: SnackBarAction(label: l.undo, onPressed: () => service.restorePlace(p)),
      ),
    );
  }

  /// Puts the place on a day as an activity without a time (never guessed).
  Future<void> _addToDay() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(widget.outer);
    final days = ref.read(dayAssessmentsProvider(widget.tripId)).map((d) => d.date).toList();
    LocalDate? day;
    if (days.isEmpty) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
        initialDate: now,
      );
      day = picked == null ? null : LocalDate.fromDateTime(picked);
    } else {
      day = await showModalBottomSheet<LocalDate>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(l.chooseDay, style: Theme.of(c).textTheme.titleMedium)),
              for (var i = 0; i < days.length; i++)
                ListTile(
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  title: Text(formatDate(context, days[i])),
                  onTap: () => Navigator.pop(c, days[i]),
                ),
            ],
          ),
        ),
      );
    }
    if (day == null || !mounted) return;
    final dateText = formatDate(context, day);
    await ref
        .read(itineraryServiceProvider)
        .addActivity(
          widget.tripId,
          ActivityDraft(
            title: _currentName,
            kind: _category.activityKind,
            date: day,
            location: PlaceRef(name: _currentName, point: _point, source: _source ?? 'map'),
            notes: _address,
          ),
        );
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(l.addedToDay(dateText))));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final saved = _savedMatch(ref.watch(savedPlacesProvider(widget.tripId)).value ?? const []);
    final acts = ref.watch(tripActivitiesProvider(widget.tripId)).value ?? const <Activity>[];
    final here = PlaceRef(name: _currentName, point: _point);
    final planned = {
      for (final a in acts)
        if (!a.isCancelled && (a.location.sameAs(here) || (a.kind.isTransport && a.destination.sameAs(here)))) a.date,
    }.toList()..sort();
    final verified = (_source?.startsWith('search:') ?? false) || (_source?.startsWith('link:') ?? false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_category.icon, color: c.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isDroppedPin && saved == null
                        ? TextField(
                            controller: _name,
                            autofocus: true,
                            decoration: InputDecoration(labelText: l.placeName, hintText: l.mapPinnedPlace),
                          )
                        : Text(saved?.name ?? _currentName, style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Badge2(
                    label: coordinateSourceLabel(l, _source),
                    tone: verified ? Tone.good : Tone.neutral,
                    icon: verified ? Icons.verified_outlined : Icons.push_pin_outlined,
                  ),
                  if (saved != null) Badge2(label: l.placeSaved, tone: Tone.brand, icon: Icons.bookmark),
                ],
              ),
              if (_address != null) ...[
                const SizedBox(height: 8),
                Text(_address!, style: TextStyle(color: c.ink2)),
              ],
              const SizedBox(height: 4),
              Text(_point.toString(), style: TextStyle(fontSize: 11, color: c.ink3)),
              const SizedBox(height: 8),
              Text(
                planned.isEmpty ? l.notPlanned : l.plannedOn(planned.map((d) => formatDate(context, d)).join(', ')),
                style: TextStyle(color: planned.isEmpty ? c.ink3 : c.ink2, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final cat in PlaceCategory.values)
                    ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(cat.icon, size: 16),
                      label: Text(cat.label(l)),
                      selected: (saved?.category ?? _category) == cat,
                      onSelected: (_) {
                        setState(() => _category = cat);
                        if (saved != null) ref.read(savedPlaceServiceProvider).updatePlace(saved.id, category: cat);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (saved == null)
                    FilledButton.icon(icon: const Icon(Icons.bookmark_add_outlined), label: Text(l.savePlace), onPressed: _save)
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.bookmark_remove_outlined),
                      label: Text(l.removePlace),
                      onPressed: () => _remove(saved),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(l.addToDay),
                    onPressed: _addToDay,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.navigation_outlined),
                    label: Text(l.navigateWith),
                    onPressed: () {
                      Navigator.pop(context);
                      showNavigateSheet(widget.outer, _point, _currentName);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
