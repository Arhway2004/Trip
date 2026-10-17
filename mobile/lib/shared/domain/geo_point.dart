import 'dart:math' as math;

/// A WGS84 coordinate (the system used by GPS and OpenStreetMap).
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude)
    : assert(latitude >= -90 && latitude <= 90),
      assert(longitude >= -180 && longitude <= 180);

  /// Returns null for missing or out-of-range values instead of inventing one.
  static GeoPoint? tryCreate(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat.isNaN || lng.isNaN || lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return GeoPoint(lat, lng);
  }

  final double latitude;
  final double longitude;

  /// Great-circle ("as the crow flies") distance in kilometres.
  double distanceKmTo(GeoPoint o) {
    const r = 6371.0088;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(o.latitude - latitude), dLng = rad(o.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) * math.cos(rad(o.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.toDouble()));
  }

  @override
  bool operator ==(Object other) => other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}

/// China's GCJ-02 datum, required by Amap/Gaode inside mainland China.
/// Uses the widely published public conversion. Points outside mainland China
/// (Taiwan, Korea, Vietnam, Thailand… are outside; Hong Kong and Macau fall
/// inside the table) are returned unchanged.
abstract final class Gcj02 {
  static const _a = 6378245.0;
  static const _ee = 0.00669342162296594323;

  // (west, north, east, south) rectangles approximating mainland China, minus
  // neighbouring areas they overlap. Same table as the open-source
  // coordtransform library (wandergis/coordtransform), so a plain bounding box
  // never shifts e.g. Bangkok, Hanoi or Seoul.
  static const _region = [
    (79.446200, 49.220400, 96.330000, 42.889900),
    (109.687200, 54.141500, 135.000200, 39.374200),
    (73.124600, 42.889900, 124.143255, 29.529700),
    (82.968400, 29.529700, 97.035200, 26.718600),
    (97.025300, 29.529700, 124.367395, 20.414096),
    (107.975793, 20.414096, 111.744104, 17.871542),
  ];
  static const _exclude = [
    (119.921265, 25.398623, 122.497559, 21.785006), // Taiwan
    (101.865200, 22.284000, 106.665000, 20.098800), // northern Laos / Vietnam
    (106.452500, 21.542200, 108.051000, 20.487800), // northern Vietnam coast
    (109.032300, 55.817500, 119.127000, 50.325700), // Mongolia / Russia
    (127.456800, 55.817500, 137.022700, 49.557400), // Russian Far East
    (131.266200, 44.892200, 137.022700, 42.569200), // Vladivostok
    (73.124600, 35.398637, 77.948114, 29.529700), // Kashmir / northern India
  ];

  static bool _inside((double, double, double, double) r, GeoPoint p) =>
      p.longitude >= r.$1 && p.longitude <= r.$3 && p.latitude <= r.$2 && p.latitude >= r.$4;

  /// Whether GCJ-02 applies at [p] (an approximation near the borders).
  static bool appliesTo(GeoPoint p) =>
      _region.any((r) => _inside(r, p)) && !_exclude.any((r) => _inside(r, p));

  static GeoPoint fromWgs84(GeoPoint p) {
    if (!appliesTo(p)) return p;
    final (dLat, dLng) = _offset(p.latitude, p.longitude);
    return GeoPoint(p.latitude + dLat, p.longitude + dLng);
  }

  /// Inverse of [fromWgs84] by fixed-point iteration (error well under 1 m).
  /// Used for points read off a GCJ-02 map or returned by Amap services.
  static GeoPoint toWgs84(GeoPoint gcj) {
    if (!appliesTo(gcj)) return gcj;
    var lat = gcj.latitude, lng = gcj.longitude;
    for (var i = 0; i < 10; i++) {
      final (dLat, dLng) = _offset(lat, lng);
      final nLat = gcj.latitude - dLat, nLng = gcj.longitude - dLng;
      final done = (nLat - lat).abs() < 1e-9 && (nLng - lng).abs() < 1e-9;
      lat = nLat;
      lng = nLng;
      if (done) break;
    }
    return GeoPoint(lat.clamp(-90, 90), lng.clamp(-180, 180));
  }

  static (double, double) _offset(double lat, double lng) {
    final x = lng - 105.0, y = lat - 35.0;
    var dLat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
    dLat += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    dLat += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
    dLat += (160.0 * math.sin(y / 12.0 * math.pi) + 320 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
    var dLng = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
    dLng += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    dLng += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0;
    dLng += (150.0 * math.sin(x / 12.0 * math.pi) + 300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0;
    final radLat = lat / 180.0 * math.pi;
    var magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
    dLng = (dLng * 180.0) / (_a / sqrtMagic * math.cos(radLat) * math.pi);
    return (dLat, dLng);
  }
}
