/// Produces globally unique, stable identifiers for new entities.
abstract interface class IdGenerator {
  String newId();
}
