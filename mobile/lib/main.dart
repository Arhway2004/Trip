import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:wanderplan/app/app.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/shared/infrastructure/media/media_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await initializeDateFormatting();

  final deviceZone = await _deviceTimeZone();
  final media = await MediaStorage.appDefault();
  final db = AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        mediaStorageProvider.overrideWithValue(media),
        deviceTimeZoneProvider.overrideWithValue(deviceZone),
      ],
      child: const WanderPlanApp(),
    ),
  );
}

Future<String> _deviceTimeZone() async {
  try {
    final id = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.getLocation(id); // Validate it exists in the bundled database.
    return id;
  } catch (_) {
    return 'UTC';
  }
}
