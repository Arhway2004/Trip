import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/domain/saved_place.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';

final savedPlacesProvider = StreamProvider.family<List<SavedPlace>, String>(
  (ref, tripId) => ref.watch(savedPlaceServiceProvider).watchPlaces(tripId),
);

/// False in widget tests so maps don't fetch tiles from the network.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

const _providerKey = 'mapProvider';

/// The user's map provider choice (Settings and the map's menu). Persisted.
class MapProviderPreferenceController extends Notifier<MapProviderPreference> {
  @override
  MapProviderPreference build() {
    _load();
    return MapProviderPreference.auto;
  }

  Future<void> _load() async {
    final v = await ref.read(serviceRegistryProvider).settings.get(_providerKey);
    final p = enumByName(MapProviderPreference.values, v);
    if (p != null && p != state) state = p;
  }

  Future<void> set(MapProviderPreference p) async {
    state = p;
    await ref.read(serviceRegistryProvider).settings.set(_providerKey, p == MapProviderPreference.auto ? null : p.name);
  }
}

final mapProviderPreferenceProvider = NotifierProvider<MapProviderPreferenceController, MapProviderPreference>(
  MapProviderPreferenceController.new,
);
