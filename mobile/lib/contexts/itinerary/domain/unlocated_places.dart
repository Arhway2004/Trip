import 'package:wanderplan/contexts/itinerary/domain/activity.dart';

/// A place name used by activities that have no coordinates for it yet.
class UnlocatedPlace {
  const UnlocatedPlace(this.name, this.activities);
  final String name;

  /// Activities (not cancelled) that use [name] as location or destination.
  final List<Activity> activities;
}

/// Distinct place names still missing coordinates, in plan order. Lets the
/// user locate "Kunming Changshui International Airport" once for every
/// activity that mentions it.
List<UnlocatedPlace> unlocatedPlaces(List<Activity> activities) {
  final byName = <String, List<Activity>>{};
  void add(PlaceRef p, Activity a) {
    final name = p.name?.trim();
    if (p.point != null || name == null || name.isEmpty) return;
    final list = byName.putIfAbsent(name, () => []);
    if (!list.contains(a)) list.add(a);
  }

  for (final a in [...activities]..sort(compareActivities)) {
    if (a.isCancelled) continue;
    add(a.location, a);
    if (a.kind.isTransport) add(a.destination, a);
  }
  return [for (final e in byName.entries) UnlocatedPlace(e.key, e.value)];
}
