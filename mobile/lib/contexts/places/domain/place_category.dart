/// Kinds of places the map can search for, save and filter.
enum PlaceCategory {
  attraction,
  restaurant,
  hotel,
  airport,
  railwayStation,
  busStation,
  other;

  /// Categories offered by "Explore nearby".
  static const explorable = [attraction, restaurant, hotel, airport, railwayStation, busStation];

  /// Search radius that makes sense for the category (airports are far apart).
  int get nearbyRadiusMeters => switch (this) {
    airport => 50000,
    railwayStation || busStation => 15000,
    _ => 3000,
  };
}
