import 'package:wanderplan/shared/domain/geo_point.dart';

enum LocationFailure { serviceDisabled, denied, deniedForever, unavailable }

/// Port for the device's current position. Asks for permission only when
/// called (the user tapped "my location"); never tracks in the background.
abstract interface class LocationService {
  Future<GeoPoint> current();
}

class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;
  @override
  String toString() => 'LocationException: ${failure.name}';
}
