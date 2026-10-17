import 'package:geolocator/geolocator.dart';
import 'package:wanderplan/contexts/places/application/location_service.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';

/// Device GPS via the geolocator plugin (WGS84). One-shot, foreground only.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) throw const LocationException(LocationFailure.denied);
    if (permission == LocationPermission.deniedForever) throw const LocationException(LocationFailure.deniedForever);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      return GeoPoint.tryCreate(pos.latitude, pos.longitude) ??
          (throw const LocationException(LocationFailure.unavailable));
    } on LocationException {
      rethrow;
    } catch (_) {
      throw const LocationException(LocationFailure.unavailable);
    }
  }
}
