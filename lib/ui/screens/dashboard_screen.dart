import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_info_provider.dart';
import '../../providers/sa_provider.dart';
import 'user_info_screen.dart';
import 'update_notes_screen.dart';
import 'product_catalog_screen.dart';
import 'calculator_screen.dart';
import 'sa_list_screen.dart';
import 'history_screen.dart';
import 'guide_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _attendanceDays = 14;
  final int _minAttendance = 25;
  String _selectedMonth = 'Sep';
  String _selectedYear = '2026';

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  final List<String> _years = ['2025', '2026', '2027'];

  void _showAttendanceDialog() {
    final controller = TextEditingController(text: _attendanceDays.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Kehadiran (Attendance)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan jumlah hari kerja hadir bulan ini:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Hari Hadir',
                border: OutlineInputBorder(),
                suffixText: 'Hari',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 0 && val <= 31) {
                setState(() => _attendanceDays = val);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002B66),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userInfoProvider);
    final saListAsync = ref.watch(saProvider);
    final int saCount = saListAsync.valueOrNull?.length ?? 8;

    final String displayName = profileAsync.maybeWhen(
      data: (p) => p.name.trim().isNotEmpty ? p.name.toUpperCase() : 'FADLI SANTOSO',
      orElse: () => 'FADLI SANTOSO',
    );
    final String displayCode = profileAsync.maybeWhen(
      data: (p) => p.salesCode.trim().isNotEmpty ? p.salesCode.toUpperCase() : 'XLS-DTD-16824',
      orElse: () => 'XLS-DTD-16824',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. HEADER GRADIENT XLSMART
            // ==========================================
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0D47A1), // Deep Blue
                    Color(0xFF4A148C), // Deep Purple
                    Color(0xFFC2185B), // Magenta
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Row(
                    children: [
                      // Logo XLSMART
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF), Color(0xFFB0BEC5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(1, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.public,
                                color: Color(0xFF002B66),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'XLSMART',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Greeting & Profil Sales
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UserInfoScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Hi, $displayName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayCode,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Color(0xFF002B66),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==========================================
                  // 2. ATTENDANCE CARD
                  // ==========================================
                  Row(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          children: [
                            const TextSpan(
                              text: 'Attendance, ',
                              style: TextStyle(color: Color(0xFF002B66)),
                            ),
                            TextSpan(
                              text: '$_selectedMonth $_selectedYear',
                              style: const TextStyle(color: Color(0xFFC2185B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          ref.invalidate(userInfoProvider);
                          ref.invalidate(saProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Data Dashboard tersinkronisasi.'),
                              duration: Duration(milliseconds: 900),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(
                            Icons.sync,
                            size: 15,
                            color: Color(0xFF002B66),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Card Attendance Box
                  InkWell(
                    onTap: _showAttendanceDialog,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          // My Attendance
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '$_attendanceDays',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF002B66),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'My Attendance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            height: 44,
                            width: 1,
                            color: Colors.grey.shade200,
                          ),

                          // Min Attendance
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '$_minAttendance',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFC2185B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Min Attendance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ==========================================
                  // 3. 3 KARTU METRIK UTAMA (LEADS, SALES, SA PAID)
                  // ==========================================
                  Row(
                    children: [
                      // LEADS
                      Expanded(
                        child: _buildMetricCard(
                          title: 'LEADS',
                          items: [
                            _MetricItem('My Leads', '220'),
                            _MetricItem('Open', '0'),
                            _MetricItem('Visited', '155'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // SALES
                      Expanded(
                        child: _buildMetricCard(
                          title: 'SALES',
                          items: [
                            _MetricItem('Completed', '0'),
                            _MetricItem('Pending', '0'),
                            _MetricItem('Ongoing', '0'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // SA PAID
                      Expanded(
                        child: Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF002B66),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: const Text(
                                  'SA PAID',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '$saCount',
                                    style: const TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF002B66),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // 4. GRID 8 MENU CEPAT (QUICK ACTIONS)
                  // ==========================================
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.88,
                    children: [
                      _buildQuickAction(
                        icon: Icons.point_of_sale_rounded,
                        label: 'POS',
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(2); // Paket Jualan
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProductCatalogScreen()),
                            );
                          }
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.apartment_rounded,
                        label: 'APARTMENT',
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(5); // Panduan
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GuideScreen()),
                            );
                          }
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.support_agent_rounded,
                        label: 'HOME COMPLAINT',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UpdateNotesScreen()),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.alt_route_rounded,
                        label: 'LEAD',
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(4); // Insentif
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HistoryScreen()),
                            );
                          }
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.badge_rounded,
                        label: 'BUILDING ID',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UserInfoScreen()),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.real_estate_agent_rounded,
                        label: 'SALES',
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(3); // Data SA
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SaListScreen()),
                            );
                          }
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: 'DSA DASHBOARD',
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(1); // Kalkulator
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CalculatorScreen()),
                            );
                          }
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.home_work_rounded,
                        label: 'HOMEPASS',
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(3); // Data SA & Map
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SaListScreen()),
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // 5. PANEL "MY SALES" (PIPELINE PENJUALAN)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header My Sales + Date Filter
                        Row(
                          children: [
                            const Text(
                              'My Sales',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF002B66),
                              ),
                            ),
                            const Spacer(),

                            // Filter Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF002B66).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_month_outlined,
                                    size: 15,
                                    color: Color(0xFF002B66),
                                  ),
                                  const SizedBox(width: 4),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedMonth,
                                      isDense: true,
                                      items: _months.map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      )).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedMonth = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedYear,
                                      isDense: true,
                                      items: _years.map((y) => DropdownMenuItem(
                                        value: y,
                                        child: Text(y, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      )).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedYear = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // SO Created
                        _buildPipelineRow(
                          title: 'SO Created',
                          badgeCount: '0',
                          status1: _StatusCount('0', 'OK'),
                          status2: _StatusCount('0', 'Pending'),
                          status3: _StatusCount('8', 'Paid(PBI)'),
                        ),
                        const SizedBox(height: 10),

                        // WO Created
                        _buildPipelineRow(
                          title: 'WO Created',
                          badgeCount: '$saCount',
                          status1: _StatusCount('0', 'OK'),
                          status2: _StatusCount('0', 'Return'),
                          status3: _StatusCount('0', 'Cancel'),
                        ),
                        const SizedBox(height: 10),

                        // SA Installation
                        _buildPipelineRow(
                          title: 'SA Installation',
                          badgeCount: '$saCount',
                          status1: _StatusCount('0', 'OK'),
                          status2: _StatusCount('0', 'Return'),
                          status3: _StatusCount('0', 'Cancel'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET HELPERS
  // ==========================================

  Widget _buildMetricCard({required String title, required List<_MetricItem> items}) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF002B66),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: items.map((it) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      it.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      it.value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002B66),
                      ),
                    ),
                  ],
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikon Bergradien Ungu-Magenta
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFFC2185B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF002B66),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineRow({
    required String title,
    required String badgeCount,
    required _StatusCount status1,
    required _StatusCount status2,
    required _StatusCount status3,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Title + Badge Count
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    badgeCount,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          Container(height: 24, width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 8),

          // 3 Status Items
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusCell(status1),
                _buildStatusCell(status2),
                _buildStatusCell(status3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(_StatusCount s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.count,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFFC2185B),
          ),
        ),
        Text(
          s.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  _MetricItem(this.label, this.value);
}

class _StatusCount {
  final String count;
  final String label;
  _StatusCount(this.count, this.label);
}
