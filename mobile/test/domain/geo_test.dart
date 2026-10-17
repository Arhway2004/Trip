import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

void main() {
  test('great-circle distance', () {
    const bangkok = GeoPoint(13.7563, 100.5018), chiangMai = GeoPoint(18.7883, 98.9853);
    expect(bangkok.distanceKmTo(chiangMai), closeTo(580, 10));
    expect(bangkok.distanceKmTo(bangkok), 0);
  });

  test('invalid coordinates are rejected instead of invented', () {
    expect(GeoPoint.tryCreate(null, 100), isNull);
    expect(GeoPoint.tryCreate(91, 0), isNull);
    expect(GeoPoint.tryCreate(13.7, 100.5), isNotNull);
  });

  test('GCJ-02 shifts points inside mainland China by a few hundred metres, not outside', () {
    const tiananmen = GeoPoint(39.9087, 116.3975);
    final gcj = Gcj02.fromWgs84(tiananmen);
    final shift = tiananmen.distanceKmTo(gcj);
    expect(shift, inInclusiveRange(0.1, 0.8));
    expect(gcj.longitude, greaterThan(tiananmen.longitude));
    const paris = GeoPoint(48.8584, 2.2945);
    expect(Gcj02.fromWgs84(paris), paris);
  });

  test('GCJ-02 applies to mainland China only, not to neighbours a bounding box would catch', () {
    for (final p in const [
      GeoPoint(39.9087, 116.3975), // Beijing
      GeoPoint(31.2304, 121.4737), // Shanghai
      GeoPoint(25.0389, 102.7183), // Kunming
      GeoPoint(43.8256, 87.6168), // Urumqi
      GeoPoint(18.2528, 109.5119), // Sanya
      GeoPoint(45.8038, 126.5350), // Harbin
    ]) {
      expect(Gcj02.appliesTo(p), isTrue, reason: '$p');
    }
    for (final p in const [
      GeoPoint(13.7563, 100.5018), // Bangkok
      GeoPoint(18.7883, 98.9853), // Chiang Mai
      GeoPoint(21.0278, 105.8342), // Hanoi
      GeoPoint(37.5665, 126.9780), // Seoul
      GeoPoint(25.0330, 121.5654), // Taipei
      GeoPoint(35.6762, 139.6503), // Tokyo
      GeoPoint(47.8864, 106.9057), // Ulaanbaatar
      GeoPoint(1.3521, 103.8198), // Singapore
    ]) {
      expect(Gcj02.appliesTo(p), isFalse, reason: '$p');
      expect(Gcj02.fromWgs84(p), p);
    }
  });

  test('GCJ-02 inverse returns the original WGS84 point to within a metre', () {
    for (final p in const [
      GeoPoint(39.9087, 116.3975),
      GeoPoint(22.5431, 114.0579),
      GeoPoint(29.5630, 106.5516),
    ]) {
      final back = Gcj02.toWgs84(Gcj02.fromWgs84(p));
      expect(back.distanceKmTo(p) * 1000, lessThan(1.0), reason: '$p');
    }
  });
}
