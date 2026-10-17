import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/trip/application/trip_queries.dart';

export 'package:wanderplan/contexts/trip/application/trip_queries.dart' show TripFilter, TripSummary, matchesFilter;

final tripsProvider = StreamProvider<List<TripSummary>>((ref) => ref.watch(tripQueryServiceProvider).watchSummaries());

final tripProvider = StreamProvider.family<TripSummary?, String>(
  (ref, id) => ref.watch(tripQueryServiceProvider).watchSummary(id),
);

class TripFilterController extends Notifier<TripFilter> {
  @override
  TripFilter build() => TripFilter.all;
  void set(TripFilter f) => state = f;
}

final tripFilterProvider = NotifierProvider<TripFilterController, TripFilter>(TripFilterController.new);
