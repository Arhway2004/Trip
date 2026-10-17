import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/places/application/location_link_service.dart';
import 'package:wanderplan/contexts/places/domain/location_link.dart';
import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_lookup.dart';
import 'package:wanderplan/contexts/places/domain/plus_code.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

import '../helpers.dart';

class _Expander implements LinkExpander {
  _Expander(this.to);
  final String to;
  @override
  Future<Uri> expand(Uri shortLink) async => Uri.parse(to);
}

// The user's real inputs for Dukezong Ancient Town, Shangri-La.
const _embed =
    '<iframe src="https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3528.9150141005107!2d99.70218707552665!3d27.81238672085081!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3721ba8bacac6789%3A0x517be1756e2cf1f7!2z6aaZ5qC86YeM5ouJ5Y6_54us5YWL5a6X5Y-k5Z-O!5e0!3m2!1sth!2sth!4v1792223531003!5m2!1sth!2sth" width="600" height="450" style="border:0;" allowfullscreen="" loading="lazy"></iframe>';
const _short = 'https://maps.app.goo.gl/u591UoQLRBQNyBD29';
const _expanded =
    'https://www.google.com/maps/place/%E9%A6%99%E6%A0%BC%E9%87%8C%E6%8B%89%E5%8E%BF%E7%8B%AC%E5%85%8B%E5%AE%97%E5%8F%A4%E5%9F%8E/@27.8123867,99.7021871,17z/data=!3m1!4b1!4m6!3m5!1s0x3721ba8bacac6789:0x517be1756e2cf1f7!8m2!3d27.812382!4d99.704762!16s%2Fg%2F1wbrw3yh?entry=tts';
const _plus = 'RP63+XW2, Shangri-La City, Diqing Tibetan Autonomous Prefecture, Yunnan, จีน 674400';
const _googlePin = GeoPoint(27.812382, 99.704762);

void main() {
  group('parsing', () {
    test('a Google place URL uses the pin (!3d/!4d), not the view centre', () {
      final p = parseLocationText(_expanded) as ParsedCoordinates;
      expect((p.point, p.origin, p.exactPlace), (_googlePin, CoordinateOrigin.google, true));
    });

    test('an embed iframe gives the map centre, marked as not exact', () {
      final p = parseLocationText(_embed) as ParsedCoordinates;
      expect(p.point.latitude, closeTo(27.8123867, 1e-6));
      expect(p.point.longitude, closeTo(99.7021871, 1e-6));
      expect(p.exactPlace, isFalse);
    });

    test('short links, Plus Codes and plain coordinates are recognised', () {
      expect(parseLocationText(_short), isA<ShortMapLink>());
      final plus = parseLocationText(_plus) as PlusCodeText;
      expect((plus.code, plus.locality), ('RP63+XW2', 'Shangri-La City, Diqing Tibetan Autonomous Prefecture, Yunnan, จีน 674400'));
      expect((parseLocationText('27.812382, 99.704762') as ParsedCoordinates).point, _googlePin);
      expect((parseLocationText('33.8688° S, 151.2093° E') as ParsedCoordinates).point, const GeoPoint(-33.8688, 151.2093));
      expect((parseLocationText('https://uri.amap.com/marker?position=116.3975,39.9087') as ParsedCoordinates).point, const GeoPoint(39.9087, 116.3975));
      expect(parseLocationText('Louvre Museum'), isNull);
      expect(parseLocationText('https://example.com/?q=1,2'), isNull);
    });
  });

  group('Plus Codes', () {
    test('a full code decodes to the centre of its cell', () {
      final p = PlusCode.decode('7MVXRP63+XW2')!;
      expect(p.distanceKmTo(_googlePin) * 1000, lessThan(15));
    });

    test('a short code is completed from a nearby reference point', () {
      final p = PlusCode.recoverNearest('RP63+XW2', const GeoPoint(27.83, 99.71))!;
      expect(p.distanceKmTo(_googlePin) * 1000, lessThan(15));
      // Works across a cell edge too.
      expect(PlusCode.recoverNearest('RP63+XW2', const GeoPoint(28.2, 99.3))!.distanceKmTo(_googlePin), lessThan(0.02));
    });
  });

  group('resolving', () {
    final service = LocationLinkService(
      expander: _Expander(_expanded),
      search: () => FakePlaceSearch(
        results: [
          const PlaceResult(name: '香格里拉市', address: '', point: GeoPoint(27.8256, 99.7065), source: 'test'),
        ],
      ),
    );

    test('Google coordinates in mainland China are converted from GCJ-02 to GPS', () async {
      final r = await service.resolve(_short);
      expect(r.convertedFromGcj02, isTrue);
      expect(r.source, 'link:google');
      expect(r.point.distanceKmTo(Gcj02.toWgs84(_googlePin)), lessThan(0.001));
      expect(r.point.distanceKmTo(_googlePin) * 1000, inInclusiveRange(200, 600), reason: 'the China offset');
    });

    test('a short Plus Code finds its area by name', () async {
      final r = await service.resolve(_plus);
      expect(r.source, 'pluscode');
      expect(Gcj02.fromWgs84(r.point).distanceKmTo(_googlePin) * 1000, lessThan(15));
    });

    test('outside China nothing is converted; plain GPS coordinates can opt out', () async {
      final paris = await service.resolve('https://www.google.com/maps/place/x/@48.86,2.33,17z/data=!3d48.8606!4d2.3376');
      expect((paris.point, paris.convertedFromGcj02), (const GeoPoint(48.8606, 2.3376), false));
      final gps = await service.resolve('27.812382, 99.704762', plainFromChineseMap: false);
      expect(gps.point, _googlePin);
    });

    test('unrecognised text is an error, not a guess', () {
      expect(service.resolve('somewhere nice'), throwsA(isA<LocationLinkException>()));
    });
  });

  group('looking up names', () {
    test('query variants split alternatives and drop notes', () {
      expect(placeQueryVariants('昆明老街 / 南屏街'), ['昆明老街', '南屏街']);
      expect(placeQueryVariants('Bangkok airport (confirm BKK or DMK)'), ['Bangkok airport']);
      expect(placeQueryVariants('独克宗古城, Shangri-La'), ['独克宗古城, Shangri-La']);
    });

    test('generic names are recognised as placeholders', () {
      for (final n in ['Kunming hotel', 'Chengdu city centre', 'Chengdu airport (verify)', '丽江酒店']) {
        expect(looksLikePlaceholder(n), isTrue, reason: n);
      }
      for (final n in ['松赞林寺', 'Kunming Changshui International Airport', 'Dali Railway Station']) {
        expect(looksLikePlaceholder(n), isFalse, reason: n);
      }
    });

    test('matches near the trip destinations rank first; far ones are flagged', () {
      const xiamen = GeoPoint(24.4798, 118.0894);
      final ranked = rankByDestinations([
        const PlaceResult(name: '中山路步行街', address: '宜昌', point: GeoPoint(30.69, 111.28), source: 's'),
        const PlaceResult(name: '中山路步行街', address: '厦门', point: GeoPoint(24.455, 118.08), source: 's'),
      ], [xiamen]);
      expect(ranked.first.place.address, '厦门');
      expect(ranked.last.isNearDestination, isFalse);
    });
  });
}
