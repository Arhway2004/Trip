import 'dart:io';

import 'package:wanderplan/contexts/budget/application/budget_service.dart';
import 'package:wanderplan/contexts/budget/application/rate_source.dart';
import 'package:wanderplan/contexts/budget/infrastructure/drift_budget_repositories.dart';
import 'package:wanderplan/contexts/budget/infrastructure/frankfurter_rate_source.dart';
import 'package:wanderplan/contexts/checklist/application/checklist_service.dart';
import 'package:wanderplan/contexts/checklist/infrastructure/drift_checklist_repository.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_status_ports.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_update_service.dart';
import 'package:wanderplan/contexts/flight_status/infrastructure/backend_flight_server.dart';
import 'package:wanderplan/contexts/flight_status/infrastructure/drift_flight_status_repository.dart';
import 'package:wanderplan/contexts/gallery/application/gallery_service.dart';
import 'package:wanderplan/contexts/gallery/infrastructure/drift_photo_repository.dart';
import 'package:wanderplan/contexts/itinerary/application/booking_reminders.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/itinerary/infrastructure/drift_activity_repository.dart';
import 'package:wanderplan/contexts/itinerary/infrastructure/drift_day_settings_repository.dart';
import 'package:wanderplan/contexts/itinerary/infrastructure/local_notification_scheduler.dart';
import 'package:wanderplan/contexts/places/application/location_link_service.dart';
import 'package:wanderplan/contexts/places/application/location_service.dart';
import 'package:wanderplan/contexts/places/application/map_services.dart';
import 'package:wanderplan/contexts/places/application/place_search.dart';
import 'package:wanderplan/contexts/places/application/route_service.dart';
import 'package:wanderplan/contexts/places/application/saved_place_service.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/infrastructure/amap_web_service.dart';
import 'package:wanderplan/contexts/places/infrastructure/drift_saved_place_repository.dart';
import 'package:wanderplan/contexts/places/infrastructure/geolocator_location_service.dart';
import 'package:wanderplan/contexts/places/infrastructure/http_link_expander.dart';
import 'package:wanderplan/contexts/places/infrastructure/osm_place_search.dart';
import 'package:wanderplan/contexts/places/infrastructure/osrm_route_service.dart';
import 'package:wanderplan/contexts/settings/application/data_management_service.dart';
import 'package:wanderplan/contexts/sharing/application/trip_package_service.dart';
import 'package:wanderplan/contexts/trip/application/trip_queries.dart';
import 'package:wanderplan/contexts/trip/application/trip_service.dart';
import 'package:wanderplan/contexts/trip/infrastructure/drift_trip_repository.dart';
import 'package:wanderplan/shared/application/media_store.dart';
import 'package:wanderplan/shared/application/secret_store.dart';
import 'package:wanderplan/shared/application/settings_store.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';
import 'package:wanderplan/shared/infrastructure/persistence/drift_settings_store.dart';
import 'package:wanderplan/shared/infrastructure/persistence/drift_unit_of_work.dart';
import 'package:wanderplan/shared/infrastructure/secrets/keychain_secret_store.dart';
import 'package:wanderplan/shared/infrastructure/uuid_id_generator.dart';

/// Composition root: the only place that knows which adapters implement
/// which ports. The UI (via Riverpod) and tests both build the app from here.
class ServiceRegistry {
  ServiceRegistry._({
    required this.trips,
    required this.tripQueries,
    required this.gallery,
    required this.checklist,
    required this.itinerary,
    required this.budget,
    required this.savedPlaces,
    required this.maps,
    required this.location,
    required this.links,
    required this.reminders,
    required this.flightUpdates,
    required this.packages,
    required this.data,
    required this.settings,
  });

