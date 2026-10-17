import 'package:wanderplan/shared/domain/geo_point.dart';

/// Coordinate system a map provider draws in. Everything the app stores is
/// WGS84; points are converted only for display and when talking to a provider.
enum CoordinateSystem { wgs84, gcj02 }

/// The map providers WanderPlan can draw with.
enum MapProviderId {
  /// OpenStreetMap tiles, Nominatim/Overpass search, OSRM routing. Worldwide.
  openStreetMap(CoordinateSystem.wgs84),

  /// Amap / Gaode. Best coverage in mainland China; draws in GCJ-02.
  amap(CoordinateSystem.gcj02);

  const MapProviderId(this.coordinates);
  final CoordinateSystem coordinates;

  /// Converts a stored WGS84 point to this provider's coordinates.
  GeoPoint toProvider(GeoPoint wgs84) => coordinates == CoordinateSystem.gcj02 ? Gcj02.fromWgs84(wgs84) : wgs84;

  /// Converts a point read from this provider (a tap, a search result) to WGS84.
  GeoPoint fromProvider(GeoPoint p) => coordinates == CoordinateSystem.gcj02 ? Gcj02.toWgs84(p) : p;
}

/// What the user chose in settings.
enum MapProviderPreference { auto, openStreetMap, amap }

/// Country names (any app language) that mean mainland China for the
/// "auto" choice when a trip has no coordinates yet.
const _chinaNames = {'china', 'cn', 'prc', "people's republic of china", '中国', '中國', '中华人民共和国', 'จีน'};

/// Picks the provider for a trip. "Auto" prefers Amap when most of the trip's
/// known points are in mainland China (or, without points, when a destination
/// country is China); otherwise OpenStreetMap.
MapProviderId resolveMapProvider(
  MapProviderPreference preference, {
  Iterable<GeoPoint> points = const [],
  Iterable<String?> countries = const [],
}) {
  switch (preference) {
    case MapProviderPreference.openStreetMap:
      return MapProviderId.openStreetMap;
    case MapProviderPreference.amap:
      return MapProviderId.amap;
    case MapProviderPreference.auto:
      final list = points.toList();
      if (list.isNotEmpty) {
        final inChina = list.where(Gcj02.appliesTo).length;
        return inChina * 2 > list.length ? MapProviderId.amap : MapProviderId.openStreetMap;
      }
      final china = countries.any((c) => c != null && _chinaNames.contains(c.trim().toLowerCase()));
      return china ? MapProviderId.amap : MapProviderId.openStreetMap;
  }
}
