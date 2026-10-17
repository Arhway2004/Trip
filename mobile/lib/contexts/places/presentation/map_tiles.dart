import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Raster tiles for [provider]. Both need an internet connection; tiles
/// already viewed are cached by flutter_map's built-in cache (which honours
/// the servers' cache headers, as the OSM tile policy requires).
TileLayer providerTileLayer(MapProviderId provider) => switch (provider) {
  MapProviderId.openStreetMap => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.wanderplan.wanderplan',
    maxNativeZoom: 19,
  ),
  // Amap road map (GCJ-02). Same tiles the Amap web map shows.
  MapProviderId.amap => TileLayer(
    urlTemplate: 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
    subdomains: const ['1', '2', '3', '4'],
    userAgentPackageName: 'com.wanderplan.wanderplan',
    maxNativeZoom: 18,
  ),
};

/// Attribution required by the provider, always visible on the map.
Widget providerAttribution(MapProviderId provider) => RichAttributionWidget(
  alignment: AttributionAlignment.bottomLeft,
  attributions: switch (provider) {
    MapProviderId.openStreetMap => [
      TextSourceAttribution(
        'OpenStreetMap contributors',
        onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
      ),
    ],
    MapProviderId.amap => [
      TextSourceAttribution('AutoNavi / 高德地图', onTap: () => launchUrl(Uri.parse('https://lbs.amap.com/'))),
    ],
  },
);

/// Converts between stored WGS84 points and what the provider draws.
extension ProviderProjection on MapProviderId {
  LatLng toScreen(GeoPoint wgs84) {
    final p = toProvider(wgs84);
    return LatLng(p.latitude, p.longitude);
  }

  GeoPoint fromScreen(LatLng ll) => fromProvider(GeoPoint(ll.latitude, ll.longitude.clamp(-180, 180)));
}
