/// Parses a persisted enum name, returning null for unknown/legacy values.
T? enumByName<T extends Enum>(List<T> values, String? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
