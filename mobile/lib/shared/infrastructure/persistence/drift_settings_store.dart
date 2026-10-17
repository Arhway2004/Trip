import 'package:wanderplan/shared/application/settings_store.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftSettingsStore implements SettingsStore {
  const DriftSettingsStore(this._db);
  final AppDatabase _db;

  @override
  Future<String?> get(String key) => _db.getSetting(key);

  @override
  Future<void> set(String key, String? value) => _db.setSetting(key, value);

  @override
  Future<void> clear() => _db.delete(_db.appSettings).go();
}
