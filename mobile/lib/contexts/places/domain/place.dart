import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// A place returned by a search provider, with real coordinates from that
/// provider, always converted to WGS84.
class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.address,
    required this.point,
    required this.source,
    this.category,
  });

  final String name;
  final String address;
  final GeoPoint point;

  /// e.g. `search:openstreetmap-nominatim`, `search:amap`
  final String source;

  /// Set when the provider says what kind of place it is.
  final PlaceCategory? category;
}
