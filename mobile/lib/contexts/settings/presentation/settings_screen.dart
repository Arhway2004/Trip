import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/contexts/places/domain/map_provider.dart';
import 'package:wanderplan/contexts/places/presentation/place_category_ui.dart';
import 'package:wanderplan/contexts/places/presentation/places_providers.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';

const _languageNames = {'en': 'English', 'zh': '简体中文', 'th': 'ไทย'};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = ref.watch(localeProvider);
    final mapPref = ref.watch(mapProviderPreferenceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.moreSettings)),
      body: ListView(
        children: [
          ListTile(title: Text(l.language, style: Theme.of(context).textTheme.titleSmall)),
          RadioGroup<String>(
            groupValue: locale?.languageCode ?? '',
            onChanged: (v) => ref.read(localeProvider.notifier).set(v == null || v.isEmpty ? null : Locale(v)),
            child: Column(
              children: [
                RadioListTile<String>(value: '', title: Text(l.languageSystem)),
                for (final code in supportedLanguageCodes)
                  RadioListTile<String>(value: code, title: Text(_languageNames[code]!)),
              ],
            ),
          ),
          const Divider(),
          ListTile(title: Text(l.mapProvider, style: Theme.of(context).textTheme.titleSmall)),
          RadioGroup<MapProviderPreference>(
            groupValue: mapPref,
            onChanged: (v) {
              if (v != null) ref.read(mapProviderPreferenceProvider.notifier).set(v);
            },
            child: Column(
              children: [
                for (final p in MapProviderPreference.values)
                  RadioListTile<MapProviderPreference>(
                    value: p,
                    title: Text(p.label(l)),
                    subtitle: p == MapProviderPreference.auto ? Text(l.providerAutoHelp) : null,
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.flight_takeoff),
            title: Text(l.flightUpdates),
            subtitle: Text(l.flightUpdatesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.flightUpdates),
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.lock_outline), title: Text(l.privacyTitle), subtitle: Text(l.privacyBody)),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text(l.deleteAllData, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _confirmDeleteAll(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteAllData),
        content: Text(l.deleteAllDataBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.actionCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(dataManagementServiceProvider).deleteAllData();
    await ref.read(localeProvider.notifier).set(null);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.allDataDeleted)));
    }
  }
}
