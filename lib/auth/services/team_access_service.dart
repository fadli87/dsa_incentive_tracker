import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/access_cache.dart';
import '../models/member_status.dart';
import '../supabase_client.dart';

abstract class SecureStorageService {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class DefaultSecureStorage implements SecureStorageService {
  final FlutterSecureStorage _storage;
  const DefaultSecureStorage([this._storage = const FlutterSecureStorage()]);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Service inti untuk pengecekan akses tim, verifikasi RPC, dan penyimpanan cache lokal terenkripsi
class TeamAccessService {
  static const Duration graceDuration = Duration(days: 7);
  static const Duration serverTimeout = Duration(seconds: 6);
  static const String cacheKeyPrefix = 'team_access_cache_';

  final SupabaseClient? _injectedClient;
  final SecureStorageService _secureStorage;

  TeamAccessService({
    SupabaseClient? supabaseClient,
    SecureStorageService? secureStorage,
  })  : _injectedClient = supabaseClient,
        _secureStorage = secureStorage ?? const DefaultSecureStorage();

  SupabaseClient get _client => _injectedClient ?? AppSupabase.client;

  String _getCacheKey(String userId) => '$cacheKeyPrefix$userId';

  /// Menyelesaikan status akses user:
  /// 1. Coba query ke server Supabase (dengan timeout 6 detik).
  /// 2. Jika sukses: simpan status baru ke secure storage dan return cache.
  /// 3. Jika gagal/timeout/offline: gunakan cache lokal yang ada.
  ///    - Cache ada & approved & now <= validUntil -> tetap approved.
  ///    - Cache ada & revoked -> tetap revoked.
  ///    - Cache ada tapi now > validUntil -> status unknown (butuh online).
  ///    - Tidak ada cache -> status unknown.
  /// CATATAN PENTING: Kegagalan koneksi TIDAK AKAN PERNAH memanggil signOut() otomatis.
  Future<AccessCache> resolveAccess(String userId) async {
    final now = DateTime.now();

    try {
      final response = await _client
          .from('team_members')
          .select('status, approved_at')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(serverTimeout);

      if (response != null && response['status'] != null) {
        final serverStatus = MemberStatus.fromString(response['status'] as String?);
        
        final DateTime validUntil;
        if (serverStatus == MemberStatus.approved) {
          validUntil = now.add(graceDuration);
        } else {
          validUntil = now;
        }

        final freshCache = AccessCache(
          status: serverStatus,
          checkedAt: now,
          validUntil: validUntil,
        );

        await _saveCache(userId, freshCache);
        return freshCache;
      }
    } catch (e) {
      debugPrint('TeamAccessService: Server check failed or timed out: $e. Falling back to local cache.');
    }

    // Fallback ke cache lokal terenkripsi saat offline/timeout
    final cached = await _loadCache(userId);
    if (cached != null) {
      // Jika status revoked, selalu tahan sebagai revoked
      if (cached.status == MemberStatus.revoked) {
        return cached;
      }
      
      // Jika status approved dan masih dalam masa tenggang
      if (cached.status == MemberStatus.approved && !cached.isExpired) {
        return cached;
      }

      // Jika masa tenggang habis atau pending
      if (cached.status == MemberStatus.approved && cached.isExpired) {
        return AccessCache(
          status: MemberStatus.unknown,
          checkedAt: cached.checkedAt,
          validUntil: cached.validUntil,
        );
      }

      return cached;
    }

    // Jika tidak ada cache sama sekali
    return AccessCache(
      status: MemberStatus.unknown,
      checkedAt: now,
      validUntil: now,
    );
  }

  /// Memvalidasi kode akses tim via RPC security definer
  /// Mengembalikan: 'approved' | 'invalid_code' | 'already_revoked' | 'config_missing' | 'not_authenticated' | 'error'
  Future<String> redeemAccessCode(String code) async {
    try {
      final result = await _client.rpc(
        'redeem_access_code',
        params: {'input_code': code.trim()},
      ).timeout(serverTimeout);

      final statusString = result.toString();
      if (statusString == 'approved') {
        final currentUser = _client.auth.currentUser;
        if (currentUser != null) {
          await resolveAccess(currentUser.id);
        }
      }
      return statusString;
    } catch (e) {
      debugPrint('TeamAccessService: redeemAccessCode error: $e');
      return 'error';
    }
  }

  /// Ubah password dengan verifikasi wajib kata sandi lama terlebih dahulu
  Future<void> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    // 1. Re-autentikasi dengan password lama
    final authResponse = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: oldPassword,
    );

    if (authResponse.user == null) {
      throw const AuthException('Password lama yang Anda masukkan salah.');
    }

    // 2. Update password baru
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Logout manual: hapus sesi auth Supabase dan bersihkan cache lokal
  Future<void> signOut({String? userId}) async {
    try {
      final currentId = userId ?? _client.auth.currentUser?.id;
      if (currentId != null) {
        await _clearCache(currentId);
      }
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('TeamAccessService: signOut error: $e');
    }
  }

  // --- Private Storage Helpers ---

  Future<void> _saveCache(String userId, AccessCache cache) async {
    try {
      final jsonStr = jsonEncode(cache.toJson());
      await _secureStorage.write(_getCacheKey(userId), jsonStr);
    } catch (e) {
      debugPrint('TeamAccessService: Failed to save cache: $e');
    }
  }

  Future<AccessCache?> _loadCache(String userId) async {
    try {
      final jsonStr = await _secureStorage.read(_getCacheKey(userId));
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AccessCache.fromJson(map);
      }
    } catch (e) {
      debugPrint('TeamAccessService: Failed to read cache: $e');
    }
    return null;
  }

  Future<void> _clearCache(String userId) async {
    try {
      await _secureStorage.delete(_getCacheKey(userId));
    } catch (e) {
      debugPrint('TeamAccessService: Failed to delete cache: $e');
    }
  }
}
