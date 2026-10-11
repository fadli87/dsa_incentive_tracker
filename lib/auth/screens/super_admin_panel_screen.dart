import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member_status.dart';
import '../models/team_member_item.dart';
import '../providers/auth_providers.dart';
import '../supabase_client.dart';

/// Layar Panel Kontrol Superadmin untuk Manajemen Anggota & Kode Akses Tim
class SuperAdminPanelScreen extends ConsumerStatefulWidget {
  const SuperAdminPanelScreen({super.key});

  @override
  ConsumerState<SuperAdminPanelScreen> createState() => _SuperAdminPanelScreenState();
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
                Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'PANEL SUPERADMIN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
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
            onPressed: () => ref.read(teamMembersProvider.notifier).refresh(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersTab(membersAsync),
          _buildAccessCodeTab(),
        ],
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
          final matchesQuery = query.isEmpty ||
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
          onRefresh: () => ref.read(teamMembersProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF002B66)),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                      Icon(Icons.person_search_rounded, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada anggota yang cocok dengan filter.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map((member) => _buildMemberCard(member, currentUserId)),
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
                onPressed: () => ref.read(teamMembersProvider.notifier).refresh(),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
                      color: member.isSuperadmin ? Colors.amber.shade900 : const Color(0xFF002B66),
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
                              member.name.isNotEmpty ? member.name : '(Nama belum diisi)',
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Status Badges & Action Buttons Row
            Row(
              children: [
                // Role Badge
                if (member.isSuperadmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade600),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, size: 12, color: Colors.amber.shade900),
                        const SizedBox(width: 4),
                        Text(
                          'SUPERADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (member.isSuperadmin) const SizedBox(width: 8),

                // Status Badge
                _statusBadge(member.status),

                const Spacer(),

                // Actions
                if (!isMe && !member.isSuperadmin) ...[
                  if (member.isPending) ...[
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.green.shade600),
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      tooltip: 'Setujui Akses',
                      onPressed: () => _confirmChangeStatus(member, MemberStatus.approved),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.red.shade600),
                      icon: const Icon(Icons.close, size: 16, color: Colors.white),
                      tooltip: 'Tolak / Cabut Akses',
                      onPressed: () => _confirmChangeStatus(member, MemberStatus.revoked),
                    ),
                  ] else if (member.isApproved) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.block, size: 14),
                      label: const Text('Cabut Akses', style: TextStyle(fontSize: 11)),
                      onPressed: () => _confirmChangeStatus(member, MemberStatus.revoked),
                    ),
                  ] else if (member.isRevoked) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Pulihkan Akses', style: TextStyle(fontSize: 11)),
                      onPressed: () => _confirmChangeStatus(member, MemberStatus.approved),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(MemberStatus status) {
    final (label, color, bg) = switch (status) {
      MemberStatus.approved => ('Aktif (Approved)', Colors.green.shade800, Colors.green.shade50),
      MemberStatus.pending => ('Menunggu Kode', Colors.orange.shade900, Colors.orange.shade50),
      MemberStatus.revoked => ('Akses Dicabut', Colors.red.shade900, Colors.red.shade50),
      MemberStatus.unknown => ('Tidak Diketahui', Colors.grey.shade700, Colors.grey.shade100),
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
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _confirmChangeStatus(TeamMemberItem member, MemberStatus newStatus) async {
    final actionName = newStatus == MemberStatus.approved ? 'Menyetujui' : 'Mencabut';
    final actionColor = newStatus == MemberStatus.approved ? Colors.green.shade700 : Colors.red.shade700;

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
            style: ElevatedButton.styleFrom(backgroundColor: actionColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus == MemberStatus.approved ? 'Setujui' : 'Cabut Akses'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final res = await ref.read(teamMembersProvider.notifier).updateStatus(member.userId, newStatus);
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
                Icon(Icons.security_rounded, color: Colors.amber.shade900, size: 24),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                          _obscureNewCode ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscureNewCode = !_obscureNewCode),
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
                          _obscureConfirmCode ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscureConfirmCode = !_obscureConfirmCode),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isUpdatingCode
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isUpdatingCode ? 'Menyimpan...' : 'Perbarui Kode Akses Tim',
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
