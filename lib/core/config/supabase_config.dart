// Konfigurasi Kredensial Supabase untuk Team Login
// Anda dapat memasukkan Supabase URL dan Anon Key langsung di sini.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-ref.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  /// Cek apakah kredensial sudah diganti dari placeholder default
  static bool get isConfigured =>
      url != 'https://your-project-ref.supabase.co' &&
      anonKey != 'your-anon-key' &&
      url.isNotEmpty &&
      anonKey.isNotEmpty;
}
