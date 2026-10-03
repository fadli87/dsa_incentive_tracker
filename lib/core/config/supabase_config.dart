// Konfigurasi Kredensial Supabase untuk Team Login
// Kredensial di-inject dari luar kode melalui --dart-define atau --dart-define-from-file=.env
// JANGAN PERNAH menaruh Anon Key atau URL sensitif langsung di file kode ini.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Cek apakah kredensial sudah di-inject lewat environment
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
