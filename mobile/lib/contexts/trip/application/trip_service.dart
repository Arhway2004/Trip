import 'package:wanderplan/contexts/budget/application/budget_service.dart';
import 'package:wanderplan/contexts/checklist/application/checklist_service.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/gallery/application/gallery_service.dart';
import 'package:wanderplan/contexts/gallery/domain/photo.dart';
import 'package:wanderplan/contexts/places/application/saved_place_service.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/application/media_store.dart';
import 'package:wanderplan/shared/application/unit_of_work.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/domain_exception.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';

import 'trip_draft.dart';

/// Use cases (commands) of the Trip context.
class TripService {
  TripService({
    required TripRepository trips,
    required GalleryService gallery,
    required ChecklistService checklist,
    required ItineraryService itinerary,
    required BudgetService budget,
    required SavedPlaceService places,
    required MediaStore media,
    required UnitOfWork uow,
    required IdGenerator ids,
    required Clock clock,
  }) : _trips = trips,
       _gallery = gallery,
       _checklist = checklist,
       _itinerary = itinerary,
       _places = places,
       _budget = budget,
       _media = media,
       _uow = uow,
       _ids = ids,
       _clock = clock;

  final TripRepository _trips;
  final GalleryService _gallery;
  final ChecklistService _checklist;
  final ItineraryService _itinerary;
  final BudgetService _budget;
  final SavedPlaceService _places;
  final MediaStore _media;
  final UnitOfWork _uow;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Trip?> getTrip(String id) => _trips.findById(id);

  Future<Trip> _require(String id) async => await _trips.findById(id) ?? (throw EntityNotFoundException('Trip', id));

  Future<String> createTrip(TripDraft draft) async {
    final id = _ids.newId();
    final now = _clock();
    var banner = BannerConfig.defaultFor(id);
    final trip = draft.toTrip(id: id, now: now, banner: banner); // validates before any I/O
    final cover = draft.coverImageSourcePath;
    await _uow.run(() async {
      await _trips.insertFirst(trip);
      if (cover != null) {
        final photo = await _gallery.importPhoto(id, cover);
        banner = banner.withImage(photo.relPath);
        await _trips.save(trip.copyWith(banner: banner));
      }
    });
    return id;
  }

  Future<void> updateTrip(String id, TripDraft draft) async {
    final current = await _require(id);
    final cover = draft.coverImageSourcePath;
    await _uow.run(() async {
      var banner = current.banner;
      if (cover != null) banner = banner.withImage((await _gallery.importPhoto(id, cover)).relPath);
      await _trips.save(draft.toTrip(id: id, now: _clock(), base: current, banner: banner));
    });
  }

  /// Copies a trip as a template: details, destinations, banner (with its own
  /// copy of the banner image), the checklist (unchecked), the itinerary
  /// (bookings reset) and planned costs. Photos and actual spending are not copied.
  Future<String> duplicateTrip(String sourceId, {required String titleSuffix}) async {
    final src = await _require(sourceId);
    final id = _ids.newId();
    final now = _clock();
    var banner = src.banner;
    if (banner.imagePath != null) banner = banner.copyWith(imagePath: await _media.copyToTrip(banner.imagePath!, id));
    await _uow.run(() async {
      await _trips.insertFirst(
        src.copyWith(
          id: id,
          title: '${src.title}$titleSuffix',
          archived: false,
          createdAt: now,
          updatedAt: now,
          banner: banner,
        ),
      );
      await _checklist.copyItems(sourceId, id);
      final idMap = await _itinerary.copyActivities(sourceId, id);
      await _budget.copyPlan(sourceId, id, activityIdMap: idMap);
      await _places.copyPlaces(sourceId, id);
    });
    return id;
  }

  Future<void> setArchived(String id, bool archived) async =>
      _trips.save((await _require(id)).copyWith(archived: archived, updatedAt: _clock()));

  Future<void> reorder(List<String> orderedIds) => _trips.reorder(orderedIds);

  Future<void> saveBanner(String id, BannerConfig banner) async =>
      _trips.save((await _require(id)).copyWith(banner: banner, updatedAt: _clock()));

  /// Imports a new banner image (it also becomes a gallery photo) and
  /// returns its media path. The banner itself is saved by [saveBanner].
  Future<String> importBannerImage(String tripId, String sourcePath) async =>
      (await _gallery.importPhoto(tripId, sourcePath)).relPath;

  Future<void> setPhotoAsCover(String tripId, Photo photo) async {
    final trip = await _require(tripId);
    await _trips.save(trip.copyWith(banner: trip.banner.withImage(photo.relPath), updatedAt: _clock()));
  }

  /// Deletes the trip; child rows cascade in storage, media files are removed.
  Future<void> deleteTrip(String id) async {
    await _trips.delete(id);
    await _media.deleteTripMedia(id);
  }
}
