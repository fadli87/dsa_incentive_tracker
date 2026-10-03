import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/auth/models/access_cache.dart';
import 'package:dsa_incentive_tracker/auth/models/member_status.dart';
import 'package:dsa_incentive_tracker/auth/services/team_access_service.dart';

/// In-memory fake untuk SecureStorageService
class FakeSecureStorage implements SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}

void main() {
  group('MemberStatus & AccessCache Model Tests', () {
    test('MemberStatus correctly parses from strings', () {
      expect(MemberStatus.fromString('approved'), MemberStatus.approved);
      expect(MemberStatus.fromString('APPROVED'), MemberStatus.approved);
      expect(MemberStatus.fromString('pending'), MemberStatus.pending);
      expect(MemberStatus.fromString('revoked'), MemberStatus.revoked);
      expect(MemberStatus.fromString('anything_else'), MemberStatus.unknown);
      expect(MemberStatus.fromString(null), MemberStatus.unknown);
    });

    test('AccessCache serializes and deserializes correctly', () {
      final now = DateTime.now();
      final validUntil = now.add(const Duration(days: 7));
      final cache = AccessCache(
        status: MemberStatus.approved,
        checkedAt: now,
        validUntil: validUntil,
      );

      final json = cache.toJson();
      expect(json['status'], 'approved');
      expect(json['checked_at'], isNotNull);
      expect(json['valid_until'], isNotNull);

      final reconstructed = AccessCache.fromJson(json);
      expect(reconstructed.status, MemberStatus.approved);
      expect(reconstructed.isExpired, isFalse);
      expect(reconstructed.isAccessAllowed, isTrue);
    });

    test('AccessCache detects expired grace period', () {
      final past = DateTime.now().subtract(const Duration(days: 8));
      final expiredUntil = past.add(const Duration(days: 7)); // 1 hari yang lalu
      final cache = AccessCache(
        status: MemberStatus.approved,
        checkedAt: past,
        validUntil: expiredUntil,
      );

      expect(cache.isExpired, isTrue);
      expect(cache.isAccessAllowed, isFalse);
    });
  });

  group('TeamAccessService Cache & Offline Fallback Tests', () {
    late FakeSecureStorage fakeStorage;
    late TeamAccessService service;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      // Service tanpa injected Supabase client akan melempar exception jaringan
      // saat resolveAccess, mensimulasikan kondisi offline total.
      service = TeamAccessService(secureStorage: fakeStorage);
    });

    test('Offline tanpa cache mengembalikan status unknown (blokir)', () async {
      final result = await service.resolveAccess('user_test_1');
      expect(result.status, MemberStatus.unknown);
      expect(result.isAccessAllowed, isFalse);
    });

    test('Offline dengan cache approved yang masih valid (< 7 hari) mengizinkan akses', () async {
      final now = DateTime.now();
      final validCache = AccessCache(
        status: MemberStatus.approved,
        checkedAt: now.subtract(const Duration(days: 2)),
        validUntil: now.add(const Duration(days: 5)),
      );
      await fakeStorage.write(
        '${TeamAccessService.cacheKeyPrefix}user_test_2',
        jsonEncode(validCache.toJson()),
      );

      final result = await service.resolveAccess('user_test_2');
      expect(result.status, MemberStatus.approved);
      expect(result.isAccessAllowed, isTrue);
    });

    test('Offline dengan cache approved kedaluwarsa (> 7 hari) mengembalikan status unknown', () async {
      final past = DateTime.now().subtract(const Duration(days: 10));
      final expiredCache = AccessCache(
        status: MemberStatus.approved,
        checkedAt: past,
        validUntil: past.add(const Duration(days: 7)), // 3 hari yang lalu
      );
      await fakeStorage.write(
        '${TeamAccessService.cacheKeyPrefix}user_test_3',
        jsonEncode(expiredCache.toJson()),
      );

      final result = await service.resolveAccess('user_test_3');
      expect(result.status, MemberStatus.unknown);
      expect(result.isAccessAllowed, isFalse);
    });

    test('Offline dengan cache status revoked tetap diblokir', () async {
      final revokedCache = AccessCache(
        status: MemberStatus.revoked,
        checkedAt: DateTime.now(),
        validUntil: DateTime.now(),
      );
      await fakeStorage.write(
        '${TeamAccessService.cacheKeyPrefix}user_test_4',
        jsonEncode(revokedCache.toJson()),
      );

      final result = await service.resolveAccess('user_test_4');
      expect(result.status, MemberStatus.revoked);
      expect(result.isAccessAllowed, isFalse);
    });

    test('CRITICAL REGRESSION TEST: Kegagalan koneksi offline tidak pernah merusak sesi/memanggil logout', () async {
      // Setup user dengan cache valid
      final now = DateTime.now();
      final validCache = AccessCache(
        status: MemberStatus.approved,
        checkedAt: now,
        validUntil: now.add(const Duration(days: 7)),
      );
      await fakeStorage.write(
        '${TeamAccessService.cacheKeyPrefix}user_sales_field',
        jsonEncode(validCache.toJson()),
      );

      // Panggil resolveAccess berulang kali dalam kondisi offline
      final res1 = await service.resolveAccess('user_sales_field');
      final res2 = await service.resolveAccess('user_sales_field');

      expect(res1.status, MemberStatus.approved);
      expect(res2.status, MemberStatus.approved);

      // Pastikan cache tetap ada dan tidak terhapus
      final storedValue = await fakeStorage.read('${TeamAccessService.cacheKeyPrefix}user_sales_field');
      expect(storedValue, isNotNull);
    });

    test('signOut menghapus cache lokal user secara bersih', () async {
      final validCache = AccessCache(
        status: MemberStatus.approved,
        checkedAt: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 7)),
      );
      await fakeStorage.write(
        '${TeamAccessService.cacheKeyPrefix}user_to_logout',
        jsonEncode(validCache.toJson()),
      );

      await service.signOut(userId: 'user_to_logout');

      final storedValue = await fakeStorage.read('${TeamAccessService.cacheKeyPrefix}user_to_logout');
      expect(storedValue, isNull);
    });
  });
}
