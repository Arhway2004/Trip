/// Runs a group of repository calls atomically. Application services use it
/// whenever one use case writes to more than one aggregate.
abstract interface class UnitOfWork {
  Future<T> run<T>(Future<T> Function() work);
}
