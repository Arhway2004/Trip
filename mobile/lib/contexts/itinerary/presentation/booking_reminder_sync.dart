import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';

/// Re-schedules a trip's "time to book" notifications in the app's language.
/// Failures (e.g. notifications unavailable) never block saving the plan.
Future<void> syncBookingReminders(BuildContext context, WidgetRef ref, String tripId) async {
  final l = context.l10n;
  final locale = context.localeTag;
  try {
    await ref
        .read(bookingReminderServiceProvider)
        .syncTrip(
          tripId,
          title: (_) => l.reminderTitle,
          body: (a) => l.reminderBody(
            a.title,
            DateFormat.MMMd(locale).format(a.date.toDateTime()),
            a.reservationVia ?? '',
          ),
        );
  } catch (_) {
    // Reminders are a convenience; the plan itself is already saved.
  }
}
