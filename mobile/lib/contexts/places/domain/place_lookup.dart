import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Search texts to try for a place name written by hand or by an AI, in order.
/// "昆明老街 / 南屏街" → ["昆明老街", "南屏街"]; "Chengdu airport (verify)" →
/// ["Chengdu airport"]. Notes in brackets are dropped, alternatives split.
List<String> placeQueryVariants(String name) {
  final cleaned = name.replaceAll(RegExp(r'[(（][^)）]*[)）]'), ' ').trim();
  final parts = cleaned
      .split(RegExp(r'\s*(?:/|／|\||、|\bor\b|或)\s*'))
      .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((s) => s.length >= 2)
      .toList();
  final out = <String>[];
  for (final p in [if (parts.length > 1) ...parts else cleaned]) {
    if (p.length >= 2 && !out.contains(p)) out.add(p);
  }
  return out;
}

/// Names that describe a kind of place rather than a specific one ("Kunming
/// hotel", "Chengdu city centre", "airport (confirm BKK or DMK)"). A search
/// would still return *a* match, but not necessarily the traveller's, so such
/// matches are never pre-selected.
bool looksLikePlaceholder(String name) => RegExp(
  r'\b(hotel|hostel|accommodation|city cent(er|re)|downtown|confirm|verify|tbd|tbc|to be decided)\b'
  r'|酒店|宾馆|住宿|市中心|待定|待确认',
  caseSensitive: false,
).hasMatch(name);

/// How far a match may be from every trip destination before it is flagged.
const nearDestinationKm = 100.0;

/// A search match plus its distance to the closest trip destination (null
/// when no destination has coordinates yet).
class RankedPlace {
  const RankedPlace(this.place, this.kmToDestination);
  final PlaceResult place;
  final double? kmToDestination;

  bool get isNearDestination => kmToDestination == null || kmToDestination! <= nearDestinationKm;
}

/// Orders matches so those near the trip's destinations come first (the
/// provider's own order breaks ties). Same-name streets in other cities sink.
List<RankedPlace> rankByDestinations(List<PlaceResult> results, List<GeoPoint> destinations) {
  final ranked = [
    for (final r in results)
      RankedPlace(
        r,
        destinations.isEmpty
            ? null
            : destinations.map((d) => d.distanceKmTo(r.point)).reduce((a, b) => a < b ? a : b),
      ),
  ];
  final order = {for (var i = 0; i < ranked.length; i++) ranked[i]: i};
  ranked.sort((a, b) {
    final near = (b.isNearDestination ? 1 : 0) - (a.isNearDestination ? 1 : 0);
    return near != 0 ? near : order[a]!.compareTo(order[b]!);
  });
  return ranked;
}
