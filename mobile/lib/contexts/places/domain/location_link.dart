import 'package:wanderplan/contexts/places/domain/plus_code.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Where pasted coordinates came from. Google, Amap and Apple maps all draw
/// mainland China in GCJ-02, so their numbers there are offset from GPS.
enum CoordinateOrigin { google, amap, apple, plain }

/// What a pasted text turned out to be.
sealed class LocationText {
  const LocationText();
}

/// Coordinates read straight from the text, as written (not converted yet).
class ParsedCoordinates extends LocationText {
  const ParsedCoordinates(this.point, this.origin, {required this.exactPlace});
  final GeoPoint point;
  final CoordinateOrigin origin;

  /// False when only the map's view centre was available (an `@lat,lng` or
  /// an embed iframe), which may be a little off the place itself.
  final bool exactPlace;
}

/// A short link (maps.app.goo.gl) that must be expanded online first.
class ShortMapLink extends LocationText {
  const ShortMapLink(this.uri);
  final Uri uri;
}

/// A Plus Code; short codes need the area named after them (or a nearby point).
class PlusCodeText extends LocationText {
  const PlusCodeText(this.code, this.locality);
  final String code;
  final String? locality;
}

final _num = r'(-?\d{1,3}(?:\.\d+)?)';

/// Recognises a Google Maps / Amap / Apple Maps link, a Google embed
/// `<iframe>`, a short link, plain "lat, lng" coordinates or a Plus Code.
/// Returns null for anything else (e.g. an ordinary place name).
LocationText? parseLocationText(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;

  final src = RegExp(r'''src\s*=\s*["']([^"']+)["']''').firstMatch(t)?.group(1);
  final url = src ?? RegExp(r'https?://[^\s"<>]+').firstMatch(t)?.group(0);
  if (url != null) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'maps.app.goo.gl' || host == 'goo.gl' || host == 'g.co' || host == 'surl.amap.com') {
      return ShortMapLink(uri);
    }
    final origin = host.contains('amap.com') || host.contains('gaode.com')
        ? CoordinateOrigin.amap
        : host.contains('apple.com')
        ? CoordinateOrigin.apple
        : host.contains('google.') || host.contains('goo.gl')
        ? CoordinateOrigin.google
        : null;
    if (origin == null) return null;
    final decoded = Uri.decodeFull(url);
    ParsedCoordinates? at(String? lat, String? lng, {required bool exact}) {
      final p = GeoPoint.tryCreate(double.tryParse(lat ?? ''), double.tryParse(lng ?? ''));
      return p == null ? null : ParsedCoordinates(p, origin, exactPlace: exact);
    }

    // Google place pin: …!3d<lat>!4d<lng>
    final pin = RegExp('!3d$_num!4d$_num').allMatches(decoded).lastOrNull;
    if (pin != null) return at(pin.group(1), pin.group(2), exact: true);
    // Query parameters holding "lat,lng" (Amap's position/to are "lng,lat").
    for (final key in ['q', 'query', 'destination', 'daddr', 'll', 'sll', 'center', 'position', 'to', 'location']) {
      final v = uri.queryParameters[key];
      final m = v == null ? null : RegExp('^\\s*$_num\\s*,\\s*$_num').firstMatch(v);
      if (m == null) continue;
      final lngFirst = origin == CoordinateOrigin.amap && const {'position', 'to', 'location'}.contains(key);
      final exact = !const {'ll', 'sll', 'center'}.contains(key) || origin == CoordinateOrigin.apple && key == 'll';
      final r = lngFirst ? at(m.group(2), m.group(1), exact: exact) : at(m.group(1), m.group(2), exact: exact);
      if (r != null) return r;
    }
    // Google embed iframe: …!2d<lng>!3d<lat> is the map centre.
    final embed = RegExp('!2d$_num!3d$_num').firstMatch(decoded);
    if (embed != null) return at(embed.group(2), embed.group(1), exact: false);
    // Viewport: …/@<lat>,<lng>,<zoom>z
    final view = RegExp('@$_num,$_num').firstMatch(decoded);
    if (view != null) return at(view.group(1), view.group(2), exact: false);
    return null;
  }

  final plus = PlusCode.pattern.firstMatch(t);
  if (plus != null) {
    final rest = t.substring(plus.end).replaceFirst(RegExp(r'^[\s,，]+'), '').trim();
    return PlusCodeText(plus.group(1)!.toUpperCase(), rest.isEmpty ? null : rest);
  }

  // "27.8124, 99.7048" or "27.8124° N, 99.7048° E"
  final c = RegExp(
    r'^\s*(-?\d{1,2}(?:\.\d+)?)\s*°?\s*([NSns])?\s*[,\s]\s*(-?\d{1,3}(?:\.\d+)?)\s*°?\s*([EWew])?\s*$',
  ).firstMatch(t);
  if (c != null) {
    var lat = double.parse(c.group(1)!), lng = double.parse(c.group(3)!);
    if ((c.group(2) ?? '').toUpperCase() == 'S') lat = -lat.abs();
    if ((c.group(4) ?? '').toUpperCase() == 'W') lng = -lng.abs();
    final p = GeoPoint.tryCreate(lat, lng);
    if (p != null) return ParsedCoordinates(p, CoordinateOrigin.plain, exactPlace: true);
  }
  return null;
}
