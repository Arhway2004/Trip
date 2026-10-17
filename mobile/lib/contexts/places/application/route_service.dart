import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Port for road routing. Needs an internet connection.
abstract interface class RouteService {
  /// Human-readable provider name with attribution.
  String get attribution;

  /// A route through [waypoints] (WGS84, at least two) in order.
  /// Throws [RoutingException] when the provider has no route; callers then
  /// show a straight line labelled as unverified, never a made-up road.
  Future<RouteResult> route(List<GeoPoint> waypoints, TravelMode mode);
}

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;
  @override
  String toString() => 'RoutingException: $message';
}
