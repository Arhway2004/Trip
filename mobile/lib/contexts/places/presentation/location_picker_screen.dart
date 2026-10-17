import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/presentation/map_tiles.dart';
import 'package:wanderplan/contexts/places/presentation/paste_location_dialog.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';

/// Lets the user choose a real location: tap the map to drop a pin or pick a
/// search result. Returns a [PlaceRef] with WGS84 coordinates (or null when
/// cancelled). The map provider follows the user's choice; "auto" uses Amap
/// around mainland China.
Future<PlaceRef?> pickLocation(BuildContext context, {PlaceRef initial = const PlaceRef(), GeoPoint? near}) =>
    Navigator.of(context).push<PlaceRef>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LocationPickerScreen(initial: initial, near: near),
      ),
    );

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, required this.initial, this.near});

  final PlaceRef initial;
  final GeoPoint? near;

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _map = MapController();
  late final _name = TextEditingController(text: widget.initial.name);
  final _query = TextEditingController();
  late GeoPoint? _point = widget.initial.point;
  late String? _source = widget.initial.source;
  List<PlaceResult> _results = const [];
  bool _searching = false;
  String? _error;
  bool _noResults = false;

  @override
  void dispose() {
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  late final MapProviderId _provider = resolveMapProvider(
    ref.read(mapProviderPreferenceProvider),
    points: [?widget.initial.point ?? widget.near],
  );

  /// Searches only when submitted: the OSM search policy forbids search-as-you-type.
  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _noResults = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _noResults = false;
    });
    try {
      final r = await ref
          .read(mapServicesProvider)
          .searchFor(_provider)
          .search(
            q,
            languageCode: Localizations.localeOf(context).languageCode,
            near: _provider.fromScreen(_map.camera.center),
          );
      if (mounted) {
        setState(() {
          _results = r;
          _noResults = r.isEmpty;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _choose(PlaceResult r) {
    FocusScope.of(context).unfocus();
    setState(() {
      _point = r.point;
      _source = r.source;
      _results = const [];
      _noResults = false;
      if (_name.text.trim().isEmpty || _name.text == widget.initial.name) _name.text = r.name;
    });
    _map.move(_provider.toScreen(r.point), 16);
  }

  Future<void> _paste() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final r = await showPasteLocationDialog(context, near: _point ?? widget.near);
    if (r == null || !mounted) return;
    setState(() {
      _point = r.point;
      _source = r.source;
      _results = const [];
      _noResults = false;
    });
    _map.move(_provider.toScreen(r.point), 16);
    final note = resolvedLocationNote(l, r);
    if (note != null) messenger.showSnackBar(SnackBar(content: Text(note)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final center = _point ?? widget.near;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.chooseLocation),
        actions: [
          IconButton(tooltip: l.pasteLocation, icon: const Icon(Icons.add_link), onPressed: _paste),
          if (_point != null)
            IconButton(
              tooltip: l.removePin,
              icon: const Icon(Icons.location_off_outlined),
              onPressed: () => setState(() {
                _point = null;
                _source = null;
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.searchPlaces,
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center == null ? const LatLng(20, 100) : _provider.toScreen(center),
                    initialZoom: center == null ? 3 : 14,
                    minZoom: _provider == MapProviderId.amap ? 3 : 2,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onTap: (_, ll) => setState(() {
                      _point = _provider.fromScreen(ll);
                      _source = 'map';
                      _results = const [];
                      _noResults = false;
                    }),
                  ),
                  children: [
                    if (ref.watch(mapTilesEnabledProvider)) providerTileLayer(_provider),
                    if (_point != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _provider.toScreen(_point!),
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: Icon(Icons.location_pin, size: 44, color: c.accent),
                          ),
                        ],
                      ),
                    providerAttribution(_provider),
                  ],
                ),
                if (_results.isNotEmpty || _error != null || _noResults)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 0,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(14),
                      color: c.surface,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: _error != null
                            ? ListTile(leading: const Icon(Icons.cloud_off), title: Text(l.searchFailed(_error!)))
                            : _noResults
                            ? ListTile(leading: const Icon(Icons.search_off), title: Text(l.noResults))
                            : ListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                children: [
                                  for (final r in _results)
                                    ListTile(
                                      leading: const Icon(Icons.place_outlined),
                                      title: Text(r.name),
                                      subtitle: Text(r.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      onTap: () => _choose(r),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                    child: Text(
                                      ref.read(mapServicesProvider).searchFor(_provider).attribution,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.ink3),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _point == null ? l.pickHint : _point.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.ink3),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l.placeName),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(l.useThisPlace),
                    onPressed: _point == null && _name.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            PlaceRef(
                              name: _name.text.trim().isEmpty ? null : _name.text.trim(),
                              point: _point,
                              source: _point == null ? null : _source,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
