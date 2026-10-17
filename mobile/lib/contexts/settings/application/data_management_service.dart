import 'package:wanderplan/contexts/trip/domain/trip_repository.dart';
import 'package:wanderplan/shared/application/media_store.dart';
import 'package:wanderplan/shared/application/settings_store.dart';
import 'package:wanderplan/shared/application/unit_of_work.dart';

/// "Delete all data" (privacy): every trip with its children, settings and media.
class DataManagementService {
  DataManagementService({
    required TripRepository trips,
    required SettingsStore settings,
    required MediaStore media,
    required UnitOfWork uow,
  }) : _trips = trips,
       _settings = settings,
       _media = media,
       _uow = uow;

  final TripRepository _trips;
  final SettingsStore _settings;
  final MediaStore _media;
  final UnitOfWork _uow;

  Future<void> deleteAllData() async {
    await _uow.run(() async {
      await _trips.deleteAll(); // destinations, banners, photos, checklists cascade
      await _settings.clear();
    });
    await _media.deleteAll();
  }
}
