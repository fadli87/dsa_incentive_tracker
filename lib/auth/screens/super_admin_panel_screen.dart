import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/master_customer.dart';
import '../../data/services/customer_master_import_service.dart';
import '../../providers/customer_master_provider.dart';
import '../models/member_status.dart';
import '../models/team_member_item.dart';
import '../providers/auth_providers.dart';
import '../supabase_client.dart';

/// Layar Panel Kontrol Superadmin untuk Manajemen Anggota & Kode Akses Tim
class SuperAdminPanelScreen extends ConsumerStatefulWidget {
  const SuperAdminPanelScreen({super.key});

  @override
  ConsumerState<SuperAdminPanelScreen> createState() =>
      _SuperAdminPanelScreenState();
}

class _SuperAdminPanelScreenState extends ConsumerState<SuperAdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _newCodeCtrl = TextEditingController();
  final TextEditingController _confirmCodeCtrl = TextEditingController();

  String _filterStatus = 'all'; // 'all', 'pending', 'approved', 'revoked'
  bool _obscureNewCode = true;
  bool _obscureConfirmCode = true;
  bool _isUpdatingCode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _newCodeCtrl.dispose();
    _confirmCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(teamMembersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001A40),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.amberAccent,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'PANEL SUPERADMIN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Text(
              'Manajemen Akses & Keamanan Tim',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Anggota Tim'),
            Tab(icon: Icon(Icons.vpn_key_rounded), text: 'Kode Akses Tim'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () {
              ref.read(teamMembersProvider.notifier).refresh();
              ref.invalidate(masterStatusSummaryProvider);
              ref.invalidate(unmatchedFormResponsesProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMembersTab(membersAsync), _buildAccessCodeTab()],
      ),
    );
  }

  // =========================================================================
  // TAB 1: MANAJEMEN ANGGOTA TIM
  // =========================================================================
  Widget _buildMembersTab(AsyncValue<List<TeamMemberItem>> membersAsync) {
    return membersAsync.when(
      data: (members) {
        final currentUserId = AppSupabase.isInitialized
            ? AppSupabase.client.auth.currentUser?.id
            : null;

        // Hitung statistik
        final total = members.length;
        final pendingCount = members.where((m) => m.isPending).length;
        final approvedCount = members.where((m) => m.isApproved).length;
        final revokedCount = members.where((m) => m.isRevoked).length;

        // Filter list
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = members.where((m) {
          final matchesQuery =
              query.isEmpty ||
              m.name.toLowerCase().contains(query) ||
              m.email.toLowerCase().contains(query);

          final matchesStatus = switch (_filterStatus) {
            'pending' => m.isPending,
            'approved' => m.isApproved,
            'revoked' => m.isRevoked,
            _ => true,
          };

          return matchesQuery && matchesStatus;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(masterStatusSummaryProvider);
            ref.invalidate(unmatchedFormResponsesProvider);
            await ref.read(teamMembersProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildMasterStatusCard(),
              _buildUnmatchedFormResponsesCard(),
              // Summary Cards Row
              Row(
                children: [
                  _summaryChip('Total', total, const Color(0xFF002B66)),
                  const SizedBox(width: 8),
                  _summaryChip('Pending', pendingCount, Colors.orange.shade800),
                  const SizedBox(width: 8),
                  _summaryChip('Aktif', approvedCount, Colors.green.shade700),
                  const SizedBox(width: 8),
                  _summaryChip('Dicabut', revokedCount, Colors.red.shade700),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email sales...',
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
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Semua ($total)', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('Menunggu ($pendingCount)', 'pending'),
                    const SizedBox(width: 8),
                    _filterChip('Disetujui ($approvedCount)', 'approved'),
                    const SizedBox(width: 8),
                    _filterChip('Dicabut ($revokedCount)', 'revoked'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Member List
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada anggota yang cocok dengan filter.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map(
                  (member) => _buildMemberCard(member, currentUserId),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF002B66)),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat daftar anggota:\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                onPressed: () =>
                    ref.read(teamMembersProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String title, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterStatusCard() {
    final statusAsync = ref.watch(masterStatusSummaryProvider);
    final isPureSuperadmin = ref.watch(canEditRolesProvider);
    return statusAsync.when(
      data: (status) {
        if (status == null) return const SizedBox.shrink();
        final isStale = status.isImportStale();
        final lastImportText = status.lastImport != null
            ? DateFormat('dd MMM yyyy HH:mm').format(status.lastImport!.toLocal())
            : 'Belum pernah';
        final batchText = status.lastBatch.trim().isNotEmpty
            ? status.lastBatch
            : '-';

        return Card(
          key: const Key('master_status_card'),
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isStale ? Colors.amber.shade400 : Colors.blueGrey.shade100,
            ),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 18,
                      color: const Color(0xFF002B66),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Data Master Pelanggan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF001A40),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Batch: $batchText',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF002B66),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _masterMetricItem(
                      'Total Pelanggan',
                      '${status.total}',
                      const Color(0xFF002B66),
                    ),
                    _masterMetricItem(
                      'Impor Terakhir',
                      lastImportText,
                      Colors.teal.shade800,
                    ),
                    _masterMetricItem(
                      'Tanpa Nama Sales',
                      '${status.withoutSales}',
                      status.withoutSales > 0
                          ? Colors.orange.shade900
                          : Colors.grey.shade700,
                    ),
                  ],
                ),
                if (isStale) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('master_stale_warning'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Colors.amber.shade900,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status.lastImport == null
                                ? 'Data master pelanggan belum pernah diimpor.'
                                : 'Impor terakhir sudah lebih dari 35 hari yang lalu. Disarankan mengimpor KMZ terbaru.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isPureSuperadmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('btn_import_customer_master_kmz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002B66),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text(
                        'Impor dari KMZ/KML',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _onTapImportCustomerMaster,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _onTapImportCustomerMaster() async {
    if (!ref.read(canEditRolesProvider)) return;

    Uint8List? fileBytes;
    try {
      final pickCallback = ref.read(pickMasterImportBytesProvider);
      fileBytes = await pickCallback();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka pemilih file KMZ/KML.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (fileBytes == null || !mounted) return;

    // Tampilkan dialog "Membaca file…" saat isolate bekerja
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: const AlertDialog(
          key: Key('master_import_reading_dialog'),
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF002B66),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Membaca file…',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    MasterImportParseResult? parseResult;
    Object? parseError;
    try {
      final importService = ref.read(customerMasterImportServiceProvider);
      parseResult = await importService.parseFileBytesInIsolate(fileBytes);
    } catch (e) {
      parseError = e;
    } finally {
      // Lepas referensi bytes mentah dari memori segera setelah ekstraksi/parse selesai
      fileBytes = null;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (parseError != null) {
      final msg = parseError is MasterImportException
          ? parseError.message
          : 'Gagal membaca file KMZ/KML. Pastikan format file valid.';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('master_import_parse_error_dialog'),
          title: const Text('Gagal Membaca File'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return;
    }

    if (parseResult == null) return;
    await _showMasterImportPreviewDialog(parseResult);
  }

  Future<void> _showMasterImportPreviewDialog(
    MasterImportParseResult parseResult,
  ) async {
    final stats = parseResult.stats;
    final dateRangeText =
        (stats.minInstallDate != null && stats.maxInstallDate != null)
        ? '${stats.minInstallDate} s/d ${stats.maxInstallDate}'
        : '-';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const Key('master_import_preview_dialog'),
        title: const Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: Color(0xFF002B66),
              size: 22,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pratinjau Impor Master KCLP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _previewStatRow('Batch ID', stats.batchId),
              _previewStatRow('Total Placemark', '${stats.totalPlacemarks}'),
              _previewStatRow('Jumlah KCLP', '${stats.cityMatched}'),
              _previewStatRow('Baris Valid Unik', '${stats.validUnique}'),
              _previewStatRow('Duplikat', '${stats.duplicates}'),
              _previewStatRow('Tanpa Koordinat', '${stats.missingCoords}'),
              _previewStatRow(
                'Tanpa Tanggal Install',
                '${stats.missingInstallDate}',
              ),
              _previewStatRow(
                'Tanpa Nama Sales',
                '${stats.missingSalesName}',
              ),
              _previewStatRow('Jumlah Sales Unik', '${stats.uniqueSales}'),
              _previewStatRow('Rentang Tanggal Install', dateRangeText),
              const SizedBox(height: 8),
              const Text(
                'Jumlah per TSC:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001A40),
                ),
              ),
              const SizedBox(height: 4),
              if (stats.perTsc.isEmpty)
                const Text(
                  '-',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                )
              else
                ...stats.perTsc.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '${e.value}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF002B66),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  'Impor hanya menambah atau memperbarui. Pelanggan yang tidak ada di file ini tidak dihapus.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF1E3A8A),
                    height: 1.35,
                  ),
                ),
              ),
              if (stats.validUnique == 0) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('master_import_empty_warning'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    'Tidak ada baris KCLP yang valid. Pastikan ini file yang benar.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('btn_cancel_master_import'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_master_import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002B66),
              foregroundColor: Colors.white,
            ),
            onPressed: stats.validUnique == 0
                ? null
                : () => Navigator.pop(ctx, true),
            child: const Text('Impor Sekarang'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _executeMasterImportBatch(parseResult);
    }
  }

  Widget _previewStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF001A40),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeMasterImportBatch(
    MasterImportParseResult parseResult,
  ) async {
    final importService = ref.read(customerMasterImportServiceProvider);
    final total = parseResult.records.length;

    while (mounted) {
      final progressNotifier = ValueNotifier<(int, int)>((0, total));

      // Tampilkan dialog progres tanpa tombol Batal
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            key: const Key('master_import_progress_dialog'),
            title: const Text(
              'Mengimpor Master Pelanggan…',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            content: ValueListenableBuilder<(int, int)>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) {
                final done = progress.$1;
                final max = progress.$2;
                final fraction = max > 0 ? done / max : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF002B66),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mengirim $done / $max',
                      key: const Key('master_import_progress_text'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      MasterImportResult? importResult;
      Object? batchError;
      try {
        importResult = await importService.importRecords(
          parseResult.records,
          parseResult.stats.batchId,
          onProgress: (done, max) {
            progressNotifier.value = (done, max);
          },
        );
      } catch (e) {
        batchError = e;
      } finally {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        progressNotifier.dispose();
      }

      if (!mounted) return;

      if (batchError != null) {
        final errMsg = batchError is MasterImportBatchException
            ? batchError.message
            : 'Gagal mengirim data master ke server. Silakan coba lagi.';
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            key: const Key('master_import_error_dialog'),
            title: const Text('Impor Belum Selesai'),
            content: Text(errMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                key: const Key('btn_retry_master_import'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        );

        if (retry == true && mounted) {
          continue;
        }
        return;
      }

      if (importResult != null) {
        ref.invalidate(masterStatusSummaryProvider);
        final summaryText =
            'Baru: ${importResult.insertedCount}, Diperbarui: ${importResult.updatedCount}, Ditolak: ${importResult.rejectedCount}';
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            key: const Key('master_import_result_dialog'),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Impor Master Selesai',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              summaryText,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              ElevatedButton(
                key: const Key('btn_close_master_import_result'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Selesai'),
              ),
            ],
          ),
        );
        return;
      }
    }
  }

  Widget _buildUnmatchedFormResponsesCard() {
    final unmatchedAsync = ref.watch(unmatchedFormResponsesProvider);
    return unmatchedAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Card(
          key: const Key('unmatched_form_responses_card'),
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.deepOrange.shade300),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.link_off_rounded,
                      size: 18,
                      color: Colors.deepOrange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jawaban Form Tanpa Pasangan (${items.length})',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF001A40),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Jika email berbeda, atur Email Form anggota terkait.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final r = items[idx];
                      final dateLabel = r.visitDate ?? '-';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ID: ${r.customerId} · ${r.category.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF002B66),
                                    ),
                                  ),
                                ),
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Email Form: ${r.responderEmail}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            Text(
                              'Alasan: ${r.reasonDisplayLabel}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepOrange.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _masterMetricItem(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filterStatus = value);
      },
      selectedColor: const Color(0xFF002B66),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF002B66),
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildMemberCard(TeamMemberItem member, String? currentUserId) {
    final isMe = member.userId == currentUserId;
    final canEditRoles = ref.watch(canEditRolesProvider);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: member.isSuperadmin
                      ? Colors.amber.shade100
                      : const Color(0xFF002B66).withValues(alpha: 0.1),
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: member.isSuperadmin
                          ? Colors.amber.shade900
                          : const Color(0xFF002B66),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info Utama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name
                                  : '(Nama belum diisi)',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF001A40),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ANDA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF002B66),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (member.salesName != null &&
                          member.salesName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.assignment_ind_outlined,
                              size: 13,
                              color: Colors.indigo.shade700,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Sales KMZ: ${member.salesName}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (member.formEmail != null &&
                          member.formEmail!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.alternate_email_rounded,
                              size: 13,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Email Form: ${member.formEmail}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Status Badges & Action Buttons Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Role Badge (ditampilkan di tiap kartu)
                    _roleBadge(member.role),
                    const SizedBox(width: 8),

                    // Status Badge
                    _statusBadge(member.status),
                  ],
                ),

                // Actions
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (canEditRoles) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _promptSetMemberSalesName(member),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.indigo.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 14,
                                color: Colors.indigo.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Atur Nama Sales',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        key: Key('btn_set_form_email_${member.userId}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _promptSetMemberFormEmail(member),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.teal.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.alternate_email_rounded,
                                size: 14,
                                color: Colors.teal.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Atur Email Form',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (!isMe && !member.isSuperadmin) ...[
                      if (canEditRoles) ...[
                        PopupMenuButton<TeamRole>(
                          tooltip: 'Ubah Role',
                          onSelected: (newRole) {
                            if (newRole != member.role) {
                              _changeMemberRole(member, newRole);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem<TeamRole>(
                              value: TeamRole.member,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 16,
                                    color: member.role == TeamRole.member
                                        ? const Color(0xFF002B66)
                                        : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sales (Member)',
                                    style: TextStyle(
                                      fontWeight: member.role == TeamRole.member
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<TeamRole>(
                              value: TeamRole.spv,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.supervisor_account_outlined,
                                    size: 16,
                                    color: member.role == TeamRole.spv
                                        ? Colors.indigo.shade700
                                        : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SPV',
                                    style: TextStyle(
                                      fontWeight: member.role == TeamRole.spv
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<TeamRole>(
                              value: TeamRole.tsc,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.manage_accounts_outlined,
                                    size: 16,
                                    color: member.role == TeamRole.tsc
                                        ? Colors.teal.shade700
                                        : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'TSC',
                                    style: TextStyle(
                                      fontWeight: member.role == TeamRole.tsc
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF002B66,
                              ).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(
                                  0xFF002B66,
                                ).withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.manage_accounts_rounded,
                                  size: 14,
                                  color: Color(0xFF002B66),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Ubah Role',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF002B66),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: Color(0xFF002B66),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (member.isPending) ...[
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                          ),
                          icon: const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                          tooltip: 'Setujui Akses',
                          onPressed: () => _confirmChangeStatus(
                            member,
                            MemberStatus.approved,
                          ),
                        ),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                          ),
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                          tooltip: 'Tolak / Cabut Akses',
                          onPressed: () => _confirmChangeStatus(
                            member,
                            MemberStatus.revoked,
                          ),
                        ),
                      ] else if (member.isApproved) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.block, size: 14),
                          label: const Text(
                            'Cabut Akses',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () => _confirmChangeStatus(
                            member,
                            MemberStatus.revoked,
                          ),
                        ),
                      ] else if (member.isRevoked) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 14,
                          ),
                          label: const Text(
                            'Pulihkan Akses',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () => _confirmChangeStatus(
                            member,
                            MemberStatus.approved,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(TeamRole role) {
    final (label, color, bg, icon) = switch (role) {
      TeamRole.superadmin => (
        'SUPERADMIN',
        Colors.amber.shade900,
        Colors.amber.shade100,
        Icons.shield,
      ),
      TeamRole.admin => (
        'ADMIN',
        Colors.deepOrange.shade900,
        Colors.deepOrange.shade50,
        Icons.admin_panel_settings,
      ),
      TeamRole.spv => (
        'SPV',
        Colors.indigo.shade800,
        Colors.indigo.shade50,
        Icons.supervisor_account,
      ),
      TeamRole.tsc => (
        'TSC',
        Colors.teal.shade800,
        Colors.teal.shade50,
        Icons.manage_accounts,
      ),
      TeamRole.member => (
        'SALES',
        const Color(0xFF002B66),
        const Color(0xFFE8EEF7),
        Icons.badge_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptSetMemberSalesName(TeamMemberItem member) async {
    var inputText = member.salesName ?? '';
    final displayName = member.name.isNotEmpty ? member.name : member.email;

    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atur Nama Sales (KMZ)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atur nama sales sesuai kolom Sales Name pada file KMZ untuk $displayName. '
              'Kosongkan kolom lalu simpan untuk mereset klaim nama sales.',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: inputText,
              onChanged: (v) => inputText = v,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nama Sales (UPPERCASE)',
                hintText: 'Contoh: BUDI SANTOSO (kosong = reset)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal'),
          ),
          if (member.salesName != null && member.salesName!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text(
                'Reset (Kosongkan)',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002B66),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, inputText.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (submitted == null || !mounted) return;

    final res = await ref
        .read(teamMembersProvider.notifier)
        .setSalesName(member.userId, submitted);
    if (!mounted) return;

    switch (res) {
      case 'success':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submitted.isEmpty
                  ? 'Nama sales untuk $displayName berhasil direset.'
                  : 'Nama sales untuk $displayName berhasil diatur!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      case 'already_claimed':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nama sales tersebut sudah diklaim oleh akun lain.'),
            backgroundColor: Colors.red,
          ),
        );
      case 'unauthorized':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Akses ditolak: Hanya Superadmin yang dapat mengatur nama sales.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengatur nama sales: $res'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _promptSetMemberFormEmail(TeamMemberItem member) async {
    var inputText = member.formEmail ?? '';
    final displayName = member.name.isNotEmpty ? member.name : member.email;

    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atur Email Form'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atur alamat email Google alternatif yang dipakai $displayName saat mengisi Google Form visit (bila berbeda dari email akun aplikasi ${member.email}). '
              'Kosongkan lalu simpan untuk menghapus alias.',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('dialog_form_email_input'),
              initialValue: inputText,
              onChanged: (v) => inputText = v,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Google Form (Alias)',
                hintText: 'contoh.sales@gmail.com (kosong = hapus)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal'),
          ),
          if (member.formEmail != null && member.formEmail!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text(
                'Reset (Kosongkan)',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
          ElevatedButton(
            key: const Key('dialog_form_email_save_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002B66),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, inputText.trim().toLowerCase()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (submitted == null || !mounted) return;

    final res = await ref
        .read(teamMembersProvider.notifier)
        .setFormEmail(member.userId, submitted);
    if (!mounted) return;

    switch (res) {
      case 'success':
        ref.invalidate(unmatchedFormResponsesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submitted.isEmpty
                  ? 'Email Form untuk $displayName berhasil dihapus.'
                  : 'Email Form untuk $displayName berhasil diatur!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      case 'invalid_email':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format alamat email tidak valid.'),
            backgroundColor: Colors.red,
          ),
        );
      case 'already_used':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email tersebut sudah dipakai oleh akun anggota lain.'),
            backgroundColor: Colors.red,
          ),
        );
      case 'not_found':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anggota tim tidak ditemukan di server.'),
            backgroundColor: Colors.red,
          ),
        );
      case 'unauthorized':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Akses ditolak: Hanya Superadmin yang dapat mengatur Email Form.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengatur Email Form: $res'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _changeMemberRole(
    TeamMemberItem member,
    TeamRole newRole,
  ) async {
    final res = await ref
        .read(teamMembersProvider.notifier)
        .updateRole(member.userId, newRole);
    if (!mounted) return;

    final displayName = member.name.isNotEmpty ? member.name : member.email;
    switch (res) {
      case 'success':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Role $displayName berhasil diubah menjadi ${newRole.displayLabel}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      case 'unauthorized':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Akses ditolak: Hanya Superadmin yang dapat mengubah role anggota.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      case 'cannot_change_self':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda tidak dapat mengubah role akun Anda sendiri.'),
            backgroundColor: Colors.red,
          ),
        );
      case 'not_found':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anggota tim tidak ditemukan di server.'),
            backgroundColor: Colors.red,
          ),
        );
      case 'invalid_role':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Role yang dipilih tidak valid.'),
            backgroundColor: Colors.red,
          ),
        );
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal mengubah role anggota. Periksa koneksi internet Anda.',
            ),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Widget _statusBadge(MemberStatus status) {
    final (label, color, bg) = switch (status) {
      MemberStatus.approved => (
        'Aktif (Approved)',
        Colors.green.shade800,
        Colors.green.shade50,
      ),
      MemberStatus.pending => (
        'Menunggu Kode',
        Colors.orange.shade900,
        Colors.orange.shade50,
      ),
      MemberStatus.revoked => (
        'Akses Dicabut',
        Colors.red.shade900,
        Colors.red.shade50,
      ),
      MemberStatus.unknown => (
        'Tidak Diketahui',
        Colors.grey.shade700,
        Colors.grey.shade100,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _confirmChangeStatus(
    TeamMemberItem member,
    MemberStatus newStatus,
  ) async {
    final actionName = newStatus == MemberStatus.approved
        ? 'Menyetujui'
        : 'Mencabut';
    final actionColor = newStatus == MemberStatus.approved
        ? Colors.green.shade700
        : Colors.red.shade700;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionName Akses?'),
        content: Text(
          newStatus == MemberStatus.approved
              ? 'Pengguna ${member.name.isNotEmpty ? member.name : member.email} akan dapat langsung masuk dan menggunakan aplikasi.'
              : 'Pengguna ${member.name.isNotEmpty ? member.name : member.email} akan langsung diblokir dan tidak dapat mengakses aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              newStatus == MemberStatus.approved ? 'Setujui' : 'Cabut Akses',
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final res = await ref
          .read(teamMembersProvider.notifier)
          .updateStatus(member.userId, newStatus);
      if (mounted) {
        if (res == 'success' || res == 'approved') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status akses ${member.name} berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memperbarui status: $res'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // =========================================================================
  // TAB 2: PENGATURAN KODE AKSES TIM
  // =========================================================================
  Widget _buildAccessCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.security_rounded,
                  color: Colors.amber.shade900,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rotasi Kode Akses Tim',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kode akses tim digunakan oleh sales baru saat mendaftar akun. '
                        'Jika ada anggota tim yang keluar dan direvoke, segera perbarui kode akses ini '
                        'dan bagikan hanya ke anggota tim yang masih aktif.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.amber.shade900,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Form Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KODE AKSES TIM BARU',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Input Kode Baru
                  TextField(
                    controller: _newCodeCtrl,
                    obscureText: _obscureNewCode,
                    decoration: InputDecoration(
                      labelText: 'Kode Akses Baru',
                      hintText: 'Contoh: XLSATU-2026',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewCode
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNewCode = !_obscureNewCode),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Konfirmasi Kode Baru
                  TextField(
                    controller: _confirmCodeCtrl,
                    obscureText: _obscureConfirmCode,
                    decoration: InputDecoration(
                      labelText: 'Ulangi Kode Akses Baru',
                      hintText: 'Masukkan kode yang sama persis',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmCode
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmCode = !_obscureConfirmCode,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002B66),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isUpdatingCode
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isUpdatingCode
                            ? 'Menyimpan...'
                            : 'Perbarui Kode Akses Tim',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isUpdatingCode ? null : _submitNewAccessCode,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitNewAccessCode() async {
    final newCode = _newCodeCtrl.text.trim();
    final confirm = _confirmCodeCtrl.text.trim();

    if (newCode.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kolom kode akses tidak boleh kosong.')),
      );
      return;
    }

    if (newCode != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi kode akses tidak cocok.')),
      );
      return;
    }

    if (newCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode akses minimal 6 karakter.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Perubahan Kode'),
        content: Text(
          'Kode akses tim akan diperbarui menjadi: "$newCode"\n\n'
          'Pastikan Anda membagikan kode ini hanya kepada rekan sales yang berhak.',
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
            child: const Text('Ya, Perbarui'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdatingCode = true);

    try {
      final service = ref.read(teamAccessServiceProvider);
      final result = await service.updateTeamAccessCode(newCode);

      if (!mounted) return;

      if (result == 'success' || result == 'approved') {
        _newCodeCtrl.clear();
        _confirmCodeCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode akses tim berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui kode akses: $result'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingCode = false);
    }
  }
}
