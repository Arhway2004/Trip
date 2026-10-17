import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

void main() {
  const beijing = GeoPoint(39.9087, 116.3975), shanghai = GeoPoint(31.2304, 121.4737);
  const bangkok = GeoPoint(13.7563, 100.5018);

  test('auto picks Amap when most of the trip is in mainland China', () {
    expect(resolveMapProvider(MapProviderPreference.auto, points: [beijing, shanghai, bangkok]), MapProviderId.amap);
    expect(resolveMapProvider(MapProviderPreference.auto, points: [bangkok, beijing]), MapProviderId.openStreetMap);
    expect(resolveMapProvider(MapProviderPreference.auto, points: [bangkok]), MapProviderId.openStreetMap);
  });

  test('auto falls back to the destination country when nothing is located yet', () {
    expect(resolveMapProvider(MapProviderPreference.auto, countries: ['China']), MapProviderId.amap);
    expect(resolveMapProvider(MapProviderPreference.auto, countries: ['中国']), MapProviderId.amap);
    expect(resolveMapProvider(MapProviderPreference.auto, countries: ['Thailand', null]), MapProviderId.openStreetMap);
    expect(resolveMapProvider(MapProviderPreference.auto), MapProviderId.openStreetMap);
  });

  test('an explicit choice wins', () {
    expect(resolveMapProvider(MapProviderPreference.openStreetMap, points: [beijing]), MapProviderId.openStreetMap);
    expect(resolveMapProvider(MapProviderPreference.amap, points: [bangkok]), MapProviderId.amap);
  });

  test('Amap converts for display and back; OSM leaves points alone', () {
    final shown = MapProviderId.amap.toProvider(beijing);
    expect(shown, isNot(beijing));
    expect(MapProviderId.amap.fromProvider(shown).distanceKmTo(beijing) * 1000, lessThan(1));
    expect(MapProviderId.openStreetMap.toProvider(beijing), beijing);
    expect(MapProviderId.amap.toProvider(bangkok), bangkok);
  });
}
