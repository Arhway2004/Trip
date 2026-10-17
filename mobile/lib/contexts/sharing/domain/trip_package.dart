/// The `.wanderplan` trip file: a ZIP with `trip.json` (+ `media/…`), or a
/// bare `trip.json`. See docs/IMPORT_FORMAT.md for the full schema.
library;

const tripPackageFormat = 'wanderplan.trip';

/// v1: trip, destinations, banner, photos, todos.
/// v2: + activities, expenses, exchangeRates.
/// v3: + places (saved places with coordinates); later also the optional,
/// additive activity fields travelMode/travelMinutes, openingHours and
/// reservation, plus `days` (start/end points). Kept at 3 so the web app and
/// API (which accept 1–3) and older app versions still read the file; readers
/// ignore fields they don't know.
const tripPackageSchemaVersion = 3;
const tripPackageExtension = 'wanderplan';
const tripPackageJsonEntry = 'trip.json';

enum TripPackageError { invalid, tooNew }

class TripPackageException implements Exception {
  const TripPackageException(this.error, [this.detail]);
  final TripPackageError error;
  final String? detail;

  @override
  String toString() => 'TripPackageException($error${detail == null ? '' : ': $detail'})';
}

/// Decoded package contents: the JSON document plus media bytes by entry path.
class TripPackageContents {
  const TripPackageContents(this.json, this.media);
  final Map<String, dynamic> json;
  final Map<String, List<int>> media;
}

/// `HH:mm` → minutes after midnight; `24:00` is allowed (end of day).
int? parsePackageTime(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  if (min > 59 || h > 24 || (h == 24 && min != 0)) return null;
  return h * 60 + min;
}

/// Colors may be written as ARGB integers or `#RRGGBB` / `#AARRGGBB` strings.
int? parsePackageColor(Object? v) {
  if (v is num) return v.toInt();
  if (v is! String) return null;
  final hex = v.trim().replaceFirst('#', '');
  if (!RegExp(r'^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(hex)) return null;
  final value = int.parse(hex, radix: 16);
  return hex.length == 6 ? 0xFF000000 | value : value;
}
