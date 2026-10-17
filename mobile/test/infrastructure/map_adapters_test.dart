import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderplan/contexts/places/application/route_service.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/contexts/places/infrastructure/amap_web_service.dart';
import 'package:wanderplan/contexts/places/infrastructure/osm_place_search.dart';
import 'package:wanderplan/contexts/places/infrastructure/osrm_route_service.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Answers every request with canned JSON and records what was asked (no network).
class _FakeHttp implements HttpClientAdapter {
  _FakeHttp(this.respond);
  final Object Function(RequestOptions o) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o);
    return ResponseBody.fromString(
      jsonEncode(respond(o)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeHttp http) => Dio(BaseOptions(baseUrl: 'https://example.test'))..httpClientAdapter = http;

void main() {
  const tiananmen = GeoPoint(39.9087, 116.3975);

  group('OSRM (FOSSGIS)', () {
    test('requests the right profile and parses GeoJSON geometry (lng,lat order)', () async {
      final http = _FakeHttp(
        (_) => {
          'code': 'Ok',
          'routes': [
            {
              'distance': 1332.3,
              'duration': 1068.2,
              'geometry': {
                'coordinates': [
                  [100.491327, 13.75014],
                  [100.4930, 13.7465],
                ],
              },
            },
          ],
        },
      );
      final r = await OsrmRouteService(_dio(http)).route(const [
        GeoPoint(13.75, 100.4913),
        GeoPoint(13.7465, 100.493),
      ], TravelMode.walking);
      expect(http.requests.single.path, startsWith('/routed-foot/route/v1/driving/100.491300,13.750000;'));
      expect(r.geometry.first, const GeoPoint(13.75014, 100.491327));
      expect((r.distanceMeters, r.durationSeconds, r.source), (1332.3, 1068.2, 'routing:osrm-fossgis'));
    });

    test('no route is an error, never an invented line', () {
      expect(() => OsrmRouteService.parse({'code': 'NoRoute', 'routes': []}, TravelMode.driving), throwsA(isA<RoutingException>()));
    });
  });

  group('Amap web service', () {
    test('search results are converted from GCJ-02 to WGS84', () async {
      final gcj = Gcj02.fromWgs84(tiananmen);
      final http = _FakeHttp(
        (_) => {
          'status': '1',
          'info': 'OK',
          'pois': [
            {
              'name': '天安门',
              'location': '${gcj.longitude},${gcj.latitude}',
              'address': [], // Amap sends [] for empty text.
              'pname': '北京市',
              'cityname': '北京市',
              'adname': '东城区',
              'typecode': '110202',
            },
          ],
        },
      );
      final r = await AmapWebService('k', _dio(http)).search('天安门');
      expect(r.single.point.distanceKmTo(tiananmen) * 1000, lessThan(1));
      expect(r.single.category, PlaceCategory.attraction);
      expect(r.single.address, '北京市 东城区');
      expect(http.requests.single.queryParameters['key'], 'k');
    });

    test('nearby sends the centre in GCJ-02 with the category type code', () async {
      final http = _FakeHttp((_) => {'status': '1', 'pois': []});
      await AmapWebService('k', _dio(http)).nearby(tiananmen, PlaceCategory.railwayStation);
      final q = http.requests.single.queryParameters;
      final gcj = Gcj02.fromWgs84(tiananmen);
      expect(q['location'], '${gcj.longitude.toStringAsFixed(6)},${gcj.latitude.toStringAsFixed(6)}');
      expect((q['types'], q['radius']), ('150200', 15000));
    });

    test('walking routes join every leg; polylines come back as WGS84', () async {
      final a = Gcj02.fromWgs84(tiananmen), b = Gcj02.fromWgs84(const GeoPoint(39.9163, 116.3972));
      final http = _FakeHttp(
        (_) => {
          'status': '1',
          'route': {
            'paths': [
              {
                'distance': '900',
                'duration': '720',
                'steps': [
                  {'polyline': '${a.longitude},${a.latitude};${b.longitude},${b.latitude}'},
                ],
              },
            ],
          },
        },
      );
      final r = await AmapWebService('k', _dio(http)).route(const [
        tiananmen,
        GeoPoint(39.9163, 116.3972),
        GeoPoint(39.9250, 116.4040),
      ], TravelMode.walking);
      expect(http.requests, hasLength(2));
      expect(http.requests.first.path, '/v3/direction/walking');
      expect((r.distanceMeters, r.durationSeconds, r.source), (1800, 1440, 'routing:amap'));
      expect(r.geometry.first.distanceKmTo(tiananmen) * 1000, lessThan(1));
    });

    test('v4 cycling errors and v3 failures surface as routing errors', () {
      expect(
        () => AmapWebService.parseRoute({'errcode': 30001, 'errmsg': 'INVALID'}, TravelMode.cycling),
        throwsA(isA<RoutingException>()),
      );
      expect(
        () => AmapWebService.parseRoute({'status': '0', 'info': 'INVALID_USER_KEY'}, TravelMode.walking),
        throwsA(isA<RoutingException>()),
      );
    });
  });

  group('OpenStreetMap Nominatim', () {
    test('nearby keeps only the asked category inside the radius, nearest first', () async {
      final http = _FakeHttp(
        (o) => [
          {'name': 'Far hotel', 'lat': '13.80', 'lon': '100.50', 'category': 'tourism', 'type': 'hotel'},
          {'name': 'Near hotel', 'lat': '13.7570', 'lon': '100.5020', 'category': 'tourism', 'type': 'hotel'},
          {'name': 'A street', 'lat': '13.7565', 'lon': '100.5019', 'category': 'highway', 'type': 'residential'},
        ],
      );
      final r = await OsmPlaceSearch(_dio(http)).nearby(const GeoPoint(13.7563, 100.5018), PlaceCategory.hotel);
      expect(r.map((p) => p.name), ['Near hotel']);
      final q = http.requests.single.queryParameters;
      expect((q['q'], q['bounded']), ('hotel', 1));
    });
  });
}
