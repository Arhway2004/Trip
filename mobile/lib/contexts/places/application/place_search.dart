import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Port for online place search (geocoding and nearby points of interest).
/// Needs an internet connection. Results are always WGS84.
abstract interface class PlaceSearch {
  /// Human-readable provider name with attribution.
  String get attribution;

  /// Text search ("Louvre", "Shanghai Hongqiao station"). [near] biases results
  /// towards the area the user is looking at.
  Future<List<PlaceResult>> search(String query, {String? languageCode, GeoPoint? near, int limit = 8});

  /// Places of [category] around [center] (WGS84), nearest first when the
  /// provider reports distance.
  Future<List<PlaceResult>> nearby(
    GeoPoint center,
    PlaceCategory category, {
    String? languageCode,
    int? radiusMeters,
    int limit = 30,
  });
}

class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);
  final String message;
  @override
  String toString() => 'PlaceSearchException: $message';
}
