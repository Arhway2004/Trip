/// Base type for business-rule violations raised by the domain or
/// application layers (as opposed to programming errors).
class DomainException implements Exception {
  const DomainException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class EntityNotFoundException extends DomainException {
  const EntityNotFoundException(String entity, String id) : super('$entity $id not found');
}
