import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../../core/config/supabase_config.dart';

/// Item baris Data SA Tim hasil RPC `public.list_sa_customers`.
class TeamSaCustomerItem {
  final String id;
  final String userId;
  final String memberName;
  final String idPelanggan;
  final String nama;
  final String noHpUtama;
  final String noHpAlternatif;
  final String alamat;
  final double? latitude;
  final double? longitude;
  final String paket;
  final String? tanggalPasang;

  const TeamSaCustomerItem({
    required this.id,
    required this.userId,
    required this.memberName,
    required this.idPelanggan,
    required this.nama,
    this.noHpUtama = '',
    this.noHpAlternatif = '',
    this.alamat = '',
    this.latitude,
    this.longitude,
    this.paket = '',
    this.tanggalPasang,
  });

  bool get hasLocation => latitude != null && longitude != null;

  /// Memvalidasi apakah nomor telepon layak ditampilkan tombol Telepon / WhatsApp
  /// (minimal 8 digit angka setelah dibersihkan).
  static bool isValidPhoneNumber(String? raw) {
    if (raw == null) return false;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8;
  }

  bool get hasValidPrimaryPhone => isValidPhoneNumber(noHpUtama);
  bool get hasValidAltPhone => isValidPhoneNumber(noHpAlternatif);

  factory TeamSaCustomerItem.fromJson(Map<String, dynamic> json) {
    return TeamSaCustomerItem(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      memberName: (json['member_name'] ?? '').toString(),
      idPelanggan: (json['id_pelanggan'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      noHpUtama: (json['no_hp_utama'] ?? '').toString(),
      noHpAlternatif: (json['no_hp_alternatif'] ?? '').toString(),
      alamat: (json['alamat'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      paket: (json['paket'] ?? '').toString(),
      tanggalPasang: json['tanggal_pasang']?.toString(),
    );
  }
}

/// Abstraksi gateway RPC `list_sa_customers` untuk SPV/TSC/admin/superadmin.
abstract class SaTeamRemoteGateway {
  Future<List<Map<String, dynamic>>> listSaCustomers({
    required String search,
    String? userId,
    required int limit,
    required int offset,
  });
}

class SupabaseSaTeamRemoteGateway implements SaTeamRemoteGateway {
  final SupabaseClient? _injectedClient;

  const SupabaseSaTeamRemoteGateway([this._injectedClient]);

  SupabaseClient get _client => _injectedClient ?? AppSupabase.client;

  @override
  Future<List<Map<String, dynamic>>> listSaCustomers({
    required String search,
    String? userId,
    required int limit,
    required int offset,
  }) async {
    final res = await _client
        .rpc(
          'list_sa_customers',
          params: {
            'p_search': search.trim(),
            'p_user': (userId != null && userId.trim().isNotEmpty)
                ? userId.trim()
                : null,
            'p_limit': limit,
            'p_offset': offset,
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}

/// Layanan read-only untuk mengambil daftar Data SA seluruh tim (Fase 11D).
class SaTeamService {
  static const int pageSize = 50;

  final SaTeamRemoteGateway _gateway;
  final bool? isConfiguredOverride;

  const SaTeamService({
    SupabaseClient? supabaseClient,
    SaTeamRemoteGateway? remoteGateway,
    this.isConfiguredOverride,
  }) : _gateway = remoteGateway ?? const SupabaseSaTeamRemoteGateway();

  bool get isConfigured {
    if (isConfiguredOverride != null) return isConfiguredOverride!;
    return SupabaseConfig.isConfigured && AppSupabase.isInitialized;
  }

  Future<List<TeamSaCustomerItem>> fetchSaCustomers({
    String search = '',
    String? userId,
    int limit = pageSize,
    int offset = 0,
  }) async {
    if (!isConfigured) {
      throw Exception('offline_or_unconfigured');
    }
    final rows = await _gateway.listSaCustomers(
      search: search,
      userId: userId,
      limit: limit,
      offset: offset,
    );
    return rows.map((m) => TeamSaCustomerItem.fromJson(m)).toList();
  }
}

final saTeamServiceProvider = Provider<SaTeamService>((ref) {
  return const SaTeamService();
});

