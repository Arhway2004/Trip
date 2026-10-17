import 'package:dio/dio.dart';
import 'package:wanderplan/contexts/places/application/route_service.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/contexts/places/infrastructure/osm_place_search.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Road routing with OSRM on OpenStreetMap data, hosted by FOSSGIS
/// (routing.openstreetmap.de: car, bike and foot profiles worldwide).
/// Policy: identifying User-Agent, at most one request per second, no bulk use.
class OsrmRouteService implements RouteService {
  OsrmRouteService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://routing.openstreetmap.de',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': osmUserAgent},
            ),
          );

  final Dio _dio;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static const source = 'routing:osrm-fossgis';

  @override
  String get attribution => 'OSRM · FOSSGIS · © OpenStreetMap contributors';

  static String _profile(TravelMode m) => switch (m) {
    TravelMode.walking => 'routed-foot',
    TravelMode.cycling => 'routed-bike',
    TravelMode.driving => 'routed-car',
  };

  @override
  Future<RouteResult> route(List<GeoPoint> waypoints, TravelMode mode) async {
    if (waypoints.length < 2) throw const RoutingException('At least two points are needed');
    final wait = const Duration(milliseconds: 1100) - DateTime.now().difference(_last);
    if (!wait.isNegative) await Future<void>.delayed(wait);
    _last = DateTime.now();
    final coords = waypoints
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    try {
      // FOSSGIS keeps OSRM's URL shape; the profile is chosen by the path prefix.
      final res = await _dio.get<Map<String, dynamic>>(
        '/${_profile(mode)}/route/v1/driving/$coords',
        queryParameters: {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
      );
      return parse(res.data ?? const {}, mode);
    } on DioException catch (e) {
      final code = (e.response?.data is Map) ? (e.response!.data as Map)['code'] : null;
      throw RoutingException('${code ?? e.message ?? 'Network error'}');
    }
  }

  /// Parses an OSRM `route` response (public for tests).
  static RouteResult parse(Map<String, dynamic> json, TravelMode mode) {
    if (json['code'] != 'Ok') throw RoutingException('${json['code'] ?? 'No route'}');
    final routes = (json['routes'] as List?) ?? const [];
    if (routes.isEmpty) throw const RoutingException('NoRoute');
    final r = routes.first as Map<String, dynamic>;
    final coords = ((r['geometry'] as Map?)?['coordinates'] as List?) ?? const [];
    final geometry = [
      for (final c in coords.cast<List<dynamic>>())
        ?GeoPoint.tryCreate((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
    if (geometry.length < 2) throw const RoutingException('Empty geometry');
    return RouteResult(
      geometry: geometry,
      distanceMeters: (r['distance'] as num).toDouble(),
      durationSeconds: (r['duration'] as num).toDouble(),
      mode: mode,
      source: source,
    );
  }
}
