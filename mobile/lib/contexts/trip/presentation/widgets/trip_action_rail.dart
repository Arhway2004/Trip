import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';

/// Map / Timeline / Budget shortcuts that live on the right edge of every
/// trip banner, so each trip carries its own planning tools.
class TripActionRail extends StatelessWidget {
  const TripActionRail({
    super.key,
    required this.tripId,
    this.buttonSize = 40,
    this.spacing = 8,
  });

  final String tripId;
  final double buttonSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (Icons.map_outlined, l.tabMap, Routes.tripMap(tripId)),
      (
        Icons.view_timeline_outlined,
        l.tabTimeline,
        Routes.tripTimeline(tripId),
      ),
      (
        Icons.account_balance_wallet_outlined,
        l.tabBudget,
        Routes.tripBudget(tripId),
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          GlassIconButton(
            icon: items[i].$1,
            tooltip: items[i].$2,
            size: buttonSize,
            onPressed: () => context.push(items[i].$3),
          ),
        ],
      ],
    );
  }
}

/// Labeled shortcuts remain visible outside the dashboard cover.
class TripQuickActions extends StatelessWidget {
  const TripQuickActions({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final actions = [
      (
        Icons.view_timeline_outlined,
        l.tabTimeline,
        Routes.tripTimeline(tripId),
      ),
      (Icons.map_outlined, l.tabMap, Routes.tripMap(tripId)),
      (
        Icons.account_balance_wallet_outlined,
        l.tabBudget,
        Routes.tripBudget(tripId),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns = MediaQuery.textScalerOf(context).scale(14) > 18
            ? 1
            : box.maxWidth < 330
            ? 2
            : 3;
        final width = (box.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, label, route) in actions)
              SizedBox(
                width: width,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => context.push(route),
                  icon: Icon(icon, size: 18),
                  label: Text(label, textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
    );
  }
}
