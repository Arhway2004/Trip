import 'package:dio/dio.dart';
import 'package:wanderplan/contexts/places/application/location_link_service.dart';

/// Follows a short link's redirects (without loading the target page) to read
/// the full map URL it points to.
class HttpLinkExpander implements LinkExpander {
  HttpLinkExpander([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              followRedirects: false,
              validateStatus: (s) => s != null && s < 400,
            ),
          );

  final Dio _dio;

  @override
  Future<Uri> expand(Uri shortLink) async {
    var current = shortLink;
    for (var i = 0; i < 5; i++) {
      final res = await _dio.getUri<void>(current, options: Options(responseType: ResponseType.stream));
      final location = res.headers.value('location');
      if (location == null || res.statusCode == null || res.statusCode! < 300) return current;
      current = current.resolve(location);
      // Stop as soon as the URL holds a map location; no need to load Google's page.
      if (current.host.contains('google.') && current.path.startsWith('/maps')) return current;
    }
    return current;
  }
}
