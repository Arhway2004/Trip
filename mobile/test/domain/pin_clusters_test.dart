import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/places/presentation/pin_clusters.dart';

void main() {
  // (name, lat, lng)
  const pins = [
    ('KMG arrive', 25.1019, 102.9292),
    ('KMG depart', 25.1019, 102.9292),
    ('Kunming hotel', 25.0400, 102.7100),
    ('Chengdu hotel', 30.6600, 104.0600),
    ('Xiamen hotel', 24.4800, 118.0900),
  ];
  (double, double) pos((String, double, double) p) => (p.$2, p.$3);

  test('zoomed out, a whole region collapses into one cluster per area', () {
    final g = clusterByScreen(pins, pos, 2);
    expect(g.map((c) => c.map((p) => p.$1).toList()), [
      ['KMG arrive', 'KMG depart', 'Kunming hotel', 'Chengdu hotel'],
      ['Xiamen hotel'],
    ]);
  });

  test('zoomed in, only pins at the same spot stay together', () {
    final g = clusterByScreen(pins, pos, 12);
    expect(g.first.map((p) => p.$1), ['KMG arrive', 'KMG depart']);
    expect(g, hasLength(4));
  });

  test('Mercator pixels: the equator/meridian is the centre of the world', () {
    final (x, y) = mercatorPixel(0, 0, 0);
    expect((x, y), (128.0, 128.0));
  });
}
