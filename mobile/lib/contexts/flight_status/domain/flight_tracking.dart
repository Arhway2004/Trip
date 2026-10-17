import 'package:wanderplan/contexts/flight_status/domain/flight_status.dart';
import 'package:wanderplan/contexts/itinerary/domain/activity.dart';

/// A planned flight the app can follow: has a flight number, not cancelled.
/// How often it is checked, and against which provider, is decided by the
/// server (one shared check per flight and date).
bool isTrackable(Activity a) => a.kind == ActivityKind.flight && !a.isCancelled && parseFlightNumber(a.serviceNumber) != null;
