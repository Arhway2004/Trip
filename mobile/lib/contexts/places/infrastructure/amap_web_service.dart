import 'package:dio/dio.dart';
import 'package:wanderplan/contexts/places/application/place_search.dart';
import 'package:wanderplan/contexts/places/application/route_service.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Amap (Gaode) Web Service APIs: POI search (v5) and route planning (v3/v4).
/// Needs a "Web 服务" key from the Amap Open Platform. Amap speaks GCJ-02, so
/// every point is converted on the way in and out; the app stores WGS84.
class AmapWebService implements PlaceSearch, RouteService {
  AmapWebService(this._key, [Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://restapi.amap.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  final String _key;
  final Dio _dio;

  static const searchSource = 'search:amap';
  static const routeSource = 'routing:amap';

  /// Amap POI type codes (Amap POI classification table).
  static const _types = <PlaceCategory, String>{
    PlaceCategory.attraction: '110000',
    PlaceCategory.restaurant: '050000',
    PlaceCategory.hotel: '100000',
    PlaceCategory.airport: '150104',
    PlaceCategory.railwayStation: '150200',
    PlaceCategory.busStation: '150400',
  };

  @override
  String get attribution => '© AutoNavi / Amap (高德地图)';

  static String _lngLat(GeoPoint wgs) {
    final g = Gcj02.fromWgs84(wgs);
    return '${g.longitude.toStringAsFixed(6)},${g.latitude.toStringAsFixed(6)}';
  }

  /// "lng,lat" in GCJ-02 → WGS84.
  static GeoPoint? _point(Object? s) {
    final parts = '${s ?? ''}'.split(',');
    if (parts.length != 2) return null;
    final p = GeoPoint.tryCreate(double.tryParse(parts[1]), double.tryParse(parts[0]));
    return p == null ? null : Gcj02.toWgs84(p);
  }

  /// Amap returns `[]` instead of an empty string for missing text fields.
  static String _text(Object? v) => v is String ? v : '';

  Future<Map<String, dynamic>> _get(String path, Map<String, Object> params) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path, queryParameters: {...params, 'key': _key});
      return res.data ?? const {};
    } on DioException catch (e) {
      throw PlaceSearchException(e.message ?? 'Network error');
    }
  }

  // --- Search ---------------------------------------------------------------

  @override
  Future<List<PlaceResult>> search(String query, {String? languageCode, GeoPoint? near, int limit = 8}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final json = await _get('/v5/place/text', {'keywords': q, 'page_size': limit.clamp(1, 25)});
    return parsePois(json);
  }

  @override
  Future<List<PlaceResult>> nearby(
    GeoPoint center,
    PlaceCategory category, {
    String? languageCode,
    int? radiusMeters,
    int limit = 30,
  }) async {
    final type = _types[category];
    if (type == null) return const [];
    final json = await _get('/v5/place/around', {
      'location': _lngLat(center),
      'types': type,
      'radius': (radiusMeters ?? category.nearbyRadiusMeters).clamp(0, 50000),
      'page_size': limit.clamp(1, 25),
    });
    return parsePois(json, category: category);
  }

  /// Parses a v5 POI response (public for tests).
  static List<PlaceResult> parsePois(Map<String, dynamic> json, {PlaceCategory? category}) {
    if ('${json['status']}' != '1') throw PlaceSearchException('${json['info'] ?? 'Amap error'}');
    return [
      for (final poi in ((json['pois'] as List?) ?? const []).cast<Map<String, dynamic>>())
        if (_point(poi['location']) case final p?)
          PlaceResult(
            name: _text(poi['name']),
            address: [
              _text(poi['pname']),
              _text(poi['cityname']),
              _text(poi['adname']),
              _text(poi['address']),
            ].where((s) => s.isNotEmpty).toSet().join(' '),
            point: p,
            source: searchSource,
            category: category ?? _categoryOf(_text(poi['typecode'])),
          ),
    ];
  }

  static PlaceCategory? _categoryOf(String typecode) {
    if (typecode.startsWith('11')) return PlaceCategory.attraction;
    if (typecode.startsWith('05')) return PlaceCategory.restaurant;
    if (typecode.startsWith('10')) return PlaceCategory.hotel;
    if (typecode.startsWith('1501')) return PlaceCategory.airport;
    if (typecode.startsWith('1502')) return PlaceCategory.railwayStation;
    if (typecode.startsWith('1504')) return PlaceCategory.busStation;
    return null;
  }

  // --- Routing --------------------------------------------------------------

  @override
  Future<RouteResult> route(List<GeoPoint> waypoints, TravelMode mode) async {
    if (waypoints.length < 2) throw const RoutingException('At least two points are needed');
    // Walking and cycling take one origin/destination pair per request.
    final legs = <RouteResult>[];
    for (var i = 0; i + 1 < waypoints.length; i++) {
      final params = {'origin': _lngLat(waypoints[i]), 'destination': _lngLat(waypoints[i + 1])};
      final Map<String, dynamic> json;
      try {
        json = await _get(switch (mode) {
          TravelMode.walking => '/v3/direction/walking',
          TravelMode.driving => '/v3/direction/driving',
          TravelMode.cycling => '/v4/direction/bicycling',
        }, params);
      } on PlaceSearchException catch (e) {
        throw RoutingException(e.message);
      }
      legs.add(parseRoute(json, mode));
    }
    return RouteResult(
      geometry: [for (final l in legs) ...l.geometry],
      distanceMeters: legs.fold(0, (s, l) => s + l.distanceMeters),
      durationSeconds: legs.fold(0, (s, l) => s + l.durationSeconds),
      mode: mode,
      source: routeSource,
    );
  }

  /// Parses a v3 (walking/driving) or v4 (bicycling) direction response.
  static RouteResult parseRoute(Map<String, dynamic> json, TravelMode mode) {
    final Map<String, dynamic>? container;
    if (json.containsKey('errcode')) {
      if ('${json['errcode']}' != '0') throw RoutingException('${json['errmsg'] ?? 'Amap error'}');
      container = json['data'] as Map<String, dynamic>?;
    } else {
      if ('${json['status']}' != '1') throw RoutingException('${json['info'] ?? 'Amap error'}');
      container = json['route'] as Map<String, dynamic>?;
    }
    final paths = (container?['paths'] as List?) ?? const [];
    if (paths.isEmpty) throw const RoutingException('No route');
    final path = paths.first as Map<String, dynamic>;
    final geometry = <GeoPoint>[
      for (final step in ((path['steps'] as List?) ?? const []).cast<Map<String, dynamic>>())
        for (final pair in _text(step['polyline']).split(';')) ?_point(pair),
    ];
    if (geometry.length < 2) throw const RoutingException('Empty geometry');
    return RouteResult(
      geometry: geometry,
      distanceMeters: double.tryParse('${path['distance']}') ?? 0,
      durationSeconds: double.tryParse('${path['duration']}') ?? 0,
      mode: mode,
      source: routeSource,
    );
  }
}
