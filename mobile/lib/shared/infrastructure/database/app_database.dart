import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:wanderplan/shared/infrastructure/database/tables.dart';

export 'package:wanderplan/shared/infrastructure/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Trips,
    TripDestinations,
    TripBanners,
    TripPhotos,
    AppSettings,
    TripTodos,
    Activities,
    Expenses,
    ExchangeRates,
    SavedPlaces,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production database stored in the app documents directory.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'wanderplan'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Each schema version adds an `if (from < N)` step.
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(tripTodos);
      if (from < 3) {
        await m.createTable(activities);
        await m.createTable(expenses);
        await m.createTable(exchangeRates);
      }
      if (from >= 3 && from < 4) await m.addColumn(activities, activities.hasTime);
      if (from < 5) await m.createTable(savedPlaces);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await (delete(appSettings)..where((t) => t.key.equals(key))).go();
    } else {
      await into(appSettings).insertOnConflictUpdate(SettingRow(key: key, value: value));
    }
  }
}
