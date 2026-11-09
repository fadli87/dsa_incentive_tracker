import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_providers.dart';
import '../../core/config/visit_form_config.dart';
import '../../core/constants/visit_constants.dart';
import '../../core/utils/launcher_helper.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/visit_activity.dart';
import '../../data/models/visit_form_response.dart';
import '../../data/services/visit_csv_export_service.dart';
import '../../providers/customer_master_provider.dart';
import '../../providers/visit_provider.dart';
import 'claim_sales_name_screen.dart';
import 'visit_form_screen.dart';
import 'visit_map_screen.dart';

class VisitDailyScreen extends ConsumerStatefulWidget {
  const VisitDailyScreen({super.key});

  @override
  ConsumerState<VisitDailyScreen> createState() => _VisitDailyScreenState();
}

class _VisitDailyScreenState extends ConsumerState<VisitDailyScreen>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  final Set<String> _selectedRvaiIds = {};
  bool _rvaiExpanded = true;
  bool _needsSalesNameClaim = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger initial restore/sync bila online
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(visitProvider.notifier).syncNow();
        ref.read(masterSyncProvider.notifier).syncIfNeeded();
        _checkIfShouldPromptSalesNameClaim();
      }
    });
    // Trigger sync saat koneksi kembali
    try {
      _connSub = Connectivity().onConnectivityChanged.listen((results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline && mounted) {
          ref.read(visitProvider.notifier).syncNow();
          ref.read(masterSyncProvider.notifier).syncIfNeeded();
        }
      });
    } catch (_) {}
  }

  Future<void> _checkIfShouldPromptSalesNameClaim() async {
    final gateState = ref.read(accessGateProvider);
    final isApproved = gateState == GateState.approved;
    final canViewAll = ref.read(canViewAllProvider);
    final salesName = ref.read(mySalesNameProvider);
    if (!isApproved || canViewAll || (salesName != null && salesName.isNotEmpty)) {
      if (_needsSalesNameClaim && mounted) {
        setState(() => _needsSalesNameClaim = false);
      }
      return;
    }
    final options = await ref.read(customerMasterServiceProvider).fetchSalesNames();
    if (!mounted) return;
    final shouldPrompt = ClaimSalesNameScreen.shouldPromptClaim(
      isApproved: isApproved,
      canViewAll: canViewAll,
      currentSalesName: ref.read(mySalesNameProvider),
      hasMasterOptions: options.isNotEmpty,
    );
    setState(() => _needsSalesNameClaim = shouldPrompt);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(visitProvider.notifier).syncNow();
      ref.read(masterSyncProvider.notifier).syncIfNeeded();
    }
  }

  Color _categoryColor(VisitCategory cat) {
    switch (cat) {
      case VisitCategory.rvai:
        return Colors.green.shade700;
      case VisitCategory.dismantle:
        return Colors.red.shade700;
      case VisitCategory.unpaid:
        return Colors.amber.shade700;
    }
  }

  Color _categoryBgColor(VisitCategory cat) {
    switch (cat) {
      case VisitCategory.rvai:
        return Colors.green.shade50;
      case VisitCategory.dismantle:
        return Colors.red.shade50;
      case VisitCategory.unpaid:
        return Colors.amber.shade50;
    }
  }

  void _shiftDate(int days) {
    final currentStr = ref.read(visitSelectedDateProvider);
    final current = DateTime.tryParse(currentStr) ?? DateTime.now();
    final next = current.add(Duration(days: days));
    ref.read(visitSelectedDateProvider.notifier).state = formatVisitDate(next);
  }

  Future<void> _pickDate(BuildContext context) async {
    final currentStr = ref.read(visitSelectedDateProvider);
    final current = DateTime.tryParse(currentStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      ref.read(visitSelectedDateProvider.notifier).state = formatVisitDate(picked);
    }
  }

  void _showVisitDetailSheet(BuildContext context, VisitActivity visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _VisitDetailBottomSheet(visit: visit),
    );
  }

  Future<void> _onManualSyncPressed() async {
    final res = await ref.read(visitProvider.notifier).syncNow();
    if (!mounted) return;
    if (res.skippedByGuard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode offline lokal aktif. Data disimpan aman di perangkat.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (res.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyinkronkan ke server. Data tetap tersimpan di perangkat.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sinkronisasi selesai (${res.pushedCount} terkirim, ${res.restoredCount} dipulihkan).',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onRefreshMasterPressed() async {
    final res = await ref.read(masterSyncProvider.notifier).syncNow();
    if (!mounted) return;
    if (res.skippedByGuard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode offline lokal aktif. Tidak dapat mengunduh Master Pelanggan.'),
        ),
      );
    } else if (res.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui data Master Pelanggan. Periksa koneksi internet.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data Pelanggan Saya berhasil diperbarui (${res.syncedCount} pelanggan).'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _addSelectedRvaiSuggestions(
    List<RvaiSuggestionItem> allSuggestions,
  ) async {
    final picked = allSuggestions
        .where((s) => _selectedRvaiIds.contains(s.customer.customerId))
        .toList();
    if (picked.isEmpty) return;

    final todayStr = formatVisitDate(DateTime.now());
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final notifier = ref.read(visitProvider.notifier);

    int addedCount = 0;
    for (final item in picked) {
      final c = item.customer;
      final isDup = await notifier.hasDuplicate(
        customerId: c.customerId,
        category: VisitCategory.rvai,
        plannedDate: todayStr,
      );
      if (isDup) continue;

      final activity = VisitActivity(
        clientId: '',
        customerId: c.customerId,
        customerName: '',
        category: VisitCategory.rvai,
        status: VisitStatus.belum,
        address: c.address,
        packageName: c.packageName,
        latitude: c.latitude,
        longitude: c.longitude,
        plannedDate: todayStr,
        note: '',
        updatedAt: nowIso,
      );
      await notifier.addVisit(activity);
      addedCount++;
    }

    if (!mounted) return;
    setState(() => _selectedRvaiIds.clear());
    ref.read(visitSelectedDateProvider.notifier).state = todayStr;
    await ref.read(masterSyncProvider.notifier).refreshLocalCount();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          addedCount > 0
              ? '$addedCount target RVAI berhasil ditambahkan ke hari ini!'
              : 'Target RVAI yang dipilih sudah tercatat pada hari ini.',
        ),
        backgroundColor: addedCount > 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _onExportCsvPressed(String selectedDateStr) async {
    try {
      final allVisits = await DatabaseHelper.instance.getVisitsByDate(selectedDateStr);
      final count = await VisitCsvExportService.shareCategoryCsvFiles(
        visits: allVisits,
        dateStr: selectedDateStr,
      );
      if (!mounted) return;
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Belum ada target visit berkoordinat pada tanggal ini untuk diekspor ke CSV My Maps.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateStr = ref.watch(visitSelectedDateProvider);
    final selectedCategory = ref.watch(visitSelectedCategoryProvider);
    final filterMissingForm = ref.watch(visitFilterMissingFormProvider);
    final missingFormCountAsync = ref.watch(visitMissingFormCountProvider);
    final missingFormCount = missingFormCountAsync.valueOrNull ?? 0;
    final visitsAsync = ref.watch(visitProvider);
    final countsAsync = ref.watch(visitCountsByCategoryProvider);
    final pendingAsync = ref.watch(pendingVisitCountProvider);
    final isSyncing = ref.watch(visitIsSyncingProvider);
    final pendingCount = pendingAsync.valueOrNull ?? 0;
    final rvaiSuggestionsAsync = ref.watch(rvaiSuggestionsProvider);
    final rvaiSuggestions = rvaiSuggestionsAsync.valueOrNull ?? const [];

    final counts = countsAsync.valueOrNull ??
        const {
          VisitCategory.rvai: 0,
          VisitCategory.dismantle: 0,
          VisitCategory.unpaid: 0,
        };
    final totalCount = (counts[VisitCategory.rvai] ?? 0) +
        (counts[VisitCategory.dismantle] ?? 0) +
        (counts[VisitCategory.unpaid] ?? 0);

    final parsedDate = DateTime.tryParse(selectedDateStr);
    final formattedDate = parsedDate != null
        ? DateFormat('EEEE, dd MMM yyyy').format(parsedDate)
        : selectedDateStr;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AKTIVITAS HARIAN VISIT',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            Text(
              'Monitoring RVAI · Dismantle · Unpaid',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan',
            icon: isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: isSyncing ? null : _onManualSyncPressed,
          ),
          IconButton(
            tooltip: 'Buka Peta Visit',
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitMapScreen(initialDate: selectedDateStr),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu Lainnya',
            onSelected: (value) async {
              if (value == 'export_csv') {
                _onExportCsvPressed(selectedDateStr);
              } else if (value == 'refresh_master') {
                _onRefreshMasterPressed();
              } else if (value == 'claim_sales') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClaimSalesNameScreen(),
                  ),
                );
                if (mounted) {
                  _checkIfShouldPromptSalesNameClaim();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'refresh_master',
                child: Row(
                  children: [
                    Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF002B66)),
                    SizedBox(width: 8),
                    Text('Perbarui Data Pelanggan'),
                  ],
                ),
              ),
              if (!ref.read(canViewAllProvider) &&
                  (ref.read(mySalesNameProvider) == null ||
                      ref.read(mySalesNameProvider)!.isEmpty))
                const PopupMenuItem<String>(
                  value: 'claim_sales',
                  child: Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 18, color: Color(0xFF002B66)),
                      SizedBox(width: 8),
                      Text('Klaim Nama Sales'),
                    ],
                  ),
                ),
              const PopupMenuItem<String>(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF002B66)),
                    SizedBox(width: 8),
                    Text('Ekspor CSV (My Maps)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Tambah Target',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitFormScreen(initialDate: selectedDateStr),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Indikator Status Sinkronisasi yang tidak mengganggu
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: pendingCount > 0 ? Colors.amber.shade50 : Colors.green.shade50,
            child: Row(
              children: [
                Icon(
                  pendingCount > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
                  size: 15,
                  color: pendingCount > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isSyncing
                        ? 'Menyinkronkan data visit...'
                        : (pendingCount > 0
                            ? 'Belum tersinkron ($pendingCount)'
                            : 'Semua data tersimpan & sinkron'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: pendingCount > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                    ),
                  ),
                ),
                if (pendingCount > 0 && !isSyncing)
                  InkWell(
                    onTap: _onManualSyncPressed,
                    child: Text(
                      'Sinkronkan',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bar Pemilih Tanggal & Filter Kategori
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pemilih Tanggal
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF002B66)),
                      onPressed: () => _shiftDate(-1),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today, size: 15, color: Color(0xFF002B66)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF002B66),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF002B66)),
                      onPressed: () => _shiftDate(1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Chip Kategori Semua / RVAI / Dismantle / Unpaid dengan jumlah
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        key: const Key('filter_chip_all'),
                        label: Text('Semua ($totalCount)'),
                        selected: selectedCategory == null && !filterMissingForm,
                        selectedColor: const Color(0xFF002B66),
                        labelStyle: TextStyle(
                          color: (selectedCategory == null && !filterMissingForm)
                              ? Colors.white
                              : const Color(0xFF002B66),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          ref.read(visitSelectedCategoryProvider.notifier).state = null;
                          ref.read(visitFilterMissingFormProvider.notifier).state = false;
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const Key('filter_chip_missing_form'),
                        label: Text('Belum isi Form ($missingFormCount)'),
                        selected: filterMissingForm,
                        selectedColor: Colors.deepOrange.shade700,
                        labelStyle: TextStyle(
                          color: filterMissingForm
                              ? Colors.white
                              : Colors.deepOrange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          ref.read(visitFilterMissingFormProvider.notifier).state =
                              !filterMissingForm;
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const Key('filter_chip_rvai'),
                        label: Text('RVAI (${counts[VisitCategory.rvai] ?? 0})'),
                        selected: selectedCategory == VisitCategory.rvai,
                        selectedColor: Colors.green.shade700,
                        labelStyle: TextStyle(
                          color: selectedCategory == VisitCategory.rvai
                              ? Colors.white
                              : Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          ref.read(visitSelectedCategoryProvider.notifier).state =
                              VisitCategory.rvai;
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const Key('filter_chip_dismantle'),
                        label: Text('Dismantle (${counts[VisitCategory.dismantle] ?? 0})'),
                        selected: selectedCategory == VisitCategory.dismantle,
                        selectedColor: Colors.red.shade700,
                        labelStyle: TextStyle(
                          color: selectedCategory == VisitCategory.dismantle
                              ? Colors.white
                              : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          ref.read(visitSelectedCategoryProvider.notifier).state =
                              VisitCategory.dismantle;
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const Key('filter_chip_unpaid'),
                        label: Text('Unpaid (${counts[VisitCategory.unpaid] ?? 0})'),
                        selected: selectedCategory == VisitCategory.unpaid,
                        selectedColor: Colors.amber.shade700,
                        labelStyle: TextStyle(
                          color: selectedCategory == VisitCategory.unpaid
                              ? Colors.white
                              : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          ref.read(visitSelectedCategoryProvider.notifier).state =
                              VisitCategory.unpaid;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Banner Klaim Nama Sales bila akun sales belum klaim
          if (_needsSalesNameClaim)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, size: 18, color: Colors.indigo.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hubungkan nama sales Anda untuk menampilkan Pelanggan Saya & Saran RVAI.',
                      style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClaimSalesNameScreen(),
                        ),
                      );
                      if (mounted) {
                        _checkIfShouldPromptSalesNameClaim();
                      }
                    },
                    child: const Text(
                      'Pilih Nama',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Kartu / Section Saran RVAI (N) bila ada pelanggan jatuh tempo
          if (rvaiSuggestions.isNotEmpty)
            _buildRvaiSuggestionsSection(rvaiSuggestions),

          // Daftar Kartu Visit
          Expanded(
            child: visitsAsync.when(
              data: (rawVisits) {
                final visits = filterMissingForm
                    ? rawVisits
                        .where(
                          (v) =>
                              v.status == VisitStatus.sudahVisit &&
                              !v.formSubmitted,
                        )
                        .toList()
                    : rawVisits;
                if (visits.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada target visit pada tanggal ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tekan tombol "Tambah Target" di kanan bawah untuk mencatat rencana visit RVAI, Dismantle, atau Unpaid.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: visits.length,
                  itemBuilder: (context, index) {
                    final visit = visits[index];
                    final catColor = _categoryColor(visit.category);
                    final catBg = _categoryBgColor(visit.category);

                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: catColor.withValues(alpha: 0.45), width: 1.2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showVisitDetailSheet(context, visit),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Badge Kategori Berwarna
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: catBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: catColor),
                                    ),
                                    child: Text(
                                      visit.category.displayLabel.toUpperCase(),
                                      style: TextStyle(
                                        color: catColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Chip Status
                                  _buildStatusChip(visit.status),
                                  const Spacer(),

                                  // Ikon sudah isi Google Form
                                  if (visit.formSubmitted)
                                    Tooltip(
                                      message: 'Sudah isi Google Form',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.green.shade400),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.fact_check_rounded,
                                              size: 13,
                                              color: Colors.green.shade800,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Form OK',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Customer ID & Nama
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      visit.customerName.isNotEmpty
                                          ? '${visit.customerId} · ${visit.customerName}'
                                          : 'ID: ${visit.customerId}',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF002B66),
                                      ),
                                    ),
                                  ),
                                  if (visit.hasLocation)
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                ],
                              ),
                              if (visit.address.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  visit.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              if (visit.note.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Catatan: ${visit.note}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRvaiSuggestionsSection(List<RvaiSuggestionItem> suggestions) {
    final validSelectedCount = suggestions
        .where((s) => _selectedRvaiIds.contains(s.customer.customerId))
        .length;

    return Container(
      key: const Key('rvai_suggestions_card'),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade400, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _rvaiExpanded = !_rvaiExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    size: 18,
                    color: Colors.green.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saran RVAI (${suggestions.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                  if (_rvaiExpanded)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        setState(() {
                          if (validSelectedCount == suggestions.length) {
                            _selectedRvaiIds.clear();
                          } else {
                            for (final s in suggestions) {
                              _selectedRvaiIds.add(s.customer.customerId);
                            }
                          }
                        });
                      },
                      child: Text(
                        validSelectedCount == suggestions.length
                            ? 'Batal Semua'
                            : 'Pilih Semua',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  Icon(
                    _rvaiExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.green.shade800,
                  ),
                ],
              ),
            ),
          ),
          if (_rvaiExpanded) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 195),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final item = suggestions[idx];
                  final cid = item.customer.customerId;
                  final isChecked = _selectedRvaiIds.contains(cid);
                  return CheckboxListTile(
                    key: Key('rvai_suggestion_tile_$cid'),
                    value: isChecked,
                    dense: true,
                    activeColor: Colors.green.shade700,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedRvaiIds.add(cid);
                        } else {
                          _selectedRvaiIds.remove(cid);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Text(
                          'ID: $cid',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: Color(0xFF002B66),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.dueLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      item.customer.address.isNotEmpty
                          ? item.customer.address
                          : '(Alamat belum tersedia)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  key: const Key('rvai_add_selected_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: validSelectedCount == 0
                      ? null
                      : () => _addSelectedRvaiSuggestions(suggestions),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text(
                    validSelectedCount > 0
                        ? 'Tambahkan ke target hari ini ($validSelectedCount)'
                        : 'Tambahkan ke target hari ini',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(VisitStatus status) {
    final (label, color, bg) = switch (status) {
      VisitStatus.belum => ('Belum Visit', Colors.grey.shade800, Colors.grey.shade200),
      VisitStatus.sudahVisit => ('Sudah Visit', Colors.green.shade800, Colors.green.shade100),
      VisitStatus.followUp => ('Follow-up', Colors.orange.shade900, Colors.orange.shade100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _VisitDetailBottomSheet extends ConsumerStatefulWidget {
  final VisitActivity visit;

  const _VisitDetailBottomSheet({required this.visit});

  @override
  ConsumerState<_VisitDetailBottomSheet> createState() => _VisitDetailBottomSheetState();
}

class _VisitDetailBottomSheetState extends ConsumerState<_VisitDetailBottomSheet> {
  late VisitStatus _status;
  late TextEditingController _noteCtrl;
  late bool _formSubmitted;
  bool _isLoadingFormResponse = false;
  bool _isOfflineFormResponse = false;
  VisitFormResponse? _formResponse;

  @override
  void initState() {
    super.initState();
    _status = widget.visit.status;
    _noteCtrl = TextEditingController(text: widget.visit.note);
    _formSubmitted = widget.visit.formSubmitted;
    if (_formSubmitted) {
      _loadFormResponse();
    }
  }

  Future<void> _loadFormResponse() async {
    setState(() {
      _isLoadingFormResponse = true;
      _isOfflineFormResponse = false;
    });
    bool online = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      online = conn.any((c) => c != ConnectivityResult.none);
    } catch (_) {
      online = true;
    }
    if (!online) {
      if (!mounted) return;
      setState(() {
        _isLoadingFormResponse = false;
        _isOfflineFormResponse = true;
      });
      return;
    }
    final service = ref.read(visitSyncServiceProvider);
    final resp = await service.fetchFormResponseForVisit(
      clientId: widget.visit.clientId,
      ownerUserId: widget.visit.ownerUserId,
    );
    if (!mounted) return;
    setState(() {
      _formResponse = resp;
      _isLoadingFormResponse = false;
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveQuickUpdate() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    String? visitedAt = widget.visit.visitedAt;
    if (_status == VisitStatus.sudahVisit && (visitedAt == null || visitedAt.isEmpty)) {
      visitedAt = nowIso;
    }

    final updated = widget.visit.copyWith(
      status: _status,
      note: _noteCtrl.text.trim(),
      visitedAt: visitedAt,
      formSubmitted: _formSubmitted,
      updatedAt: nowIso,
    );

    await ref.read(visitProvider.notifier).updateVisit(updated);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status visit berhasil diperbarui!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openGoogleForm() async {
    final uri = VisitFormConfig.buildPrefillUri(
      customerId: widget.visit.customerId,
      category: widget.visit.category,
    );
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!mounted) return;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sudah Mengisi Google Form?'),
        content: const Text(
          'Apakah Anda sudah selesai mengirim laporan hasil visit di Google Form manajemen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Belum'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sudah Isi'),
          ),
        ],
      ),
    );

    if (submitted == true && mounted) {
      setState(() => _formSubmitted = true);
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final updated = widget.visit.copyWith(
        status: _status,
        note: _noteCtrl.text.trim(),
        formSubmitted: true,
        updatedAt: nowIso,
      );
      await ref.read(visitProvider.notifier).updateVisit(updated);
    }
  }

  Future<void> _confirmDelete() async {
    final id = widget.visit.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Target Visit?'),
        content: Text(
          'Target pelanggan ID ${widget.visit.customerId} akan dihapus dari daftar harian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await ref.read(visitProvider.notifier).deleteVisit(id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formConfigured = VisitFormConfig.isConfigured;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.visit.customerName.isNotEmpty
                        ? '${widget.visit.customerId} · ${widget.visit.customerName}'
                        : 'Customer ID: ${widget.visit.customerId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Lengkap',
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF002B66)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitFormScreen(initialVisit: widget.visit),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Hapus Target',
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  onPressed: _confirmDelete,
                ),
              ],
            ),
            if (widget.visit.address.isNotEmpty) ...[
              Text(
                widget.visit.address,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
            ],

            const Divider(),
            const SizedBox(height: 8),

            // Pilih Status
            const Text(
              'Status Kunjungan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: VisitStatus.values.map((st) {
                final selected = _status == st;
                return ChoiceChip(
                  label: Text(st.displayLabel),
                  selected: selected,
                  onSelected: (_) => setState(() => _status = st),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Catatan Hasil
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan Hasil Visit',
                hintText: 'Tulis hasil kunjungan atau tindak lanjut',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Ringkasan Jawaban Google Form bila formSubmitted == true
            if (_formSubmitted) ...[
              _buildFormResponseSummarySection(),
              const SizedBox(height: 14),
            ],

            // Tombol Navigasi & Isi Google Form
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Navigasi'),
                    onPressed: widget.visit.hasLocation
                        ? () {
                            LauncherHelper.openGoogleMaps(
                              widget.visit.latitude!,
                              widget.visit.longitude!,
                            );
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('visit_open_google_form_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Isi Google Form'),
                    onPressed: formConfigured ? _openGoogleForm : null,
                  ),
                ),
              ],
            ),

            if (!formConfigured) ...[
              const SizedBox(height: 6),
              Text(
                'Link Google Form belum dikonfigurasi (VISIT_FORM_URL kosong saat build).',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                ),
                onPressed: _saveQuickUpdate,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Simpan Status & Catatan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormResponseSummarySection() {
    final resp = _formResponse;
    final safePhotos = resp?.safeDrivePhotoUrls ?? const <String>[];

    return Container(
      key: const Key('visit_form_response_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_rounded,
                size: 17,
                color: Colors.green.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                _isOfflineFormResponse || resp == null
                    ? 'Form terkirim'
                    : 'Ringkasan Jawaban Google Form',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          if (_isLoadingFormResponse) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ] else if (resp != null) ...[
            const SizedBox(height: 8),
            if (resp.visitStatus.isNotEmpty)
              _formDetailLine('Status Form', resp.visitStatus),
            if (resp.result.isNotEmpty)
              _formDetailLine('Hasil Kunjungan', resp.result),
            if (resp.obstacles.isNotEmpty)
              _formDetailLine('Kendala', resp.obstacles.join(', ')),
            if (resp.note.isNotEmpty)
              _formDetailLine('Catatan Form', resp.note),
            if (resp.followUp.isNotEmpty)
              _formDetailLine('Tindak Lanjut', resp.followUp),
            if (safePhotos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < safePhotos.length; i++)
                    OutlinedButton.icon(
                      key: Key('visit_open_drive_photo_$i'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade900,
                        side: BorderSide(color: Colors.green.shade600),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 15),
                      label: Text(
                        safePhotos.length == 1
                            ? 'Buka Foto Bukti'
                            : 'Buka Foto ${i + 1}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () {
                        final uri = Uri.tryParse(safePhotos[i]);
                        if (uri != null &&
                            VisitFormResponse.isSafeGoogleDriveUrl(
                              safePhotos[i],
                            )) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _formDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
