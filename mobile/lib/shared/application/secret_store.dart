/// Port for small secrets (API keys) kept in the OS keychain/keystore, never
/// in the database, trip files, exports or logs.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
