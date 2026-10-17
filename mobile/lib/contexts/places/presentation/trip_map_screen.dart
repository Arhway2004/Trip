import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/domain/day_route.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_l10n.dart';
import 'package:wanderplan/contexts/itinerary/presentation/itinerary_providers.dart';
import 'package:wanderplan/contexts/itinerary/presentation/navigation_links.dart';
import 'package:wanderplan/contexts/places/application/location_service.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/contexts/places/domain/saved_place.dart';
import 'package:wanderplan/contexts/places/domain/location_link.dart';
import 'package:wanderplan/contexts/places/presentation/map_tiles.dart';
import 'package:wanderplan/contexts/places/presentation/paste_location_dialog.dart';
import 'package:wanderplan/contexts/places/presentation/pin_clusters.dart';
import 'package:wanderplan/contexts/places/presentation/place_category_ui.dart';
import 'package:wanderplan/contexts/places/presentation/place_sheet.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

/// How a piece of the day's route is drawn.
enum _LegStyle {
  /// Real road route from a routing provider.
  routed,

  /// No road route available: straight line, labelled unverified.
  unverified,

  /// Booked flight/train/ferry: direct line, not its real path.
  booked,
}

class _LegDraw {
  const _LegDraw(this.points, this.style, [this.color]);
  final List<GeoPoint> points;
  final _LegStyle style;
  final Color? color;
}

class _RouteState {
  const _RouteState({
    this.draws = const [],
    this.loading = false,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.unverifiedLegs = 0,
    this.bookedLegs = 0,
    this.sources = const {},
  });
  final List<_LegDraw> draws;
  final bool loading;
  final double distanceMeters;
  final double durationSeconds;
  final int unverifiedLegs;
  final int bookedLegs;
  final Set<String> sources;
}

/// A marker on the map (activity pin, saved place, search result, me).
class _Pin {
  const _Pin(this.point, this.child, this.onTap, {this.size = 36, this.label = '', this.icon, this.cluster = true});
  final GeoPoint point;
  final Widget child;
  final VoidCallback? onTap;
  final double size;

  /// Shown in the list when several pins share one spot.
  final String label;
  final IconData? icon;

  /// False for markers that must stay separate (my location).
  final bool cluster;
}

/// The trip's real-world map (spec §9): plan pins per day with real road
/// routes, saved places, place search, "explore nearby", marker filters,
/// current location and external navigation. Provider: OpenStreetMap
/// worldwide, Amap (GCJ-02) for mainland China.
class TripMapScreen extends ConsumerStatefulWidget {
  const TripMapScreen({super.key, required this.tripId, this.initialDay});
  final String tripId;
  final LocalDate? initialDay;

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  final _map = MapController();
  final _query = TextEditingController();
  late LocalDate? _day = widget.initialDay;
  TravelMode _mode = TravelMode.walking;
  bool _mapReady = false;
  bool _fitted = false;

  // Search & explore.
  List<PlaceResult> _results = const [];
  bool _showResultList = false;
  PlaceCategory? _nearby;
  bool _searching = false;
  String? _searchError;
  bool _noResults = false;

  // Filters.
  final _hiddenKinds = <ActivityKind>{};
  final _hiddenCategories = <PlaceCategory>{};
  bool _showSaved = true;
  bool _showResults = true;

  GeoPoint? _me;
  bool _locating = false;

  /// Current map zoom, for clustering overlapping markers.
  double _zoom = 3;

  String? _routeKey;
  _RouteState _route = const _RouteState();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  // --- Data -----------------------------------------------------------------

  List<Activity> _activities() =>
      (ref.watch(tripActivitiesProvider(widget.tripId)).value ?? const <Activity>[])
          .where((a) => !a.isCancelled)
          .toList();

  List<SavedPlace> _saved() => ref.watch(savedPlacesProvider(widget.tripId)).value ?? const [];

