import 'package:wanderplan/shared/domain/geo_point.dart';

/// Straight-line distances are this much shorter than real paths, on average.
const detourFactor = 1.3;

/// How the traveller moves between two stops.
///
/// Walking, cycling and driving are routed on real roads. [transit] (train,
/// metro, bus) is never calculated: no free provider returns timetabled routes,
/// so its duration is the traveller's own estimate.
enum TravelMode {
  walking,
  cycling,
  driving,
  transit;

  /// Routed by a road-routing provider.
  bool get isRouted => this != transit;

  /// Modes offered for whole-day road routing.
  static const routed = [walking, cycling, driving];

  /// Rough door-to-door speed for straight-line estimates when no route is
  /// available (labelled as estimates wherever shown).
  double get estimateKmh => switch (this) {
    walking => 4.5,
    cycling => 13,
    driving => 25,
    transit => 20,
  };
}

/// A road route returned by a routing provider. Geometry is WGS84.
class RouteResult {
  const RouteResult({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.mode,
    required this.source,
    this.legs = const [],
  });

  /// Per-leg (distance m, duration s) between consecutive waypoints, when the
  /// provider reports them.
  final List<(double, double)> legs;

  final List<GeoPoint> geometry;
  final double distanceMeters;

  /// The provider's typical estimate; not live traffic and not a guarantee.
  final double durationSeconds;
  final TravelMode mode;

  /// e.g. `routing:osrm-fossgis`, `routing:amap`
  final String source;
}

/// Travel times between every pair of points (seconds; null = no route).
class TravelMatrix {
  const TravelMatrix(this.seconds, {required this.source, required this.estimated});
  final List<List<double?>> seconds;

  /// `routing:<provider>` or `estimate:straight-line`.
  final String source;

  /// True when computed from straight-line distance rather than a router.
  final bool estimated;

  double? between(int from, int to) => seconds[from][to];
}

/// Travel-time estimates from straight-line distance, used only when no
/// router answers (and always labelled as estimates).
TravelMatrix estimateMatrix(List<GeoPoint> points, TravelMode mode) => TravelMatrix(
  [
    for (final a in points)
      [for (final b in points) a.distanceKmTo(b) * detourFactor / mode.estimateKmh * 3600],
  ],
  source: 'estimate:straight-line',
  estimated: true,
);
