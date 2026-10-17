import 'package:wanderplan/contexts/places/application/place_search.dart';
import 'package:wanderplan/contexts/places/application/route_service.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Chooses the search and routing adapters for the map provider in use.
///
/// Amap's web services need a key (`--dart-define=AMAP_WEB_KEY=…`). Without
/// one, the Amap map still draws its tiles, and search and routing fall back
/// to the OpenStreetMap services. The screen says so ([usesFallbackFor]).
class MapServices {
  MapServices({
    required PlaceSearch osmSearch,
    required RouteService osmRouting,
    PlaceSearch? amapSearch,
    RouteService? amapRouting,
  }) : _osmSearch = osmSearch,
       _osmRouting = osmRouting,
       _amapSearch = amapSearch,
       _amapRouting = amapRouting;

  final PlaceSearch _osmSearch;
  final RouteService _osmRouting;
  final PlaceSearch? _amapSearch;
  final RouteService? _amapRouting;
  final _routeCache = <String, RouteResult>{};

  bool get amapServicesConfigured => _amapSearch != null && _amapRouting != null;

  /// True when [provider] is drawn but its own web services aren't available.
  bool usesFallbackFor(MapProviderId provider) => provider == MapProviderId.amap && !amapServicesConfigured;

  PlaceSearch searchFor(MapProviderId provider) =>
      provider == MapProviderId.amap ? (_amapSearch ?? _osmSearch) : _osmSearch;

  RouteService routingFor(MapProviderId provider) =>
      provider == MapProviderId.amap ? (_amapRouting ?? _osmRouting) : _osmRouting;

  /// Routes through [waypoints], remembering results for this session so
  /// switching days doesn't call the provider again (and respects its limits).
  Future<RouteResult> route(MapProviderId provider, List<GeoPoint> waypoints, TravelMode mode) async {
    final service = routingFor(provider);
    final key = '${service.attribution}|${mode.name}|${waypoints.join(';')}';
    if (_routeCache[key] case final cached?) return cached;
    final r = await service.route(waypoints, mode);
    if (_routeCache.length > 200) _routeCache.remove(_routeCache.keys.first);
    return _routeCache[key] = r;
  }

  /// Travel times between all [points]. Transit, failures and offline use
  /// straight-line estimates, flagged as such in the result.
  Future<TravelMatrix> matrix(MapProviderId provider, List<GeoPoint> points, TravelMode mode) async {
    if (!mode.isRouted || points.length < 2) return estimateMatrix(points, mode);
    try {
      final m = await routingFor(provider).matrix(points, mode);
      // Fill gaps (no route between two points) with estimates.
      final est = estimateMatrix(points, mode);
      return TravelMatrix(
        [
          for (var i = 0; i < points.length; i++)
            [for (var j = 0; j < points.length; j++) m.seconds[i][j] ?? est.seconds[i][j]],
        ],
        source: m.source,
        estimated: false,
      );
    } catch (_) {
      return estimateMatrix(points, mode);
    }
  }
}
