import 'dart:math' as math;

import 'package:wanderplan/shared/domain/geo_point.dart';

/// Open Location Code ("Plus Code", e.g. `7MQ3RP63+XW2` or the short
/// `RP63+XW2, Shangri-La`), the open algorithm Google Maps shows for places.
/// Spec: github.com/google/open-location-code.
abstract final class PlusCode {
  static const _alphabet = '23456789CFGHJMPQRVWX';
  static const _pairResolutions = [20.0, 1.0, 0.05, 0.0025, 0.000125];

  static final pattern = RegExp(r'(?<![0-9A-Z])([23456789CFGHJMPQRVWX]{2,8}\+[23456789CFGHJMPQRVWX]{0,7})(?![0-9A-Z])', caseSensitive: false);

  static bool isFull(String code) => code.indexOf('+') == 8;

  /// Centre of a full code's area, or null when it isn't a valid full code.
  static GeoPoint? decode(String code) {
    final c = code.toUpperCase().replaceAll('+', '').replaceAll('0', '');
    if (!isFull(code.toUpperCase()) || c.length < 8 || c.split('').any((ch) => !_alphabet.contains(ch))) return null;
    var lat = -90.0, lng = -180.0, latSize = 0.0, lngSize = 0.0;
    final pairs = math.min(c.length, 10);
    for (var i = 0; i + 1 < pairs; i += 2) {
      final res = _pairResolutions[i ~/ 2];
      lat += _alphabet.indexOf(c[i]) * res;
      lng += _alphabet.indexOf(c[i + 1]) * res;
      latSize = lngSize = res;
    }
    for (var i = 10; i < c.length; i++) {
      final v = _alphabet.indexOf(c[i]);
      latSize /= 5;
      lngSize /= 4;
      lat += (v ~/ 4) * latSize;
      lng += (v % 4) * lngSize;
    }
    return GeoPoint.tryCreate(math.min(lat + latSize / 2, 90), _normLng(lng + lngSize / 2));
  }

  /// Completes a short code with the nearest matching area around [reference]
  /// (which must be within about half a degree for a 4-character prefix).
  static GeoPoint? recoverNearest(String shortCode, GeoPoint reference) {
    final code = shortCode.toUpperCase();
    final sep = code.indexOf('+');
    if (sep < 0) return null;
    if (sep == 8) return decode(code);
    final padding = 8 - sep;
    if (padding.isOdd || padding <= 0) return null;
    final resolution = math.pow(20, 2 - padding / 2).toDouble();
    final half = resolution / 2;
    final full = decode(_prefix(reference, padding) + code);
    if (full == null) return null;
    var lat = full.latitude, lng = full.longitude;
    if (reference.latitude + half < lat && lat - resolution >= -90) {
      lat -= resolution;
    } else if (reference.latitude - half > lat && lat + resolution <= 90) {
      lat += resolution;
    }
    if (reference.longitude + half < lng) {
      lng -= resolution;
    } else if (reference.longitude - half > lng) {
      lng += resolution;
    }
    return GeoPoint.tryCreate(lat, _normLng(lng));
  }

  /// The first [digits] characters of the full code for [p].
  static String _prefix(GeoPoint p, int digits) {
    var lat = math.min(p.latitude, 89.9999999) + 90, lng = _normLng(p.longitude) + 180;
    final b = StringBuffer();
    for (var i = 0; i < digits ~/ 2; i++) {
      final res = _pairResolutions[i];
      final dLat = (lat / res).floor(), dLng = (lng / res).floor();
      lat -= dLat * res;
      lng -= dLng * res;
      b
        ..write(_alphabet[dLat])
        ..write(_alphabet[dLng]);
    }
    return b.toString();
  }

  static double _normLng(double lng) {
    while (lng < -180) {
      lng += 360;
    }
    while (lng >= 180) {
      lng -= 360;
    }
    return lng;
  }
}
