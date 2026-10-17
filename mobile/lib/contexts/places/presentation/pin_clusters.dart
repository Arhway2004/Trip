import 'dart:math' as math;

/// Pixel position of a coordinate on a Web-Mercator map at [zoom].
(double, double) mercatorPixel(double lat, double lng, double zoom) {
  final scale = 256 * math.pow(2, zoom);
  final x = (lng + 180) / 360 * scale;
  final s = math.sin(lat.clamp(-85.05112878, 85.05112878) * math.pi / 180);
  final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale;
  return (x, y);
}

/// Groups items whose markers would overlap on screen at [zoom] (within
/// [radius] pixels of a group's first item), keeping the input order inside
/// each group. Items that don't overlap anything come back as groups of one.
List<List<T>> clusterByScreen<T>(
  List<T> items,
  (double lat, double lng) Function(T) position,
  double zoom, {
  double radius = 30,
}) {
  final groups = <(double, double, List<T>)>[];
  for (final item in items) {
    final (lat, lng) = position(item);
    final (x, y) = mercatorPixel(lat, lng, zoom);
    final hit = groups.where((g) => (g.$1 - x).abs() <= radius && (g.$2 - y).abs() <= radius).firstOrNull;
    if (hit != null) {
      hit.$3.add(item);
    } else {
      groups.add((x, y, [item]));
    }
  }
  return [for (final g in groups) g.$3];
}
