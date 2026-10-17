import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:wanderplan/shared/presentation/l10n_helpers.dart';

/// "UTC+07:00" style offset label for an IANA zone at the current instant.
String utcOffsetLabel(String zone, [DateTime? at]) {
  try {
    final offset = tz.TZDateTime.from(at ?? DateTime.now(), tz.getLocation(zone)).timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final m = offset.inMinutes.abs();
    return 'UTC$sign${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  } catch (_) {
    return 'UTC';
  }
}

Future<String?> showTimeZonePicker(BuildContext context, {required String current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TimeZoneSheet(current: current),
  );
}

class _TimeZoneSheet extends StatefulWidget {
  const _TimeZoneSheet({required this.current});
  final String current;

  @override
  State<_TimeZoneSheet> createState() => _TimeZoneSheetState();
}

class _TimeZoneSheetState extends State<_TimeZoneSheet> {
  late final List<String> _all = tz.timeZoneDatabase.locations.keys.where((z) => z.contains('/')).toList()..sort();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().replaceAll(' ', '_');
    final items = q.isEmpty ? _all : _all.where((z) => z.toLowerCase().contains(q)).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.l10n.searchTimeZone),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final z = items[i];
                return ListTile(
                  title: Text(z.replaceAll('_', ' ')),
                  trailing: Text(utcOffsetLabel(z)),
                  selected: z == widget.current,
                  onTap: () => Navigator.pop(context, z),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
