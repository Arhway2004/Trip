import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// A place the traveller saved to a trip ("want to go"), e.g. an attraction,
/// restaurant or station. Entity of the Places context.
///
/// A saved place always has real coordinates (WGS84) from a provider search,
/// a map tap or an import; the app never invents them. Putting it on a day
/// creates an itinerary activity at the same location.
class SavedPlace {
  SavedPlace({
    required this.id,
    required this.tripId,
    required String name,
    this.category = PlaceCategory.attraction,
    required this.point,
    String? address,
    this.source,
    String? notes,
    required this.createdAt,
    required this.updatedAt,
  }) : name = name.trim(),
       address = _clean(address),
       notes = _clean(notes) {
    if (this.name.isEmpty) throw const DomainException('A place needs a name');
  }

  final String id;
  final String tripId;
  final String name;
  final PlaceCategory category;
  final GeoPoint point;
  final String? address;

  /// `map` (user tapped), `search:<provider>` or `import`.
  final String? source;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Coordinates came from a place provider rather than a manual tap.
  bool get isProviderVerified => source?.startsWith('search:') ?? false;

  SavedPlace copyWith({
    String? id,
    String? tripId,
    String? name,
    PlaceCategory? category,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SavedPlace(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    name: name ?? this.name,
    category: category ?? this.category,
    point: point,
    address: address,
    source: source,
    notes: clearNotes ? null : (notes ?? this.notes),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

String? _clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
