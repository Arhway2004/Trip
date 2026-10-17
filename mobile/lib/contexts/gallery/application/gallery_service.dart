import 'package:wanderplan/contexts/gallery/domain/photo.dart';
import 'package:wanderplan/contexts/gallery/domain/photo_repository.dart';
import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/application/media_store.dart';
import 'package:wanderplan/shared/application/unit_of_work.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';

/// Use cases of the Gallery context.
class GalleryService {
  GalleryService({
    required PhotoRepository photos,
    required TripRepository trips,
    required MediaStore media,
    required UnitOfWork uow,
    required IdGenerator ids,
    required Clock clock,
  }) : _photos = photos,
       _trips = trips,
       _media = media,
       _uow = uow,
       _ids = ids,
       _clock = clock;

  final PhotoRepository _photos;
  final TripRepository _trips;
  final MediaStore _media;
  final UnitOfWork _uow;
  final IdGenerator _ids;
  final Clock _clock;

  Stream<List<Photo>> watchPhotos(String tripId) => _photos.watchByTrip(tripId);
  Future<List<Photo>> photosOf(String tripId) => _photos.findByTrip(tripId);

  /// Copies an image into the trip's media and records it as a photo.
  Future<Photo> importPhoto(String tripId, String sourcePath, {String? caption, bool isFavorite = false}) async {
    final rel = await _media.importFile(tripId, sourcePath);
    return addStoredPhoto(tripId, rel, caption: caption, isFavorite: isFavorite);
  }

  /// Records an already-stored media file as a photo.
  Future<Photo> addStoredPhoto(
    String tripId,
    String relPath, {
    String? caption,
    bool isFavorite = false,
    DateTime? createdAt,
  }) async {
    final photo = Photo(
      id: _ids.newId(),
      tripId: tripId,
      relPath: relPath,
      caption: _blankToNull(caption),
      isFavorite: isFavorite,
      createdAt: createdAt ?? _clock(),
    );
    await _photos.insert(photo);
    return photo;
  }

  Future<List<String>> addPhotos(String tripId, List<String> sourcePaths) async => [
    for (final src in sourcePaths) (await importPhoto(tripId, src)).id,
  ];

  Future<void> updatePhoto(String photoId, {String? caption, bool? isFavorite}) async {
    final p = await _photos.findById(photoId);
    if (p == null) return;
    final c = caption == null ? p.caption : _blankToNull(caption);
    await _photos.update(p.copyWith(caption: c, clearCaption: c == null, isFavorite: isFavorite));
  }

  /// Deletes a photo. If it is the current banner image, the banner falls
  /// back to its colors so nothing points at a missing file.
  Future<void> deletePhoto(Photo photo) async {
    await _uow.run(() async {
      await _photos.delete(photo.id);
      final trip = await _trips.findById(photo.tripId);
      if (trip != null && trip.banner.imagePath == photo.relPath) {
        await _trips.save(trip.copyWith(banner: trip.banner.withoutImage(), updatedAt: _clock()));
      }
    });
    await _media.deleteFile(photo.relPath);
  }
}

String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
