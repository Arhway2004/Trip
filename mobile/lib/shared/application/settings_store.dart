/// Small key/value store for app preferences (language, …).
abstract interface class SettingsStore {
  Future<String?> get(String key);

  /// Null removes the key.
  Future<void> set(String key, String? value);
  Future<void> clear();
}
