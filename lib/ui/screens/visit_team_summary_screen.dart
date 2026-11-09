import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/launcher_helper.dart';
import '../../data/models/visit_activity.dart';
import '../../data/services/customer_master_service.dart';
import '../../data/services/visit_team_summary_service.dart';
import '../../providers/customer_master_provider.dart';
import '../../providers/visit_provider.dart';

/// Provider untuk `VisitTeamSummaryService` agar mudah di-override pada test
final visitTeamSummaryServiceProvider = Provider<VisitTeamSummaryService>((ref) {
  return VisitTeamSummaryService();
});

class VisitTeamSummaryScreen extends ConsumerStatefulWidget {
  final bool? isOnlineOverride;

  const VisitTeamSummaryScreen({
    super.key,
    this.isOnlineOverride,
  });

  @override
  ConsumerState<VisitTeamSummaryScreen> createState() => _VisitTeamSummaryScreenState();
}

class _VisitTeamSummaryScreenState extends ConsumerState<VisitTeamSummaryScreen> {
  late DateTime _fromDate;
  late DateTime _toDate;

  bool _isLoading = true;
  bool _isOffline = false;
  bool _isUnauthorized = false;
  String? _errorMsg;
  List<SalesVisitSummary> _summaries = [];
  List<RvaiComplianceRow> _rvaiCompliance = [];
  bool _rvaiExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
    _loadSummary();
  }

  Future<bool> _checkOnline() async {
    if (widget.isOnlineOverride != null) {
      return widget.isOnlineOverride!;
    }
    try {
      final res = await Connectivity().checkConnectivity();
      return res.any((c) => c != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
      _isUnauthorized = false;
      _errorMsg = null;
    });

    final online = await _checkOnline();
    if (!online) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
      return;
    }

    try {
      final service = ref.read(visitTeamSummaryServiceProvider);
      final masterService = ref.read(customerMasterServiceProvider);
      final data = await service.fetchTeamSummary(
        fromDate: formatVisitDate(_fromDate),
        toDate: formatVisitDate(_toDate),
      );
      List<RvaiComplianceRow> compliance = const [];
      try {
        compliance = await masterService.fetchRvaiCompliance(
          fromDate: _fromDate,
          toDate: _toDate,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _summaries = data;
        _rvaiCompliance = compliance;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final bool isPostgrestUnauth = e is PostgrestException &&
          (e.message.toLowerCase().contains('unauthorized') ||
              e.code == '42501' ||
              e.code == 'P0001');
      final errStr = e.toString().toLowerCase();
      setState(() {
        _isLoading = false;
        if (isPostgrestUnauth || errStr.contains('unauthorized')) {
          _isUnauthorized = true;
        } else {
          _errorMsg = e.toString();
        }
      });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      await _loadSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel =
        '${DateFormat("dd MMM yyyy").format(_fromDate)} – ${DateFormat("dd MMM yyyy").format(_toDate)}';

    final grandTotal = _summaries.fold<int>(0, (sum, s) => sum + s.total);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REKAP VISIT TIM (READ-ONLY)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Monitoring SPV / TSC · Hanya Baca',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan Rekap',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSummary,
          ),
        ],
      ),
      body: Column(
        children: [
          // Pemilih Rentang Tanggal
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF002B66)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rangeLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF002B66),
                              ),
                            ),
                          ),
                          const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF002B66)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF002B66),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Total: $grandTotal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isOffline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 56, color: Colors.orange.shade700),
              const SizedBox(height: 12),
              const Text(
                'Fitur Rekap Tim Memerlukan Koneksi Internet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Pastikan perangkat Anda terhubung ke internet untuk menarik rekap aktivitas visit seluruh sales dari server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isUnauthorized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 56, color: Colors.red.shade700),
              const SizedBox(height: 12),
              const Text(
                'Akses Rekap Tim Tidak Diizinkan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Hak akses SPV/TSC pada akun Anda tidak aktif atau telah dicabut. Hubungi Superadmin bila ini merupakan kekeliruan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 10),
              Text(
                'Gagal memuat rekap tim:\n$_errorMsg',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat Ulang'),
              ),
            ],
          ),
        ),
      );
    }

    if (_summaries.isEmpty && _rvaiCompliance.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data aktivitas visit tim pada rentang tanggal ini.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_rvaiCompliance.isNotEmpty) _buildRvaiComplianceCard(),
        if (_summaries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Belum ada data aktivitas visit tim pada rentang tanggal ini.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ..._summaries.map((item) => _buildSalesSummaryCard(item)),
      ],
    );
  }

  Widget _buildRvaiComplianceCard() {
    final totalDue = _rvaiCompliance.fold<int>(0, (sum, r) => sum + r.dueTotal);
    final totalVisited = _rvaiCompliance.fold<int>(
      0,
      (sum, r) => sum + r.visitedTotal,
    );
    final visibleRows = _rvaiExpanded
        ? _rvaiCompliance
        : _rvaiCompliance.take(5).toList();

    return Card(
      key: const Key('rvai_compliance_card'),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fact_check_rounded,
                  size: 18,
                  color: Colors.green.shade800,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ringkasan Kepatuhan RVAI per Sales',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalVisited / $totalDue Divisit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Perbandingan pelanggan jatuh tempo RVAI (H+7 install) vs sudah divisit (Read-Only).',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...visibleRows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.salesName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF001A40),
                            ),
                          ),
                          if (row.spvName.isNotEmpty || row.tscName.isNotEmpty)
                            Text(
                              [
                                if (row.spvName.isNotEmpty) 'SPV: ${row.spvName}',
                                if (row.tscName.isNotEmpty) 'TSC: ${row.tscName}',
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _statBadge(
                      'Sudah: ${row.visitedTotal} / ${row.dueTotal}',
                      row.visitedTotal >= row.dueTotal && row.dueTotal > 0
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                      row.visitedTotal >= row.dueTotal && row.dueTotal > 0
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                    ),
                  ],
                ),
              ),
            ),
            if (_rvaiCompliance.length > 5) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() => _rvaiExpanded = !_rvaiExpanded);
                  },
                  child: Text(
                    _rvaiExpanded
                        ? 'Sembunyikan'
                        : 'Lihat Semua (${_rvaiCompliance.length} Sales)',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSummaryCard(SalesVisitSummary item) {
    return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitMemberReadOnlyListScreen(
                    summary: item,
                    initialFromDate: _fromDate,
                    initialToDate: _toDate,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF002B66).withValues(alpha: 0.1),
                        child: Text(
                          item.displayName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF002B66),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Color(0xFF002B66),
                              ),
                            ),
                            if (item.memberEmail.isNotEmpty)
                              Text(
                                item.memberEmail,
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF002B66),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.total} Visit',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Jumlah per Kategori
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statBadge(
                        'RVAI: ${item.byCategory[VisitCategory.rvai] ?? 0}',
                        Colors.green.shade800,
                        Colors.green.shade50,
                      ),
                      _statBadge(
                        'Dismantle: ${item.byCategory[VisitCategory.dismantle] ?? 0}',
                        Colors.red.shade800,
                        Colors.red.shade50,
                      ),
                      _statBadge(
                        'Unpaid: ${item.byCategory[VisitCategory.unpaid] ?? 0}',
                        Colors.amber.shade900,
                        Colors.amber.shade50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Jumlah per Status
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statBadge(
                        'Sudah: ${item.byStatus[VisitStatus.sudahVisit] ?? 0}',
                        Colors.teal.shade800,
                        Colors.teal.shade50,
                      ),
                      _statBadge(
                        'Follow-up: ${item.byStatus[VisitStatus.followUp] ?? 0}',
                        Colors.orange.shade900,
                        Colors.orange.shade50,
                      ),
                      _statBadge(
                        'Belum: ${item.byStatus[VisitStatus.belum] ?? 0}',
                        Colors.grey.shade800,
                        Colors.grey.shade200,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _statBadge(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Layar Detail Daftar Visit per Sales (100% Read-Only: tanpa tombol ubah/hapus)
class VisitMemberReadOnlyListScreen extends ConsumerStatefulWidget {
  final SalesVisitSummary summary;
  final DateTime initialFromDate;
  final DateTime initialToDate;

  const VisitMemberReadOnlyListScreen({
    super.key,
    required this.summary,
    required this.initialFromDate,
    required this.initialToDate,
  });

  @override
  ConsumerState<VisitMemberReadOnlyListScreen> createState() =>
      _VisitMemberReadOnlyListScreenState();
}

class _VisitMemberReadOnlyListScreenState
    extends ConsumerState<VisitMemberReadOnlyListScreen> {
  VisitCategory? _selectedCategory;
  VisitStatus? _selectedStatus;
  int _page = 0;
  bool _isLoading = true;
  bool _hasMore = false;
  List<VisitActivity> _items = [];

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  Future<void> _loadPage({required bool reset}) async {
    if (reset) {
      setState(() {
        _page = 0;
        _isLoading = true;
        _items = [];
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final service = ref.read(visitTeamSummaryServiceProvider);
      final fetched = await service.fetchMemberVisits(
        memberId: widget.summary.memberId,
        fromDate: formatVisitDate(widget.initialFromDate),
        toDate: formatVisitDate(widget.initialToDate),
        category: _selectedCategory,
        status: _selectedStatus,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = fetched;
        } else {
          _items = [..._items, ...fetched];
        }
        _hasMore = fetched.length >= VisitTeamSummaryService.pageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.summary.displayName,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Detail Aktivitas Sales (Read-Only)',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Kategori & Status
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua Kategori'),
                    selected: _selectedCategory == null,
                    onSelected: (_) {
                      setState(() => _selectedCategory = null);
                      _loadPage(reset: true);
                    },
                  ),
                  const SizedBox(width: 6),
                  ...VisitCategory.values.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat.displayLabel),
                        selected: _selectedCategory == cat,
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                          _loadPage(reset: true);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<VisitStatus?>(
                    value: _selectedStatus,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Semua Status', style: TextStyle(fontSize: 12)),
                    items: [
                      const DropdownMenuItem<VisitStatus?>(
                        value: null,
                        child: Text('Semua Status', style: TextStyle(fontSize: 12)),
                      ),
                      ...VisitStatus.values.map(
                        (st) => DropdownMenuItem<VisitStatus?>(
                          value: st,
                          child: Text(st.displayLabel, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    onChanged: (st) {
                      setState(() => _selectedStatus = st);
                      _loadPage(reset: true);
                    },
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _items.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada data visit untuk filter ini.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return Center(
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        _page++;
                                        _loadPage(reset: false);
                                      },
                                child: const Text('Muat 50 Berikutnya'),
                              ),
                            );
                          }

                          final v = _items[index];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 10),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${v.category.displayLabel.toUpperCase()} · ${v.status.displayLabel}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF002B66),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        v.plannedDate,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    v.customerName.isNotEmpty
                                        ? '${v.customerId} · ${v.customerName}'
                                        : 'ID: ${v.customerId}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (v.address.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      v.address,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                  if (v.note.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Catatan: ${v.note}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  if (v.hasLocation) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.directions, size: 16),
                                        label: const Text('Lihat di Maps'),
                                        onPressed: () {
                                          LauncherHelper.openGoogleMaps(
                                            v.latitude!,
                                            v.longitude!,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
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

