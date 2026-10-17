import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';

/// Opens turn-by-turn navigation in an external app (the app itself does not navigate).
/// Amap expects GCJ-02 coordinates in mainland China, so those are converted.
Future<void> showNavigateSheet(BuildContext context, GeoPoint point, String? name) async {
  final l = context.l10n;
  final label = Uri.encodeComponent(name ?? '');
  final gcj = Gcj02.fromWgs84(point);
  final links = <(String, IconData, Uri)>[
    (
      l.openGoogleMaps,
      Icons.map_outlined,
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}'),
    ),
    (
      l.openAppleMaps,
      Icons.apple,
      Uri.parse('https://maps.apple.com/?daddr=${point.latitude},${point.longitude}&q=$label'),
    ),
    (
      l.openAmap,
      Icons.navigation_outlined,
      Uri.parse(
        'https://uri.amap.com/navigation?to=${gcj.longitude},${gcj.latitude},$label&coordinate=gaode&callnative=1',
      ),
    ),
  ];
  final messenger = ScaffoldMessenger.of(context);
  final chosen = await showModalBottomSheet<Uri>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.navigateWith, style: Theme.of(c).textTheme.titleMedium),
          ),
          for (final (title, icon, uri) in links)
            ListTile(leading: Icon(icon), title: Text(title), onTap: () => Navigator.pop(c, uri)),
        ],
      ),
    ),
  );
  if (chosen == null) return;
  final ok = await launchUrl(chosen, mode: LaunchMode.externalApplication);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.openFailed)));
}
