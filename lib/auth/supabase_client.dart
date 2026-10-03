import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

/// Helper wrapper untuk Supabase initialization dan client access
class AppSupabase {
  static bool _isInitialized = false;

  /// Inisialisasi Supabase saat app startup.
  static Future<void> initialize({
    String? url,
    String? anonKey,
  }) async {
    if (_isInitialized) return;

    if (!SupabaseConfig.isConfigured && url == null) {
      debugPrint('Supabase credentials not configured yet. Running in dev bypass mode.');
      return;
    }

    final targetUrl = url ?? SupabaseConfig.url;
    final targetAnonKey = anonKey ?? SupabaseConfig.anonKey;

    try {
      await Supabase.initialize(
        url: targetUrl,
        // ignore: deprecated_member_use
        anonKey: targetAnonKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase initialize error: $e');
    }
  }

  /// Expose SupabaseClient aktif
  static SupabaseClient get client => Supabase.instance.client;

  /// Cek apakah Supabase sudah berhasil terinisialisasi
  static bool get isInitialized => _isInitialized;
}
