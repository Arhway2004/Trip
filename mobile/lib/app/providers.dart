import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wanderplan/app/service_registry.dart';
import 'package:wanderplan/contexts/budget/application/budget_service.dart';
import 'package:wanderplan/contexts/checklist/application/checklist_service.dart';
import 'package:wanderplan/contexts/flight_status/application/flight_update_service.dart';
import 'package:wanderplan/contexts/gallery/application/gallery_service.dart';
import 'package:wanderplan/contexts/itinerary/application/booking_reminders.dart';
import 'package:wanderplan/contexts/itinerary/application/itinerary_service.dart';
import 'package:wanderplan/contexts/places/application/location_link_service.dart';
import 'package:wanderplan/contexts/places/application/location_service.dart';
import 'package:wanderplan/contexts/places/application/map_services.dart';
import 'package:wanderplan/contexts/places/application/saved_place_service.dart';
import 'package:wanderplan/contexts/settings/application/data_management_service.dart';
import 'package:wanderplan/contexts/sharing/application/trip_package_service.dart';
import 'package:wanderplan/contexts/trip/application/trip_queries.dart';
import 'package:wanderplan/contexts/trip/application/trip_service.dart';
import 'package:wanderplan/shared/application/media_store.dart';
import 'package:wanderplan/shared/domain/clock.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

// --- Infrastructure (overridden in main() and in tests) --------------------

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('databaseProvider'));
final mediaStorageProvider = Provider<MediaStore>((ref) => throw UnimplementedError('mediaStorageProvider'));
final tempDirProvider = Provider<Future<Directory> Function()>((ref) => getTemporaryDirectory);

/// The device's IANA zone, used as the default for new trips.
final deviceTimeZoneProvider = Provider<String>((ref) => 'UTC');

/// Amap Web Service key, from `--dart-define=AMAP_WEB_KEY=…` (empty = not configured).
final amapWebKeyProvider = Provider<String>((ref) => const String.fromEnvironment('AMAP_WEB_KEY'));

/// WanderPlan server address, part of the build (not a secret):
/// `--dart-define=WANDERPLAN_API_URL=…` (tool/run_phone.sh sets it for testing).
/// Empty = this build has no server, so live flight updates are off.
final serverUrlProvider = Provider<String>((ref) => const String.fromEnvironment('WANDERPLAN_API_URL'));

/// Source of "now"; tests override it with a fixed time.
final clockProvider = Provider<Clock>((ref) => DateTime.now);

// --- Application services (built once by the composition root) ------------

final serviceRegistryProvider = Provider<ServiceRegistry>(
  (ref) => ServiceRegistry.create(
    db: ref.watch(databaseProvider),
    media: ref.watch(mediaStorageProvider),
    tempDir: ref.watch(tempDirProvider),
    clock: ref.watch(clockProvider),
    amapWebKey: ref.watch(amapWebKeyProvider),
    serverUrl: ref.watch(serverUrlProvider),
  ),
);

final tripServiceProvider = Provider<TripService>((ref) => ref.watch(serviceRegistryProvider).trips);
final tripQueryServiceProvider = Provider<TripQueryService>((ref) => ref.watch(serviceRegistryProvider).tripQueries);
final galleryServiceProvider = Provider<GalleryService>((ref) => ref.watch(serviceRegistryProvider).gallery);
final checklistServiceProvider = Provider<ChecklistService>((ref) => ref.watch(serviceRegistryProvider).checklist);
final itineraryServiceProvider = Provider<ItineraryService>((ref) => ref.watch(serviceRegistryProvider).itinerary);
final budgetServiceProvider = Provider<BudgetService>((ref) => ref.watch(serviceRegistryProvider).budget);
final savedPlaceServiceProvider = Provider<SavedPlaceService>((ref) => ref.watch(serviceRegistryProvider).savedPlaces);
final mapServicesProvider = Provider<MapServices>((ref) => ref.watch(serviceRegistryProvider).maps);
final bookingReminderServiceProvider = Provider<BookingReminderService>(
  (ref) => ref.watch(serviceRegistryProvider).reminders,
);
/// Automatic flight checks on app start/resume (tests turn them off).
final flightAutoCheckProvider = Provider<bool>((ref) => true);
final flightUpdateServiceProvider = Provider<FlightUpdateService>((ref) => ref.watch(serviceRegistryProvider).flightUpdates);
final locationLinkServiceProvider = Provider<LocationLinkService>((ref) => ref.watch(serviceRegistryProvider).links);
final locationServiceProvider = Provider<LocationService>((ref) => ref.watch(serviceRegistryProvider).location);
final tripPackageServiceProvider = Provider<TripPackageService>((ref) => ref.watch(serviceRegistryProvider).packages);
final dataManagementServiceProvider = Provider<DataManagementService>((ref) => ref.watch(serviceRegistryProvider).data);

// --- UI-wide state ----------------------------------------------------------

/// Ticks every 30 seconds so countdowns stay live without wasting battery.
final nowProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  final controller = StreamController<DateTime>();
  controller.add(clock());
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => controller.add(clock()));
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Synchronous "now" for widgets: latest tick, or the clock before the first.
final currentTimeProvider = Provider<DateTime>((ref) => ref.watch(nowProvider).value ?? ref.watch(clockProvider)());

const _localeKey = 'locale';
const supportedLanguageCodes = ['en', 'zh', 'th'];

/// User-selected app language. Null follows the system.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final code = await ref.read(serviceRegistryProvider).settings.get(_localeKey);
    if (code != null && supportedLanguageCodes.contains(code)) state = Locale(code);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    await ref.read(serviceRegistryProvider).settings.set(_localeKey, locale?.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);
