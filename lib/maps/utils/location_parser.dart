import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class LocationParseResult {
  final LatLng point;
  final String? label;
  final String rawSource;

  const LocationParseResult({
    required this.point,
    this.label,
    required this.rawSource,
  });
}

class LocationParser {
  LocationParser._();

  /// Regex untuk mencocokkan pola koordinat desimal (misal: -7.718821, 109.015632)
  static final RegExp _latLngRegex = RegExp(
    r'([-+]?\d{1,2}\.\d+)[,\s]+([-+]?\d{1,3}\.\d+)',
  );

  /// Regex untuk Google Maps URL parameter (@lat,lng atau q=lat,lng atau query=lat,lng)
  static final RegExp _mapsUrlQueryRegex = RegExp(
    r'(?:[?&](?:q|query|daddr|destination)=|@)([-+]?\d{1,2}\.\d+)[,\s]+([-+]?\d{1,3}\.\d+)',
    caseSensitive: false,
  );

  /// Regex untuk geo: URI
  static final RegExp _geoUriRegex = RegExp(
    r'geo:([-+]?\d{1,2}\.\d+)[,\s]+([-+]?\d{1,3}\.\d+)',
    caseSensitive: false,
  );

  /// Regex untuk derajat menit detik (DMS): misal 7°43'07.8"S 109°00'56.3"E
  static final RegExp _dmsRegex = RegExp(
    r'''(\d{1,2})[°\s]+(\d{1,2})['\s]+([\d.]+)"?\s*([NSEWnsew])[,\s]+(\d{1,3})[°\s]+(\d{1,2})['\s]+([\d.]+)"?\s*([NSEWnsew])''',
  );

  /// Parse input teks pengguna (teks koordinat, link WA, link Google Maps)
  static Future<LocationParseResult?> parse(String input) async {
    final text = input.trim();
    if (text.isEmpty) return null;

    // 1. Cek pola URL parameter (@lat,lng atau ?q=lat,lng)
    final urlMatch = _mapsUrlQueryRegex.firstMatch(text);
    if (urlMatch != null) {
      final lat = double.tryParse(urlMatch.group(1)!);
      final lng = double.tryParse(urlMatch.group(2)!);
      if (_isValid(lat, lng)) {
        return LocationParseResult(
          point: LatLng(lat!, lng!),
          rawSource: text,
        );
      }
    }

    // 2. Cek geo URI
    final geoMatch = _geoUriRegex.firstMatch(text);
    if (geoMatch != null) {
      final lat = double.tryParse(geoMatch.group(1)!);
      final lng = double.tryParse(geoMatch.group(2)!);
      if (_isValid(lat, lng)) {
        return LocationParseResult(
          point: LatLng(lat!, lng!),
          rawSource: text,
        );
      }
    }

    // 3. Cek pola DMS (Derajat Menit Detik)
    final dmsMatch = _dmsRegex.firstMatch(text);
    if (dmsMatch != null) {
      final lat = _dmsToDecimal(
        double.parse(dmsMatch.group(1)!),
        double.parse(dmsMatch.group(2)!),
        double.parse(dmsMatch.group(3)!),
        dmsMatch.group(4)!,
      );
      final lng = _dmsToDecimal(
        double.parse(dmsMatch.group(5)!),
        double.parse(dmsMatch.group(6)!),
        double.parse(dmsMatch.group(7)!),
        dmsMatch.group(8)!,
      );
      if (_isValid(lat, lng)) {
        return LocationParseResult(
          point: LatLng(lat, lng),
          rawSource: text,
        );
      }
    }

    // 4. Cek pola koordinat desimal langsung di dalam teks
    final directMatch = _latLngRegex.firstMatch(text);
    if (directMatch != null) {
      final lat = double.tryParse(directMatch.group(1)!);
      final lng = double.tryParse(directMatch.group(2)!);
      if (_isValid(lat, lng)) {
        return LocationParseResult(
          point: LatLng(lat!, lng!),
          rawSource: text,
        );
      }
    }

    // 5. Jika merupakan short link (misal maps.app.goo.gl atau goo.gl/maps), coba resolve redirect
    if (text.contains('maps.app.goo.gl') || text.contains('goo.gl/maps')) {
      try {
        final urlRegex = RegExp(r'https?://[^\s]+');
        final matchUrl = urlRegex.firstMatch(text)?.group(0);
        if (matchUrl != null) {
          final client = http.Client();
          final request = http.Request('GET', Uri.parse(matchUrl))..followRedirects = true;
          final response = await client.send(request);
          final finalUrl = response.headers['location'] ?? response.request?.url.toString() ?? '';
          if (finalUrl.isNotEmpty) {
            return parse(finalUrl);
          }
        }
      } catch (_) {}
    }

    return null;
  }

  static bool _isValid(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  static double _dmsToDecimal(double d, double m, double s, String direction) {
    double dec = d + (m / 60.0) + (s / 3600.0);
    final dir = direction.toUpperCase();
    if (dir == 'S' || dir == 'W') {
      dec = -dec;
    }
    return dec;
  }
}
