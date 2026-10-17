import 'package:wanderplan/contexts/places/domain/place.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/saved_place.dart';
import 'package:wanderplan/contexts/places/domain/saved_place_repository.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';

/// Input for saving a place.
class SavedPlaceDraft {
  SavedPlaceDraft({
    required this.name,
    required this.point,
    this.category = PlaceCategory.attraction,
    this.address,
    this.source,
    this.notes,
  });

  factory SavedPlaceDraft.fromResult(PlaceResult r, {PlaceCategory? category}) => SavedPlaceDraft(
    name: r.name,
    point: r.point,
    category: category ?? r.category ?? PlaceCategory.attraction,
    address: r.address.isEmpty ? null : r.address,
    source: r.source,
  );

  String name;
  GeoPoint point;
  PlaceCategory category;
  String? address;
  String? source;
  String? notes;
}

/// Use cases of the Places context: the trip's saved places ("want to go").
class SavedPlaceService {
  SavedPlaceService({required SavedPlaceRepository places, required IdGenerator ids, required Clock clock})
    : _places = places,
      _ids = ids,
      _clock = clock;

  final SavedPlaceRepository _places;
  final IdGenerator _ids;
  final Clock _clock;

  Stream<List<SavedPlace>> watchPlaces(String tripId) => _places.watchByTrip(tripId);
  Future<List<SavedPlace>> placesOf(String tripId) => _places.findByTrip(tripId);

  /// Saves a place. Saving the same spot twice returns the existing one.
  Future<String> savePlace(String tripId, SavedPlaceDraft d) async {
    final existing = await findSame(tripId, d.point, d.name);
    if (existing != null) return existing.id;
    final now = _clock();
    final p = SavedPlace(
      id: _ids.newId(),
      tripId: tripId,
      name: d.name,
      category: d.category,
      point: d.point,
      address: d.address,
      source: d.source,
      notes: d.notes,
      createdAt: now,
      updatedAt: now,
    );
    await _places.save(p);
    return p.id;
  }

  Future<List<String>> savePlaces(String tripId, List<SavedPlaceDraft> drafts) async => [
    for (final d in drafts) await savePlace(tripId, d),
  ];

  /// A saved place within 30 m with the same name (case-insensitive), if any.
  Future<SavedPlace?> findSame(String tripId, GeoPoint point, String name) async {
    final n = name.trim().toLowerCase();
    for (final p in await _places.findByTrip(tripId)) {
      if (p.name.toLowerCase() == n && p.point.distanceKmTo(point) < 0.03) return p;
    }
    return null;
  }

  Future<void> updatePlace(String id, {PlaceCategory? category, String? notes, bool clearNotes = false}) async {
    final p = await _require(id);
    await _places.save(p.copyWith(category: category, notes: notes, clearNotes: clearNotes, updatedAt: _clock()));
  }

  Future<void> removePlace(String id) => _places.delete(id);

  Future<void> restorePlace(SavedPlace p) => _places.save(p);

  /// Copies the saved places to another trip (trip duplication).
  Future<void> copyPlaces(String fromTripId, String toTripId) async {
    final now = _clock();
    for (final p in await _places.findByTrip(fromTripId)) {
      await _places.save(p.copyWith(id: _ids.newId(), tripId: toTripId, createdAt: now, updatedAt: now));
    }
  }

  Future<SavedPlace> _require(String id) async =>
      await _places.findById(id) ?? (throw EntityNotFoundException('Place', id));
}
