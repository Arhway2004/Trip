import 'package:wanderplan/shared/domain/geo_point.dart';

/// How the traveller moves between stops when the route is drawn on roads.
/// Public transport is not offered: no free provider returns timetabled
/// routes, so the app does not pretend to have them.
enum TravelMode { walking, cycling, driving }

/// A road route returned by a routing provider. Geometry is WGS84.
class RouteResult {
  const RouteResult({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.mode,
    required this.source,
  });

  final List<GeoPoint> geometry;
  final double distanceMeters;

  /// The provider's typical estimate; not live traffic and not a guarantee.
  final double durationSeconds;
  final TravelMode mode;

  /// e.g. `routing:osrm-fossgis`, `routing:amap`
  final String source;
}
