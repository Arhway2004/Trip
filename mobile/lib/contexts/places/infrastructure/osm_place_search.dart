import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:wanderplan/contexts/places/application/place_search.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Identifying User-Agent required by the OpenStreetMap service policies.
const osmUserAgent = 'WanderPlan/1.0 (personal travel planner; Flutter)';

/// OpenStreetMap Nominatim geocoding, used worldwide.
///
/// Follows the Nominatim usage policy: identifying User-Agent, at most one
/// request per second, searches only when the user submits (no autocomplete).
/// "Nearby" uses Nominatim's category phrases inside a bounded box. The public
/// Overpass API was evaluated but asks apps not to rely on it.
class OsmPlaceSearch implements PlaceSearch {
  OsmPlaceSearch([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'User-Agent': osmUserAgent},
            ),
          );

  final Dio _dio;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static const source = 'search:openstreetmap-nominatim';

  /// Category phrases understood by Nominatim, and the OSM tags accepted back.
  static const _phrases = <PlaceCategory, List<String>>{
    PlaceCategory.attraction: ['attraction', 'museum'],
    PlaceCategory.restaurant: ['restaurant'],
    PlaceCategory.hotel: ['hotel'],
    PlaceCategory.airport: ['airport'],
    PlaceCategory.railwayStation: ['railway station'],
    PlaceCategory.busStation: ['bus station'],
  };

  @override
  String get attribution => '© OpenStreetMap contributors · Nominatim';

  @override
  Future<List<PlaceResult>> search(String query, {String? languageCode, GeoPoint? near, int limit = 8}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final rows = await _get({
      'q': q,
      'limit': limit,
      // Prefer results around the visible area without excluding the rest.
      if (near != null) 'viewbox': _viewbox(near, 50000),
    }, languageCode);
    return [for (final r in rows) ?_parse(r)];
  }

  @override
  Future<List<PlaceResult>> nearby(
    GeoPoint center,
    PlaceCategory category, {
    String? languageCode,
    int? radiusMeters,
    int limit = 30,
  }) async {
    final phrases = _phrases[category];
    if (phrases == null) return const [];
    final radius = radiusMeters ?? category.nearbyRadiusMeters;
    final byKey = <String, PlaceResult>{};
    for (final phrase in phrases) {
      final rows = await _get({
        'q': phrase,
        'viewbox': _viewbox(center, radius),
        'bounded': 1,
        'limit': 40,
      }, languageCode);
      for (final r in rows) {
        final p = _parse(r);
        if (p == null || p.category != category) continue; // Drop loose phrase matches (e.g. a street).
        if (p.point.distanceKmTo(center) * 1000 > radius) continue; // Box corners are outside the circle.
        byKey['${p.name}|${p.point}'] = p;
      }
    }
    final list = byKey.values.toList()
      ..sort((a, b) => a.point.distanceKmTo(center).compareTo(b.point.distanceKmTo(center)));
    return list.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> _get(Map<String, Object> params, String? languageCode) async {
    final wait = const Duration(milliseconds: 1100) - DateTime.now().difference(_last);
    if (!wait.isNegative) await Future<void>.delayed(wait);
    _last = DateTime.now();
    try {
      final res = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {...params, 'format': 'jsonv2', 'addressdetails': 0, 'accept-language': ?languageCode},
      );
      return (res.data ?? const []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw PlaceSearchException(e.message ?? 'Network error');
    }
  }

  static String _viewbox(GeoPoint c, int radiusMeters) {
    final dLat = radiusMeters / 111320.0;
    final dLng = radiusMeters / (111320.0 * math.max(0.01, math.cos(c.latitude * math.pi / 180)));
    String f(double v) => v.toStringAsFixed(5);
    return '${f(c.longitude - dLng)},${f(c.latitude + dLat)},${f(c.longitude + dLng)},${f(c.latitude - dLat)}';
  }

  static PlaceResult? _parse(Map<String, dynamic> r) {
    final p = GeoPoint.tryCreate(double.tryParse('${r['lat']}'), double.tryParse('${r['lon']}'));
    if (p == null) return null;
    final display = '${r['display_name'] ?? ''}';
    final name = (r['name'] as String?)?.trim();
    return PlaceResult(
      name: name != null && name.isNotEmpty ? name : display.split(',').first,
      address: display,
      point: p,
      source: source,
      category: categoryOfOsmTag('${r['category']}', '${r['type']}'),
    );
  }
}

/// Maps an OSM `key=value` tag to a place category (null when unrelated).
PlaceCategory? categoryOfOsmTag(String key, String value) => switch ((key, value)) {
  ('tourism', 'attraction' || 'museum' || 'viewpoint' || 'gallery' || 'theme_park' || 'zoo' || 'aquarium') =>
    PlaceCategory.attraction,
  ('historic', _) => PlaceCategory.attraction,
  ('amenity', 'restaurant' || 'cafe' || 'fast_food' || 'food_court') => PlaceCategory.restaurant,
  ('tourism', 'hotel' || 'hostel' || 'guest_house' || 'motel' || 'apartment') => PlaceCategory.hotel,
  ('aeroway', 'aerodrome' || 'terminal') => PlaceCategory.airport,
  ('railway', 'station' || 'halt') || ('public_transport', 'station') => PlaceCategory.railwayStation,
  ('amenity', 'bus_station') => PlaceCategory.busStation,
  _ => null,
};
