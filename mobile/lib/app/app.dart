import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/contexts/flight_status/presentation/flight_status_l10n.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';

class WanderPlanApp extends ConsumerStatefulWidget {
  const WanderPlanApp({super.key});

  @override
  ConsumerState<WanderPlanApp> createState() => _WanderPlanAppState();
}

class _WanderPlanAppState extends ConsumerState<WanderPlanApp> with WidgetsBindingObserver {
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFlights());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkFlights();
  }

  /// Syncs planned flights with the WanderPlan server and reads their latest
  /// state when the app opens or comes back (at most every 10 minutes). It
  /// costs no flight-data requests: the server checks flights on its schedule.
  Future<void> _checkFlights() async {
    if (!ref.read(flightAutoCheckProvider)) return;
    final now = DateTime.now();
    if (_lastSync != null && now.difference(_lastSync!) < const Duration(minutes: 10)) return;
    _lastSync = now;
    try {
      final locale = ref.read(localeProvider) ?? WidgetsBinding.instance.platformDispatcher.locale;
      final l = lookupAppLocalizations(
        AppLocalizations.supportedLocales.any((s) => s.languageCode == locale.languageCode)
            ? Locale(locale.languageCode)
            : const Locale('en'),
      );
      await ref.read(flightUpdateServiceProvider).sync(texts: flightChangeTexts(l));
    } catch (_) {
      // Live updates are best-effort; the plan never depends on them.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
