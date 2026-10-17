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
    TravelMode.transit => throw const RoutingException('Public transport is not routed'),
  };

  Future<void> _pace() async {
    final wait = const Duration(milliseconds: 1100) - DateTime.now().difference(_last);
    if (!wait.isNegative) await Future<void>.delayed(wait);
    _last = DateTime.now();
  }

  static String _coords(List<GeoPoint> points) =>
      points.map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}').join(';');

  @override
  Future<TravelMatrix> matrix(List<GeoPoint> points, TravelMode mode) async {
    if (points.length < 2) throw const RoutingException('At least two points are needed');
    final profile = _profile(mode);
    await _pace();
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/$profile/table/v1/driving/${_coords(points)}',
        queryParameters: {'annotations': 'duration'},
      );
      return parseTable(res.data ?? const {});
    } on DioException catch (e) {
      throw RoutingException(e.message ?? 'Network error');
    }
  }

  /// Parses an OSRM `table` response (public for tests).
  static TravelMatrix parseTable(Map<String, dynamic> json) {
    if (json['code'] != 'Ok') throw RoutingException('${json['code'] ?? 'No table'}');
    final rows = (json['durations'] as List?) ?? const [];
    return TravelMatrix(
      [
        for (final row in rows.cast<List<dynamic>>()) [for (final v in row) (v as num?)?.toDouble()],
      ],
      source: source,
      estimated: false,
    );
  }

  @override
  Future<RouteResult> route(List<GeoPoint> waypoints, TravelMode mode) async {
    if (waypoints.length < 2) throw const RoutingException('At least two points are needed');
    final profile = _profile(mode);
    await _pace();
    final coords = _coords(waypoints);
    try {
      // FOSSGIS keeps OSRM's URL shape; the profile is chosen by the path prefix.
      final res = await _dio.get<Map<String, dynamic>>(
        '/$profile/route/v1/driving/$coords',
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
      legs: [
        for (final l in ((r['legs'] as List?) ?? const []).cast<Map<String, dynamic>>())
          ((l['distance'] as num).toDouble(), (l['duration'] as num).toDouble()),
      ],
    );
  }
}
