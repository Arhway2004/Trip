import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wanderplan/contexts/trip/presentation/banner/banner_editor_screen.dart';
import 'package:wanderplan/contexts/gallery/presentation/gallery_screen.dart';
import 'package:wanderplan/contexts/flight_status/presentation/flight_updates_settings_screen.dart';
import 'package:wanderplan/contexts/settings/presentation/settings_screen.dart';
import 'package:wanderplan/contexts/budget/presentation/budget_screen.dart';
import 'package:wanderplan/contexts/checklist/presentation/checklist_screen.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';
import 'package:wanderplan/contexts/itinerary/presentation/activity_editor_screen.dart';
import 'package:wanderplan/contexts/itinerary/presentation/bookings_screen.dart';
import 'package:wanderplan/contexts/itinerary/presentation/timeline_screen.dart';
import 'package:wanderplan/contexts/places/presentation/locate_places_screen.dart';
import 'package:wanderplan/contexts/places/presentation/trip_map_screen.dart';
import 'package:wanderplan/shared/domain/enum_by_name.dart';
import 'package:wanderplan/shared/domain/local_date.dart';
import 'package:wanderplan/contexts/trip/presentation/home_screen.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_dashboard_screen.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_form_screen.dart';

abstract final class Routes {
  static const trips = '/trips';
  static const newTrip = '/trips/new';
  static const settings = '/settings';
  static const flightUpdates = '/settings/flight-updates';
  static String trip(String id) => '/trips/$id';
  static String editTrip(String id) => '/trips/$id/edit';
  static String banner(String id) => '/trips/$id/banner';
  static String gallery(String id) => '/trips/$id/gallery';
  static String todos(String id) => '/trips/$id/todos';
  static String tripMap(String id, {LocalDate? day}) => '/trips/$id/map${day == null ? '' : '?day=${day.toIso()}'}';
  static String locatePlaces(String id) => '/trips/$id/map/locate';
  static String tripTimeline(String id, {LocalDate? day}) =>
      '/trips/$id/timeline${day == null ? '' : '?day=${day.toIso()}'}';
  static String tripBudget(String id) => '/trips/$id/budget';
  static String bookings(String id) => '/trips/$id/bookings';
  static String newActivity(String id, {LocalDate? date, ActivityKind? kind}) {
    final q = [if (date != null) 'date=${date.toIso()}', if (kind != null) 'kind=${kind.name}'].join('&');
    return '/trips/$id/activity/new${q.isEmpty ? '' : '?$q'}';
  }

  static String editActivity(String id, String activityId) => '/trips/$id/activity/$activityId';
}

/// Every trip owns its tools (map, timeline, budget, …) as sub-routes, so
/// there is no global "current trip" and no trip-scoped bottom tabs.
final routerProvider = Provider<GoRouter>((ref) {
  GoRoute tripChild(String path, Widget Function(String id) build) =>
      GoRoute(path: path, builder: (_, s) => build(s.pathParameters['id']!));

  return GoRouter(
    initialLocation: Routes.trips,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.trips),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
        routes: [GoRoute(path: 'flight-updates', builder: (_, _) => const FlightUpdatesSettingsScreen())],
      ),
      GoRoute(
        path: Routes.trips,
        builder: (_, _) => const HomeScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const TripFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, s) => TripDashboardScreen(tripId: s.pathParameters['id']!),
            routes: [
              tripChild('edit', (id) => TripFormScreen(tripId: id)),
              tripChild('banner', (id) => BannerEditorScreen(tripId: id)),
              tripChild('gallery', (id) => GalleryScreen(tripId: id)),
              tripChild('todos', (id) => TodoListScreen(tripId: id)),
              GoRoute(
                path: 'map',
                builder: (_, s) => TripMapScreen(
                  tripId: s.pathParameters['id']!,
                  initialDay: LocalDate.tryParse(s.uri.queryParameters['day']),
                ),
                routes: [tripChild('locate', (id) => LocatePlacesScreen(tripId: id))],
              ),
              GoRoute(
                path: 'timeline',
                builder: (_, s) => TimelineScreen(
                  tripId: s.pathParameters['id']!,
                  initialDate: LocalDate.tryParse(s.uri.queryParameters['day']),
                ),
              ),
              tripChild('budget', (id) => BudgetScreen(tripId: id)),
              tripChild('bookings', (id) => BookingsScreen(tripId: id)),
              GoRoute(
                path: 'activity/new',
                builder: (_, s) => ActivityEditorScreen(
                  tripId: s.pathParameters['id']!,
                  initialDate: LocalDate.tryParse(s.uri.queryParameters['date']),
                  initialKind: enumByName(ActivityKind.values, s.uri.queryParameters['kind']),
                ),
              ),
              GoRoute(
                path: 'activity/:aid',
                builder: (_, s) =>
                    ActivityEditorScreen(tripId: s.pathParameters['id']!, activityId: s.pathParameters['aid']),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
