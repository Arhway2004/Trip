import 'package:flutter/material.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/domain/place_category.dart';
import 'package:wanderplan/contexts/places/domain/route.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';

extension PlaceCategoryUi on PlaceCategory {
  String label(AppLocalizations l) => switch (this) {
    PlaceCategory.attraction => l.placeAttraction,
    PlaceCategory.restaurant => l.placeRestaurant,
    PlaceCategory.hotel => l.placeHotel,
    PlaceCategory.airport => l.placeAirport,
    PlaceCategory.railwayStation => l.placeRailwayStation,
    PlaceCategory.busStation => l.placeBusStation,
    PlaceCategory.other => l.placeOther,
  };

  IconData get icon => switch (this) {
    PlaceCategory.attraction => Icons.attractions_outlined,
    PlaceCategory.restaurant => Icons.restaurant_outlined,
    PlaceCategory.hotel => Icons.hotel_outlined,
    PlaceCategory.airport => Icons.local_airport_outlined,
    PlaceCategory.railwayStation => Icons.train_outlined,
    PlaceCategory.busStation => Icons.directions_bus_outlined,
    PlaceCategory.other => Icons.place_outlined,
  };

  /// The itinerary activity a saved place becomes when put on a day.
  ActivityKind get activityKind => switch (this) {
    PlaceCategory.attraction => ActivityKind.sightseeing,
    PlaceCategory.restaurant => ActivityKind.food,
    PlaceCategory.hotel => ActivityKind.hotel,
    _ => ActivityKind.other,
  };
}

extension TravelModeUi on TravelMode {
  String label(AppLocalizations l) => switch (this) {
    TravelMode.walking => l.modeWalking,
    TravelMode.cycling => l.modeCycling,
    TravelMode.driving => l.modeDriving,
  };

  IconData get icon => switch (this) {
    TravelMode.walking => Icons.directions_walk,
    TravelMode.cycling => Icons.directions_bike,
    TravelMode.driving => Icons.directions_car_outlined,
  };
}

extension MapProviderUi on MapProviderId {
  String label(AppLocalizations l) => switch (this) {
    MapProviderId.openStreetMap => l.providerOsm,
    MapProviderId.amap => l.providerAmap,
  };
}

extension MapProviderPreferenceUi on MapProviderPreference {
  String label(AppLocalizations l) => switch (this) {
    MapProviderPreference.auto => l.providerAuto,
    MapProviderPreference.openStreetMap => l.providerOsm,
    MapProviderPreference.amap => l.providerAmap,
  };
}
