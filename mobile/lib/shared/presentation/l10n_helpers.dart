import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:wanderplan/contexts/trip/application/trip_queries.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';
import 'package:wanderplan/shared/domain/countdown.dart';
import 'package:wanderplan/shared/domain/local_date.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeTag => Localizations.localeOf(this).toLanguageTag();
}

extension TripStatusL10n on TripStatus {
  String label(AppLocalizations l) => switch (this) {
    TripStatus.dreaming => l.statusDreaming,
    TripStatus.planning => l.statusPlanning,
    TripStatus.upcoming => l.statusUpcoming,
    TripStatus.traveling => l.statusTraveling,
    TripStatus.completed => l.statusCompleted,
    TripStatus.archived => l.statusArchived,
  };

  IconData get icon => switch (this) {
    TripStatus.dreaming => Icons.auto_awesome_outlined,
    TripStatus.planning => Icons.edit_calendar_outlined,
    TripStatus.upcoming => Icons.flight_takeoff,
    TripStatus.traveling => Icons.explore_outlined,
    TripStatus.completed => Icons.check_circle_outline,
    TripStatus.archived => Icons.inventory_2_outlined,
  };
}

extension TripFilterL10n on TripFilter {
  String label(AppLocalizations l) => switch (this) {
    TripFilter.all => l.filterAll,
    TripFilter.upcoming => l.filterUpcoming,
    TripFilter.traveling => l.filterTraveling,
    TripFilter.completed => l.filterCompleted,
    TripFilter.archived => l.filterArchived,
  };
}

extension TripStageL10n on TripStage {
  String label(AppLocalizations l) => switch (this) {
    TripStage.dreaming => l.statusDreaming,
    TripStage.planning => l.statusPlanning,
  };
}

extension TravelStyleL10n on TravelStyle {
  String label(AppLocalizations l) => switch (this) {
    TravelStyle.relaxed => l.styleRelaxed,
    TravelStyle.balanced => l.styleBalanced,
    TravelStyle.packed => l.stylePacked,
    TravelStyle.budget => l.styleBudget,
    TravelStyle.comfort => l.styleComfort,
    TravelStyle.luxury => l.styleLuxury,
    TravelStyle.adventure => l.styleAdventure,
    TravelStyle.family => l.styleFamily,
  };
}

extension TitlePlacementL10n on TitlePlacement {
  String label(AppLocalizations l) => switch (this) {
    TitlePlacement.topLeft => l.placementTopLeft,
    TitlePlacement.center => l.placementCenter,
    TitlePlacement.bottomLeft => l.placementBottomLeft,
    TitlePlacement.bottomCenter => l.placementBottomCenter,
  };
}

extension BannerStyleL10n on BannerStyle {
  String label(AppLocalizations l) => switch (this) {
    BannerStyle.classic => l.bannerStyleClassic,
    BannerStyle.minimal => l.bannerStyleMinimal,
    BannerStyle.bold => l.bannerStyleBold,
    BannerStyle.framed => l.bannerStyleFramed,
  };
}

/// Headline text for a countdown, e.g. "45 days to go" or "Day 3 of 10".
String countdownHeadline(AppLocalizations l, CountdownState c) => switch (c) {
  CountdownNoDate() => l.countdownNoDate,
  CountdownCompleted() => l.countdownCompleted,
  CountdownDuringTrip(:final dayNumber, :final totalDays) => l.countdownDayOf(dayNumber, totalDays),
  CountdownBeforeDeparture(hasDepartureTime: false, :final days) => l.countdownDaysToGo(days),
  CountdownBeforeDeparture(:final days, :final hours, :final minutes) => l.countdownRemaining(
    _dhm(l, days, hours, minutes),
  ),
};

String _dhm(AppLocalizations l, int d, int h, int m) {
  final parts = <String>[if (d > 0) l.unitDays(d), if (d > 0 || h > 0) l.unitHours(h), if (d == 0) l.unitMinutes(m)];
  return parts.join(l.localeName.startsWith('zh') ? ' ' : ', ');
}

String formatDate(BuildContext context, LocalDate d) => DateFormat.yMMMd(context.localeTag).format(d.toDateTime());

String formatDateRange(BuildContext context, LocalDate? start, LocalDate? end) {
  if (start == null) return context.l10n.datesUndecided;
  if (end == null || end == start) return formatDate(context, start);
  return '${formatDate(context, start)} – ${formatDate(context, end)}';
}

/// Formats [amount] in [currency] for the current locale.
String formatMoney(BuildContext context, double amount, String currency) {
  return NumberFormat.simpleCurrency(locale: context.localeTag, name: currency).format(amount);
}
