import 'package:wanderplan/contexts/places/application/place_search.dart';
import 'package:wanderplan/contexts/places/domain/location_link.dart';
import 'package:wanderplan/contexts/places/domain/plus_code.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Port: expands a short link (maps.app.goo.gl/…) to the full URL. Online.
abstract interface class LinkExpander {
  Future<Uri> expand(Uri shortLink);
}

enum LocationLinkFailure {
  /// Not a map link, coordinates or Plus Code.
  unrecognized,

  /// The short link couldn't be opened (offline, expired…).
  shortLinkFailed,

  /// A short Plus Code without a recognisable area name or nearby point.
  plusCodeNeedsArea,
}

class LocationLinkException implements Exception {
  const LocationLinkException(this.failure);
  final LocationLinkFailure failure;
  @override
  String toString() => 'LocationLinkException: ${failure.name}';
}

/// A pasted location turned into a stored (WGS84) point.
class ResolvedLocation {
  const ResolvedLocation({
    required this.point,
    required this.source,
    required this.exactPlace,
    required this.convertedFromGcj02,
  });
  final GeoPoint point;

  /// `link:google`, `link:amap`, `link:apple`, `coordinates` or `pluscode`.
  final String source;

  /// False when only the map centre of a link was available.
  final bool exactPlace;

  /// The numbers were offset (mainland China) and have been converted to GPS.
  final bool convertedFromGcj02;
}

/// Turns a pasted Google Maps link, embed code, short link, "lat, lng" or Plus
/// Code into WGS84 coordinates. Coordinates from Google, Amap and Apple maps
/// inside mainland China are GCJ-02 and are converted; plain coordinates are
/// converted only when the user says they were copied from such a map.
class LocationLinkService {
  LocationLinkService({required LinkExpander expander, required PlaceSearch Function() search})
    : _expander = expander,
      _search = search;

  final LinkExpander _expander;
  final PlaceSearch Function() _search;

  /// [near] helps complete short Plus Codes; [plainFromChineseMap] says plain
  /// coordinates or Plus Codes were copied from Google/Amap/Apple maps.
  Future<ResolvedLocation> resolve(String text, {GeoPoint? near, bool plainFromChineseMap = true}) async {
    var parsed = parseLocationText(text);
    if (parsed is ShortMapLink) {
      final Uri full;
      try {
        full = await _expander.expand(parsed.uri);
      } catch (_) {
        throw const LocationLinkException(LocationLinkFailure.shortLinkFailed);
      }
      parsed = parseLocationText(full.toString());
      if (parsed == null || parsed is ShortMapLink) {
        throw const LocationLinkException(LocationLinkFailure.shortLinkFailed);
      }
    }
    switch (parsed) {
      case null || ShortMapLink():
        throw const LocationLinkException(LocationLinkFailure.unrecognized);
      case ParsedCoordinates(:final point, :final origin, :final exactPlace):
        final offset = origin != CoordinateOrigin.plain || plainFromChineseMap;
        return _finish(point, switch (origin) {
          CoordinateOrigin.google => 'link:google',
          CoordinateOrigin.amap => 'link:amap',
          CoordinateOrigin.apple => 'link:apple',
          CoordinateOrigin.plain => 'coordinates',
        }, exactPlace: exactPlace, offset: offset);
      case PlusCodeText(:final code, :final locality):
        GeoPoint? p;
        if (PlusCode.isFull(code)) {
          p = PlusCode.decode(code);
        } else {
          final ref = near ?? await _locate(locality);
          if (ref == null) throw const LocationLinkException(LocationLinkFailure.plusCodeNeedsArea);
          p = PlusCode.recoverNearest(code, ref);
        }
        if (p == null) throw const LocationLinkException(LocationLinkFailure.unrecognized);
        return _finish(p, 'pluscode', exactPlace: true, offset: plainFromChineseMap);
    }
  }

  ResolvedLocation _finish(GeoPoint p, String source, {required bool exactPlace, required bool offset}) {
    final convert = offset && Gcj02.appliesTo(p);
    return ResolvedLocation(
      point: convert ? Gcj02.toWgs84(p) : p,
      source: source,
      exactPlace: exactPlace,
      convertedFromGcj02: convert,
    );
  }

  /// The area named after a short Plus Code ("Shangri-La City, Diqing …"),
  /// trying shorter versions when the full text finds nothing.
  Future<GeoPoint?> _locate(String? locality) async {
    if (locality == null) return null;
    final parts = locality.split(RegExp(r'\s*[,，]\s*')).where((s) => s.isNotEmpty).toList();
    final tries = <String>{
      locality,
      if (parts.length > 2) parts.take(2).join(', '),
      if (parts.isNotEmpty) parts.first,
    };
    for (final q in tries) {
      try {
        final r = await _search().search(q, limit: 1);
        if (r.isNotEmpty) return r.first.point;
      } catch (_) {
        // Try the next, shorter name.
      }
    }
    return null;
  }
}
