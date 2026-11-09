import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/launcher_helper.dart';
import '../../data/services/sa_team_service.dart';

/// Layar read-only "Data SA Tim" untuk SPV / TSC / Admin / Superadmin (Fase 11D).
///
/// Tidak memiliki tombol ubah maupun hapus (100% hanya baca).
class SaTeamListScreen extends ConsumerStatefulWidget {
  const SaTeamListScreen({super.key});

  @override
  ConsumerState<SaTeamListScreen> createState() => _SaTeamListScreenState();
}

class _SaTeamListScreenState extends ConsumerState<SaTeamListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _searchQuery = '';
  String? _selectedUserId;

  List<TeamSaCustomerItem> _items = const [];
  final Map<String, String> _knownMembers = {}; // userId -> memberName

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _errorCode = null;
    });

    try {
      final service = ref.read(saTeamServiceProvider);
      final rows = await service.fetchSaCustomers(
        search: _searchQuery,
        userId: _selectedUserId,
        limit: SaTeamService.pageSize,
        offset: 0,
      );
      for (final r in rows) {
        if (r.userId.isNotEmpty) {
          _knownMembers[r.userId] =
              r.memberName.trim().isNotEmpty ? r.memberName.trim() : r.userId;
        }
      }
      if (!mounted) return;
      setState(() {
        _items = rows;
        _hasMore = rows.length >= SaTeamService.pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      setState(() {
        _isLoading = false;
        _errorCode = msg.contains('unauthorized')
            ? 'unauthorized'
            : 'network_or_offline';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final service = ref.read(saTeamServiceProvider);
      final moreRows = await service.fetchSaCustomers(
        search: _searchQuery,
        userId: _selectedUserId,
        limit: SaTeamService.pageSize,
        offset: _items.length,
      );
      for (final r in moreRows) {
        if (r.userId.isNotEmpty) {
          _knownMembers[r.userId] =
              r.memberName.trim().isNotEmpty ? r.memberName.trim() : r.userId;
        }
      }
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...moreRows];
        _hasMore = moreRows.length >= SaTeamService.pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _searchQuery = val.trim();
      _loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data SA Tim',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Hanya Baca (Read-Only) · SPV / TSC / Admin',
              style: TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadInitial,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bar pencarian & filter per sales
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                TextField(
                  key: const Key('sa_team_search_field'),
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari nama pelanggan, ID pelanggan, atau No. HP...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _searchQuery = '';
                              _loadInitial();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (_knownMembers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_search_outlined,
                        size: 18,
                        color: Color(0xFF002B66),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Filter Sales:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            key: const Key('sa_team_sales_filter_dropdown'),
                            isExpanded: true,
                            isDense: true,
                            value: _selectedUserId,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'Semua Sales',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ),
                              ..._knownMembers.entries.map(
                                (e) => DropdownMenuItem<String?>(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    style: const TextStyle(fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedUserId = val);
                              _loadInitial();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorCode != null) {
      final isUnauthorized = _errorCode == 'unauthorized';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUnauthorized
                    ? Icons.lock_outline_rounded
                    : Icons.wifi_off_rounded,
                size: 56,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 12),
              Text(
                isUnauthorized
                    ? 'Akses tidak diizinkan atau peran Anda telah berubah.'
                    : 'Data SA Tim hanya dapat diakses saat terhubung ke internet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF002B66),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loadInitial,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data pelanggan SA yang ditemukan.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton.icon(
                key: const Key('btn_load_more_sa_team'),
                onPressed: _isLoadingMore ? null : _loadMore,
                icon: _isLoadingMore
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('Muat Lebih Banyak'),
              ),
            ),
          );
        }

        final item = _items[index];
        return _buildCustomerCard(item);
      },
    );
  }

  Widget _buildCustomerCard(TeamSaCustomerItem item) {
    final salesLabel = item.memberName.trim().isNotEmpty
        ? item.memberName.trim()
        : 'Sales Tim';
    final dateLabel = (item.tanggalPasang != null &&
            item.tanggalPasang!.trim().isNotEmpty)
        ? item.tanggalPasang!.trim()
        : '-';

    return Card(
      key: Key('sa_team_card_${item.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF001A40),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID Pelanggan: ${item.idPelanggan}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF002B66).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Sales: $salesLabel',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (item.paket.trim().isNotEmpty)
                  Text(
                    'Paket: ${item.paket}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  'Tgl Pasang: $dateLabel',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            if (item.alamat.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.alamat,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.noHpUtama.trim().isNotEmpty
                        ? 'HP: ${item.noHpUtama}${item.noHpAlternatif.trim().isNotEmpty ? " / ${item.noHpAlternatif}" : ""}'
                        : 'HP: -',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (item.hasValidPrimaryPhone) ...[
                  IconButton(
                    key: Key('btn_call_${item.id}'),
                    tooltip: 'Telepon Pelanggan',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.phone_in_talk_rounded,
                      size: 19,
                      color: Color(0xFF002B66),
                    ),
                    onPressed: () =>
                        LauncherHelper.makePhoneCall(item.noHpUtama),
                  ),
                  IconButton(
                    key: Key('btn_wa_${item.id}'),
                    tooltip: 'Hubungi via WhatsApp',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.chat_rounded,
                      size: 19,
                      color: Colors.green.shade700,
                    ),
                    onPressed: () =>
                        LauncherHelper.openWhatsApp(item.noHpUtama),
                  ),
                ],
                if (item.hasLocation)
                  IconButton(
                    key: Key('btn_nav_${item.id}'),
                    tooltip: 'Navigasi Google Maps',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.directions_rounded,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                    onPressed: () => LauncherHelper.openGoogleMaps(
                      item.latitude!,
                      item.longitude!,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

