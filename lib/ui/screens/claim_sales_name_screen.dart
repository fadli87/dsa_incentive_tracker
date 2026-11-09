import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../../data/models/master_customer.dart';
import '../../providers/customer_master_provider.dart';

/// Layar klaim nama sales (`sales_name`) sekali saja untuk memetakan akun sales
/// ke kolom `Sales Name` pada data Master Pelanggan KCLP.
/// Catatan: SPV/TSC/Admin/Superadmin tidak wajib klaim karena memiliki akses `canViewAll`.
class ClaimSalesNameScreen extends ConsumerStatefulWidget {
  final List<MasterSalesNameOption>? initialOptions;
  final VoidCallback? onClaimSuccess;

  const ClaimSalesNameScreen({
    super.key,
    this.initialOptions,
    this.onClaimSuccess,
  });

  /// Helper untuk menentukan apakah akun perlu diarahkan/ditawarkan klaim nama sales.
  static bool shouldPromptClaim({
    required bool isApproved,
    required bool canViewAll,
    required String? currentSalesName,
    required bool hasMasterOptions,
  }) {
    if (!isApproved) return false;
    if (canViewAll) return false; // SPV/TSC/admin/superadmin tidak wajib klaim
    final hasName =
        currentSalesName != null && currentSalesName.trim().isNotEmpty;
    if (hasName) return false;
    return hasMasterOptions;
  }

  /// Pesan status bahasa Indonesia untuk setiap hasil RPC `claim_sales_name`.
  static String messageForClaimStatus(String status) {
    return switch (status) {
      'success' =>
        'Nama sales berhasil diklaim! Mengunduh data pelanggan Anda...',
      'already_claimed' => 'Nama ini sudah dipakai akun lain, hubungi admin.',
      'already_set' =>
        'Nama sales akun Anda sudah pernah diatur. Hubungi Superadmin untuk mengubahnya.',
      'not_found' => 'Nama sales tidak ditemukan di data Master Pelanggan.',
      'invalid_name' => 'Nama sales tidak valid.',
      'unauthorized' => 'Akses ditolak: akun Anda belum berstatus disetujui.',
      _ => 'Gagal menyimpan klaim nama sales. Periksa koneksi internet Anda.',
    };
  }

  @override
  ConsumerState<ClaimSalesNameScreen> createState() =>
      _ClaimSalesNameScreenState();
}

class _ClaimSalesNameScreenState extends ConsumerState<ClaimSalesNameScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<MasterSalesNameOption> _options = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _statusBannerMessage;
  bool _isBannerError = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOptions != null) {
      _options = widget.initialOptions!;
      _isLoading = false;
    } else {
      _loadOptions();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _statusBannerMessage = null;
    });
    final service = ref.read(customerMasterServiceProvider);
    final loaded = await service.fetchSalesNames();
    if (!mounted) return;
    setState(() {
      _options = loaded;
      _isLoading = false;
    });
  }

  Future<void> _confirmAndClaim(MasterSalesNameOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Klaim Nama Sales'),
        content: Text(
          'Anda adalah ${option.salesName}?\n\n'
          'Pilihan ini hanya dapat dilakukan sekali untuk menghubungkan akun Anda '
          'dengan daftar pelanggan (${option.total} pelanggan terdaftar). '
          'Perubahan selanjutnya hanya dapat dilakukan oleh Superadmin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002B66),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Klaim Nama Ini'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _statusBannerMessage = null;
    });

    final service = ref.read(customerMasterServiceProvider);
    final status = await service.claimSalesName(option.salesName);
    if (!mounted) return;

    final msg = ClaimSalesNameScreen.messageForClaimStatus(status);
    if (status == 'success') {
      ref
          .read(accessGateProvider.notifier)
          .setClaimedSalesName(option.salesName);
      setState(() {
        _isSubmitting = false;
        _isBannerError = false;
        _statusBannerMessage = msg;
      });
      await ref.read(masterSyncProvider.notifier).syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
      widget.onClaimSuccess?.call();
      if (Navigator.canPop(context)) {
        Navigator.pop(context, option.salesName);
      }
    } else {
      setState(() {
        _isSubmitting = false;
        _isBannerError = true;
        _statusBannerMessage = msg;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _options.where((o) {
      if (query.isEmpty) return true;
      return o.salesName.toLowerCase().contains(query) ||
          o.spvName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001A40),
        foregroundColor: Colors.white,
        title: const Text(
          'Pilih Nama Sales Anda',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang Daftar Nama',
            onPressed: _isLoading || _isSubmitting ? null : _loadOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hubungkan Akun dengan Data Master Pelanggan KCLP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF001A40),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih nama resmi Anda sesuai data pemasangan agar daftar "Pelanggan Saya" '
                  'dan saran kunjungan RVAI otomatis tampil di aplikasi.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama sales atau nama SPV...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF002B66),
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF4F7FB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_statusBannerMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isBannerError
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isBannerError
                      ? Colors.red.shade300
                      : Colors.green.shade300,
                ),
              ),
              child: Text(
                _statusBannerMessage!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _isBannerError
                      ? Colors.red.shade900
                      : Colors.green.shade900,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF002B66)),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _options.isEmpty
                            ? 'Data Master Pelanggan belum tersedia di server.'
                            : 'Nama sales tidak ditemukan untuk pencarian tersebut.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      return Card(
                        elevation: 0.5,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          enabled: !_isSubmitting,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE8EEF7),
                            child: Text(
                              item.salesName.isNotEmpty
                                  ? item.salesName[0]
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFF002B66),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item.salesName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF001A40),
                            ),
                          ),
                          subtitle: Text(
                            item.spvName.isNotEmpty
                                ? 'SPV: ${item.spvName} • ${item.total} pelanggan'
                                : '${item.total} pelanggan',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF002B66),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () => _confirmAndClaim(item),
                            child: const Text(
                              'Pilih',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

