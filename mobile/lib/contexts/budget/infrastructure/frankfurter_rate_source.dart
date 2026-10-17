import 'package:dio/dio.dart';
import 'package:wanderplan/contexts/budget/application/rate_source.dart';

/// Live reference rates from the European Central Bank via frankfurter.app
/// (free, no API key). Covers ~30 major currencies; others stay manual.
class FrankfurterRateSource implements RateSource {
  FrankfurterRateSource([Dio? dio])
    : _dio =
          dio ?? Dio(BaseOptions(baseUrl: 'https://api.frankfurter.app', connectTimeout: const Duration(seconds: 10)));

  final Dio _dio;

  @override
  String get name => 'frankfurter.app (ECB)';

  @override
  Future<Map<String, double>> fetchRates({required String base, required Set<String> currencies}) async {
    // Ask "1 base = x foreign", then invert to "1 foreign = 1/x base".
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/latest',
        queryParameters: {'from': base, 'to': currencies.join(',')},
      );
      final rates = (res.data?['rates'] as Map?)?.cast<String, num>() ?? const {};
      return {
        for (final e in rates.entries)
          if (e.value > 0) e.key: 1 / e.value.toDouble(),
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 422) {
        throw RateSourceException('$base is not supported by ECB reference rates');
      }
      throw RateSourceException(e.message ?? 'Network error');
    }
  }
}