  factory ServiceRegistry.create({
    required AppDatabase db,
    required MediaStore media,
    required Future<Directory> Function() tempDir,
    Clock clock = DateTime.now,
    IdGenerator ids = const UuidIdGenerator(),
    RateSource? rateSource,
    PlaceSearch? placeSearch,
    RouteService? routeService,
    LocationService? locationService,
    LinkExpander? linkExpander,
    ReminderScheduler? reminderScheduler,
    FlightServer? flightServer,
    SecretStore? secretStore,
    String amapWebKey = '',
    String serverUrl = '',
  }) {
    final uow = DriftUnitOfWork(db);
    final tripRepo = DriftTripRepository(db);
    final photoRepo = DriftPhotoRepository(db);
    final checklistRepo = DriftChecklistRepository(db);
    final settings = DriftSettingsStore(db);
    final activityRepo = DriftActivityRepository(db);
    final savedPlaces = SavedPlaceService(places: DriftSavedPlaceRepository(db), ids: ids, clock: clock);
    // Amap's web services are used only when a key is configured.
    final amap = amapWebKey.isEmpty ? null : AmapWebService(amapWebKey);
    final notifications = reminderScheduler ?? LocalNotificationScheduler();
    final maps = MapServices(
      osmSearch: placeSearch ?? OsmPlaceSearch(),
      osmRouting: routeService ?? OsrmRouteService(),
      amapSearch: amap,
      amapRouting: amap,
    );

    final gallery = GalleryService(photos: photoRepo, trips: tripRepo, media: media, uow: uow, ids: ids, clock: clock);
    final checklist = ChecklistService(items: checklistRepo, uow: uow, ids: ids, clock: clock);
    final itinerary = ItineraryService(
      activities: activityRepo,
      days: DriftDaySettingsRepository(db),
      uow: uow,
      ids: ids,
      clock: clock,
    );
    final budget = BudgetService(
      expenses: DriftExpenseRepository(db),
      rates: DriftExchangeRateRepository(db),
      activities: activityRepo,
      trips: tripRepo,
      rateSource: rateSource ?? FrankfurterRateSource(),
      ids: ids,
      clock: clock,
    );
    return ServiceRegistry._(
      trips: TripService(
        trips: tripRepo,
        gallery: gallery,
        checklist: checklist,
        itinerary: itinerary,
        budget: budget,
        places: savedPlaces,
        media: media,
        uow: uow,
        ids: ids,
        clock: clock,
      ),
      tripQueries: TripQueryService(trips: tripRepo, photos: photoRepo, checklist: checklistRepo),
      gallery: gallery,
      checklist: checklist,
      itinerary: itinerary,
      budget: budget,
      savedPlaces: savedPlaces,
      maps: maps,
      reminders: BookingReminderService(
        activities: activityRepo,
        trips: tripRepo,
        scheduler: notifications,
        clock: clock,
      ),
      flightUpdates: FlightUpdateService(
        server: flightServer ?? BackendFlightServer(),
        secrets: secretStore ?? const KeychainSecretStore(),
        statuses: DriftFlightStatusRepository(db),
        activities: activityRepo,
        trips: tripRepo,
        notifications: notifications,
        clock: clock,
        serverUrl: serverUrl,
      ),
      links: LocationLinkService(
        expander: linkExpander ?? HttpLinkExpander(),
        search: () => maps.searchFor(MapProviderId.openStreetMap),
      ),
      location: locationService ?? const GeolocatorLocationService(),
      packages: TripPackageService(
        trips: tripRepo,
        gallery: gallery,
        checklist: checklist,
        itinerary: itinerary,
        budget: budget,
        places: savedPlaces,
        media: media,
        uow: uow,
        ids: ids,
        clock: clock,
        tempDir: tempDir,
      ),
      data: DataManagementService(trips: tripRepo, settings: settings, media: media, uow: uow),
      settings: settings,
    );
  }

  final TripService trips;
  final TripQueryService tripQueries;
  final GalleryService gallery;
  final ChecklistService checklist;
  final ItineraryService itinerary;
  final BudgetService budget;
  final SavedPlaceService savedPlaces;
  final MapServices maps;
  final LocationService location;
  final LocationLinkService links;
  final BookingReminderService reminders;
  final FlightUpdateService flightUpdates;
  final TripPackageService packages;
  final DataManagementService data;
  final SettingsStore settings;
}
