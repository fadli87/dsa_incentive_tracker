import 'package:url_launcher/url_launcher.dart';

class LauncherHelper {
  static Future<bool> makePhoneCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> openWhatsApp(String phoneNumber) async {
    String clean = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return false;
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$clean');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> openGoogleMaps(double latitude, double longitude) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