  MapProviderId _provider(List<Activity> acts, List<SavedPlace> saved) {
    final trip = ref.watch(tripProvider(widget.tripId)).value?.trip;
    return resolveMapProvider(
      ref.watch(mapProviderPreferenceProvider),
      points: [
        for (final a in acts) ...[?a.location.point, ?a.destination.point],
        for (final p in saved) p.point,
      ],
      countries: [for (final d in trip?.destinations ?? const []) d.country],
    );
  }

  // --- Camera ---------------------------------------------------------------

  void _fit(MapProviderId provider, List<GeoPoint> points) {
    if (!_mapReady || points.isEmpty) return;
    if (points.length == 1) {
      _map.move(provider.toScreen(points.first), 15);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final p in points) provider.toScreen(p)],
        padding: const EdgeInsets.fromLTRB(48, 150, 48, 200),
        maxZoom: 16,
        minZoom: provider == MapProviderId.amap ? 3 : 2,
      ),
    );
  }

  GeoPoint _center(MapProviderId provider) => provider.fromScreen(_map.camera.center);

  // --- Routes ---------------------------------------------------------------

  /// Fetches road routes for the day's legs. Consecutive road legs travelled
  /// the same way go in one request; failures fall back to straight lines
  /// that are labelled unverified, never to an invented road.
  Future<void> _loadRoute(String key, DayRoutePlan plan, MapProviderId provider, TravelMode mode) async {
    setState(() => _route = const _RouteState(loading: true));
    final maps = ref.read(mapServicesProvider);
    final draws = <_LegDraw>[];
    var distance = 0.0, duration = 0.0, unverified = 0, booked = 0;
    final sources = <String>{};

    var i = 0;
    while (i < plan.legs.length) {
      final leg = plan.legs[i];
      if (leg.kind == DayLegKind.booked) {
        draws.add(_LegDraw([leg.from.point, leg.to.point], _LegStyle.booked, leg.from.activity.kind.color));
        booked++;
        i++;
        continue;
      }
      if (leg.kind == DayLegKind.undecided) {
        draws.add(_LegDraw([leg.from.point, leg.to.point], _LegStyle.unverified));
        unverified++;
        i++;
        continue;
      }
      final runMode = leg.fixedMode ?? mode;
      final run = <DayLeg>[leg];
      while (i + run.length < plan.legs.length) {
        final next = plan.legs[i + run.length];
        if (next.kind != DayLegKind.road || (next.fixedMode ?? mode) != runMode) break;
        run.add(next);
      }
      i += run.length;
      try {
        final r = await maps.route(provider, [run.first.from.point, for (final l in run) l.to.point], runMode);
        draws.add(_LegDraw(r.geometry, _LegStyle.routed));
        distance += r.distanceMeters;
        duration += r.durationSeconds;
        sources.add(maps.routingFor(provider).attribution);
      } catch (_) {
        for (final l in run) {
          draws.add(_LegDraw([l.from.point, l.to.point], _LegStyle.unverified));
        }
        unverified += run.length;
      }
      if (!mounted || _routeKey != key) return;
    }
    if (!mounted || _routeKey != key) return;
    setState(
      () => _route = _RouteState(
        draws: draws,
        distanceMeters: distance,
        durationSeconds: duration,
        unverifiedLegs: unverified,
        bookedLegs: booked,
        sources: sources,
      ),
    );
  }

  void _scheduleRoute(DayRoutePlan? plan, MapProviderId provider) {
    final key = plan == null || plan.legs.isEmpty
        ? null
        : '${provider.name}|${_mode.name}|${plan.legs.map((l) => '${l.from.point}>${l.to.point}:${l.kind.name}').join(',')}';
    if (key == _routeKey) return;
    _routeKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _routeKey != key) return;
      if (key == null) {
        setState(() => _route = const _RouteState());
      } else {
        _loadRoute(key, plan!, provider, _mode);
      }
    });
  }

  // --- Search, explore, location -------------------------------------------

  Future<void> _run(MapProviderId provider, Future<List<PlaceResult>> Function() search, {required bool list}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      _noResults = false;
    });
    try {
      final r = await search();
      if (!mounted) return;
      setState(() {
        _results = r;
        _noResults = r.isEmpty;
        _showResultList = list && r.isNotEmpty;
        _showResults = true;
      });
      if (r.isNotEmpty && !list) _fit(provider, [for (final p in r) p.point]);
    } catch (e) {
      if (mounted) setState(() => _searchError = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _search(MapProviderId provider, String q) {
    if (q.trim().length < 2) return;
    // A pasted Google Maps link, coordinates or Plus Code goes straight to a pin.
    if (parseLocationText(q) != null) {
      _openPasted(provider, q);
      return;
    }
    setState(() => _nearby = null);
    final lang = Localizations.localeOf(context).languageCode;
    _run(
      provider,
      () => ref.read(mapServicesProvider).searchFor(provider).search(q, languageCode: lang, near: _center(provider)),
      list: true,
    );
  }

  Future<void> _openPasted(MapProviderId provider, String text) async {
    FocusScope.of(context).unfocus();
    final r = await showPasteLocationDialog(context, near: _center(provider), initialText: text.trim().isEmpty ? null : text.trim());
    if (r == null || !mounted) return;
    _query.clear();
    _map.move(provider.toScreen(r.point), 16);
    final note = resolvedLocationNote(context.l10n, r);
    if (note != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
    await showPlaceSheet(
      context,
      tripId: widget.tripId,
      result: PlaceResult(name: '', address: '', point: r.point, source: r.source),
    );
  }

  void _explore(MapProviderId provider, PlaceCategory category) {
    if (_nearby == category) {
      _clearResults();
      return;
    }
    setState(() => _nearby = category);
    final lang = Localizations.localeOf(context).languageCode;
    final center = _center(provider);
    _run(
      provider,
      () => ref.read(mapServicesProvider).searchFor(provider).nearby(center, category, languageCode: lang),
      list: false,
    );
  }

  void _clearResults() => setState(() {
    _results = const [];
    _nearby = null;
    _showResultList = false;
    _noResults = false;
    _searchError = null;
    _query.clear();
  });

  Future<void> _locate(MapProviderId provider) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      final me = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() => _me = me);
      _map.move(provider.toScreen(me), 15);
    } on LocationException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.failure) {
            LocationFailure.serviceDisabled => l.locationOff,
            LocationFailure.denied => l.locationDenied,
            LocationFailure.deniedForever => l.locationDeniedForever,
            LocationFailure.unavailable => l.locationUnavailable,
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final summary = ref.watch(tripProvider(widget.tripId)).value;
    final acts = _activities();
    final saved = _saved();
    final provider = _provider(acts, saved);
    final maps = ref.watch(mapServicesProvider);
    final days = ref.watch(dayAssessmentsProvider(widget.tripId)).map((d) => d.date).toList();
    final plan = _day == null ? null : planDayRoute(acts, _day!);
    _scheduleRoute(plan, provider);

    final presentKinds = {for (final a in acts) a.kind}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final pins = _buildPins(context, provider, acts, saved, plan);
    final missing = plan?.missingLocation.length ??
        acts.where((a) => a.location.point == null && !(a.kind.isTransport && a.destination.point != null)).length;
    final everything = [for (final p in pins) p.point];

    if (!_fitted && _mapReady && everything.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(provider, everything));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(summary == null ? l.tabMap : '${l.tabMap} · ${summary.trip.title}'),
        actions: [
          IconButton(
            tooltip: l.savedPlaces,
            icon: Badge(
              isLabelVisible: saved.isNotEmpty,
              label: Text('${saved.length}'),
              child: const Icon(Icons.bookmarks_outlined),
            ),
            onPressed: () => _showSavedList(context, provider, saved),
          ),
          IconButton(
            tooltip: l.filterMarkers,
            icon: Icon(
              _hiddenKinds.isEmpty && _hiddenCategories.isEmpty && _showSaved && _showResults
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt,
            ),
            onPressed: () => _showFilters(context, presentKinds),
          ),
          PopupMenuButton<MapProviderPreference>(
            tooltip: l.mapProvider,
            icon: const Icon(Icons.layers_outlined),
            initialValue: ref.watch(mapProviderPreferenceProvider),
            onSelected: (p) {
              ref.read(mapProviderPreferenceProvider.notifier).set(p);
              _fitted = false;
            },
            itemBuilder: (_) => [
              for (final p in MapProviderPreference.values)
                CheckedPopupMenuItem(
                  value: p,
                  checked: ref.read(mapProviderPreferenceProvider) == p,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.label(l)),
                    subtitle: p == MapProviderPreference.auto ? Text(l.providerAutoHelp) : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _dayChip(l.mapAllDays, null),
                for (final d in days) _dayChip(DateFormat.MMMd(context.localeTag).format(d.toDateTime()), d),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: const LatLng(20, 100),
                    initialZoom: 3,
                    // No tiles exist below these zooms (Amap starts at 3); zooming out further
                    // only showed a grey, repeating world.
                    minZoom: provider == MapProviderId.amap ? 3 : 2,
                    maxZoom: 19,
                    // Rotation was easy to trigger by accident while pinching.
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onPositionChanged: (camera, _) {
                      if ((camera.zoom - _zoom).abs() < 0.25) return;
                      // Re-cluster markers for the new zoom after this frame.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _zoom = camera.zoom);
                      });
                    },
                    onMapReady: () {
                      _mapReady = true;
                      if (everything.isNotEmpty) {
                        _fitted = true;
                        _fit(provider, everything);
                      }
                    },
                    onTap: (_, _) => setState(() => _showResultList = false),
                    onLongPress: (_, ll) => showPlaceSheet(
                      context,
                      tripId: widget.tripId,
                      result: PlaceResult(name: '', address: '', point: provider.fromScreen(ll), source: 'map'),
                    ),
                  ),
                  children: [
                    if (ref.watch(mapTilesEnabledProvider)) providerTileLayer(provider),
                    PolylineLayer(polylines: [for (final d in _route.draws) _polyline(provider, d, c)]),
                    MarkerLayer(markers: _markers(context, provider, pins)),
                    providerAttribution(provider),
                  ],
                ),
                Positioned(left: 12, right: 12, top: 8, child: _searchPanel(context, provider)),
                Positioned(
                  right: 12,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'fit',
                        tooltip: l.fitAll,
                        onPressed: () => _fit(provider, everything),
                        child: const Icon(Icons.fit_screen_outlined),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'me',
                        tooltip: l.myLocation,
                        onPressed: _locating ? null : () => _locate(provider),
                        child: _locating
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _infoPanel(context, provider, maps.usesFallbackFor(provider), plan, pins.isEmpty, missing),
        ],
      ),
    );
  }

  Widget _dayChip(String label, LocalDate? day) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: _day == day,
      onSelected: (_) => setState(() {
        _day = day;
        _fitted = false;
      }),
    ),
  );

  Polyline _polyline(MapProviderId provider, _LegDraw d, AppColors c) {
    final pts = [for (final p in d.points) provider.toScreen(p)];
    return switch (d.style) {
      _LegStyle.routed => Polyline(
        points: pts,
        strokeWidth: 4.5,
        color: c.brand,
        borderStrokeWidth: 1.5,
        borderColor: Colors.white,
      ),
      _LegStyle.unverified => Polyline(
        points: pts,
        strokeWidth: 3,
        color: c.ink3,
        pattern: StrokePattern.dashed(segments: const [10, 8]),
      ),
      _LegStyle.booked => Polyline(
        points: pts,
        strokeWidth: 3,
        color: d.color ?? c.info,
        pattern: const StrokePattern.dotted(spacingFactor: 2),
      ),
    };
  }

  // --- Pins -----------------------------------------------------------------

  List<_Pin> _buildPins(
    BuildContext context,
    MapProviderId provider,
    List<Activity> acts,
    List<SavedPlace> saved,
    DayRoutePlan? plan,
  ) {
    final pins = <_Pin>[];
    bool visible(Activity a) => !_hiddenKinds.contains(a.kind);

    if (plan == null) {
      for (final a in acts.where(visible)) {
        if (a.location.point != null) {
          pins.add(
            _Pin(
              a.location.point!,
              _kindDot(a.kind),
              () => _showActivity(context, a, a.location),
              label: _pinLabel(a, a.location),
              icon: a.kind.icon,
            ),
          );
        }
        if (a.kind.isTransport && a.destination.point != null) {
          pins.add(
            _Pin(
              a.destination.point!,
              _kindDot(a.kind),
              () => _showActivity(context, a, a.destination),
              label: _pinLabel(a, a.destination),
              icon: a.kind.icon,
            ),
          );
        }
      }
    } else {
      for (var i = 0; i < plan.stops.length; i++) {
        final s = plan.stops[i];
        if (!visible(s.activity)) continue;
        final place = s.isArrival ? s.activity.destination : s.activity.location;
        pins.add(
          _Pin(
            s.point,
            _numberDot(s.activity.kind, i + 1),
            () => _showActivity(context, s.activity, place),
            label: '${i + 1}. ${_pinLabel(s.activity, place)}',
            icon: s.activity.kind.icon,
          ),
        );
      }
      for (final s in plan.unordered.where((s) => visible(s.activity))) {
        final place = s.isArrival ? s.activity.destination : s.activity.location;
        pins.add(
          _Pin(
            s.point,
            _kindDot(s.activity.kind, outlined: true),
            () => _showActivity(context, s.activity, place),
            label: _pinLabel(s.activity, place),
            icon: s.activity.kind.icon,
          ),
        );
      }
    }

    if (_showSaved) {
      for (final p in saved.where((p) => !_hiddenCategories.contains(p.category))) {
        pins.add(
          _Pin(
            p.point,
            _placeBadge(p.category, saved: true),
            () => showPlaceSheet(context, tripId: widget.tripId, saved: p),
            size: 34,
            label: p.name,
            icon: p.category.icon,
          ),
        );
      }
    }
    if (_showResults) {
      for (final r in _results.where((r) => r.category == null || !_hiddenCategories.contains(r.category))) {
        pins.add(
          _Pin(
            r.point,
            _placeBadge(r.category ?? PlaceCategory.other, saved: false),
            () => showPlaceSheet(context, tripId: widget.tripId, result: r),
            size: 32,
            label: r.name,
            icon: (r.category ?? PlaceCategory.other).icon,
          ),
        );
      }
    }
    if (_me != null) pins.add(_Pin(_me!, _meDot(), null, size: 22, cluster: false));
    return pins;
  }

  String _pinLabel(Activity a, PlaceRef place) =>
      [a.title, if (place.name != null && place.name != a.title) place.name!].join(' · ');

  /// Markers that would overlap at the current zoom become one numbered
  /// cluster; tapping it zooms in, or lists the items when they share a spot.
  List<Marker> _markers(BuildContext context, MapProviderId provider, List<_Pin> pins) {
    final groups = clusterByScreen(pins.where((p) => p.cluster).toList(), (p) {
      final s = provider.toScreen(p.point);
      return (s.latitude, s.longitude);
    }, _zoom);
    Marker single(_Pin p) => Marker(
      point: provider.toScreen(p.point),
      width: p.size,
      height: p.size,
      child: GestureDetector(onTap: p.onTap, child: p.child),
    );
    return [
      for (final g in groups)
        if (g.length == 1)
          single(g.single)
        else
          Marker(
            point: provider.toScreen(g.first.point),
            width: 42,
            height: 42,
            child: GestureDetector(onTap: () => _openCluster(context, provider, g), child: _clusterDot(g.length)),
          ),
      for (final p in pins.where((p) => !p.cluster)) single(p),
    ];
  }

  void _openCluster(BuildContext context, MapProviderId provider, List<_Pin> group) {
    final spread = group.map((p) => p.point.distanceKmTo(group.first.point)).reduce(math.max);
    if (spread > 0.05) {
      _fit(provider, [for (final p in group) p.point]);
      return;
    }
    // Same spot (e.g. several flights at one airport): list them.
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in group)
              ListTile(
                leading: Icon(p.icon ?? Icons.place_outlined),
                title: Text(p.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(c);
                  p.onTap?.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _clusterDot(int n) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.brand,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }

  Widget _kindDot(ActivityKind kind, {bool outlined = false}) => Container(
    decoration: BoxDecoration(
      color: outlined ? Colors.white : kind.color,
      shape: BoxShape.circle,
      border: Border.all(color: outlined ? kind.color : Colors.white, width: 2.5),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
    ),
    alignment: Alignment.center,
    child: Icon(kind.icon, size: 16, color: outlined ? kind.color : Colors.white),
  );

  Widget _numberDot(ActivityKind kind, int n) => Container(
    decoration: BoxDecoration(
      color: kind.color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
    ),
    alignment: Alignment.center,
    child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
  );

  Widget _placeBadge(PlaceCategory cat, {required bool saved}) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: saved ? c.accent : c.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: saved ? Colors.white : c.ink2, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: Icon(cat.icon, size: 16, color: saved ? Colors.white : c.ink),
    );
  }

  Widget _meDot() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1A73E8),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x551A73E8), blurRadius: 10, spreadRadius: 4)],
    ),
  );

  // --- Panels ---------------------------------------------------------------

  Widget _searchPanel(BuildContext context, MapProviderId provider) {
    final l = context.l10n;
    final c = context.colors;
    final search = ref.read(mapServicesProvider).searchFor(provider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(14),
          color: c.surface,
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.searchPlaces,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : (_results.isNotEmpty || _query.text.isNotEmpty)
                  ? IconButton(tooltip: l.actionCancel, icon: const Icon(Icons.close), onPressed: _clearResults)
                  : IconButton(
                      tooltip: l.pasteLocation,
                      icon: const Icon(Icons.add_link),
                      onPressed: () => _openPasted(provider, ''),
                    ),
            ),
            onSubmitted: (q) => _search(provider, q),
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final cat in PlaceCategory.explorable)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(cat.icon, size: 16),
                    label: Text(cat.label(l)),
                    selected: _nearby == cat,
                    backgroundColor: c.surface,
                    onSelected: _searching ? null : (_) => _explore(provider, cat),
                  ),
                ),
            ],
          ),
        ),
        if (_searchError != null || _noResults || (_showResultList && _results.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              color: c.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: _searchError != null
                    ? ListTile(leading: const Icon(Icons.cloud_off), title: Text(l.searchFailed(_searchError!)))
                    : _noResults
                    ? ListTile(
                        leading: const Icon(Icons.search_off),
                        title: Text(_nearby == null ? l.noResults : l.nearbyEmpty),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final r in _results)
                            ListTile(
                              dense: true,
                              leading: Icon((r.category ?? PlaceCategory.other).icon),
                              title: Text(r.name),
                              subtitle: Text(r.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                setState(() => _showResultList = false);
                                _map.move(provider.toScreen(r.point), 16);
                                showPlaceSheet(context, tripId: widget.tripId, result: r);
                              },
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Text(search.attribution, style: TextStyle(fontSize: 11, color: c.ink3)),
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoPanel(
    BuildContext context,
    MapProviderId provider,
    bool fallback,
    DayRoutePlan? plan,
    bool empty,
    int missing,
  ) {
    final l = context.l10n;
    final c = context.colors;
    final small = TextStyle(fontSize: 12, color: c.ink2);
    final hasRoute = plan != null && plan.legs.isNotEmpty;
    return Material(
      color: c.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 230),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasRoute) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<TravelMode>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          segments: [
                            for (final m in TravelMode.values)
                              ButtonSegment(value: m, icon: Icon(m.icon, size: 18), tooltip: m.label(l)),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (s) => setState(() => _mode = s.first),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_route.loading)
                        Row(
                          children: [
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 6),
                            Text(l.routeLoading, style: small),
                          ],
                        )
                      else if (_route.distanceMeters > 0)
                        Text(
                          l.routeTotal(
                            _km(_route.distanceMeters),
                            formatDuration(l, (_route.durationSeconds / 60).round()),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_route.sources.isNotEmpty) Text(l.routeEstimateNote(_route.sources.join(', ')), style: small),
                  if (_route.unverifiedLegs > 0) ...[
                    const SizedBox(height: 4),
                    Badge2(label: l.routeUnverified(_route.unverifiedLegs), tone: Tone.warn, icon: Icons.warning_amber),
                  ],
                  if (_route.bookedLegs > 0) Text(l.routeBooked, style: small),
                  Text(l.routeNoTransit, style: TextStyle(fontSize: 11, color: c.ink3)),
                ],
                if (plan != null && plan.unordered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l.routeUnordered(plan.unordered.length), style: small),
                  ),
                if (empty) Text(l.mapEmpty, style: small),
                if (missing > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Badge2(label: l.mapNoPins(missing), tone: Tone.warn, icon: Icons.location_off_outlined),
                        FilledButton.tonalIcon(
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.travel_explore, size: 18),
                          label: Text(l.findLocations),
                          onPressed: () => context.push(Routes.locatePlaces(widget.tripId)),
                        ),
                      ],
                    ),
                  ),
                if (fallback)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l.amapNoKey, style: small),
                  ),
                const SizedBox(height: 4),
                Text('${provider.label(l)} · ${l.mapLongPressHint} · ${l.mapOnlineNote}', style: TextStyle(fontSize: 11, color: c.ink3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _km(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${NumberFormat('#,##0.0', context.localeTag).format(meters / 1000)} km';

  // --- Sheets ---------------------------------------------------------------

  Future<void> _showFilters(BuildContext context, List<ActivityKind> kinds) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) {
        final l = context.l10n;
        void update(VoidCallback f) {
          setState(f);
          setSheet(() {});
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.filterMarkers, style: Theme.of(c).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(l.layerPlan, style: Theme.of(c).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in kinds)
                      FilterChip(
                        avatar: Icon(k.icon, size: 16),
                        label: Text(k.label(l)),
                        selected: !_hiddenKinds.contains(k),
                        onSelected: (v) => update(() => v ? _hiddenKinds.remove(k) : _hiddenKinds.add(k)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.savedPlaces),
                  value: _showSaved,
                  onChanged: (v) => update(() => _showSaved = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.layerResults),
                  value: _showResults,
                  onChanged: (v) => update(() => _showResults = v),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cat in PlaceCategory.values)
                      FilterChip(
                        avatar: Icon(cat.icon, size: 16),
                        label: Text(cat.label(l)),
                        selected: !_hiddenCategories.contains(cat),
                        onSelected: (v) => update(() => v ? _hiddenCategories.remove(cat) : _hiddenCategories.add(cat)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _showSavedList(BuildContext context, MapProviderId provider, List<SavedPlace> saved) {
    final l = context.l10n;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(l.savedPlaces, style: Theme.of(c).textTheme.titleMedium)),
              if (saved.isEmpty) ListTile(title: Text(l.savedPlacesEmpty)),
              for (final cat in PlaceCategory.values)
                for (final p in saved.where((p) => p.category == cat))
                  ListTile(
                    leading: Icon(p.category.icon),
                    title: Text(p.name),
                    subtitle: Text(
                      [p.category.label(l), ?p.address].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(c);
                      setState(() => _showSaved = true);
                      _map.move(provider.toScreen(p.point), 16);
                      showPlaceSheet(context, tripId: widget.tripId, saved: p);
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActivity(BuildContext context, Activity a, PlaceRef place) {
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(a.kind.icon, color: a.kind.color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.title, style: Theme.of(c).textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 4),
              Text([formatDate(context, a.date), activityTimeText(l, a), ?place.name].join(' · ')),
              const SizedBox(height: 4),
              Text(coordinateSourceLabel(l, place.source), style: TextStyle(fontSize: 12, color: context.colors.ink3)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.navigation_outlined),
                      label: Text(l.navigateWith),
                      onPressed: () {
                        Navigator.pop(c);
                        showNavigateSheet(context, place.point!, place.name ?? a.title);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.actionEdit),
                    onPressed: () {
                      Navigator.pop(c);
                      context.push(Routes.editActivity(widget.tripId, a.id));
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

