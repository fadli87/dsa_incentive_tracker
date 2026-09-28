import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service untuk mengelola izin runtime (Location & Phone State)
/// agar fitur Peta GIS, Pencatatan SA, dan Analisa Jaringan Seluler / WiFi berfungsi optimal.
class PermissionService {
  PermissionService._();

  static Future<bool> hasRequiredPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }

    final locStatus = await Permission.location.status;
    final phoneStatus = await Permission.phone.status;

    return locStatus.isGranted && phoneStatus.isGranted;
  }

  /// Meminta izin lokasi dan status telepon secara bersamaan saat aplikasi dibuka / baru diinstal.
  static Future<Map<Permission, PermissionStatus>> requestInitialPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return {};
    }

    try {
      final statuses = await [
        Permission.location,
        Permission.phone,
      ].request();

      return statuses;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return {};
    }
  }

  /// Meminta izin jaringan khusus saat pengguna membuka tab/fitur Network Tools.
  static Future<bool> requestNetworkPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }

    final statuses = await [
      Permission.location,
      Permission.phone,
    ].request();

    final locGranted = statuses[Permission.location]?.isGranted ?? false;
    final phoneGranted = statuses[Permission.phone]?.isGranted ?? false;

    return locGranted && phoneGranted;
  }
}
