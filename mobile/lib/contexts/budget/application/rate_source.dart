/// Port for live exchange rates (online). Returns, for each requested
/// currency, how many units of [base] one unit of it is worth.
abstract interface class RateSource {
  String get name;
  Future<Map<String, double>> fetchRates({required String base, required Set<String> currencies});
}

class RateSourceException implements Exception {
  const RateSourceException(this.message);
  final String message;
  @override
  String toString() => 'RateSourceException: $message';
}
