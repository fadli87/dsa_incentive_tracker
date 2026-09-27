import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_info_provider.dart';
import 'user_info_screen.dart';
import 'update_notes_screen.dart';
import 'product_catalog_screen.dart';
import 'calculator_screen.dart';
import 'sa_list_screen.dart';
import 'history_screen.dart';
import 'guide_screen.dart';
import 'network_tools_screen.dart';
import 'coverage_map_screen.dart';
import '../../ai/widgets/ai_coach_chat_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userInfoProvider);

    final String displayName = profileAsync.maybeWhen(
      data: (p) => p.name.trim().isNotEmpty ? p.name : 'Rekan Sales',
      orElse: () => 'Rekan Sales',
    );
    final String displayCode = profileAsync.maybeWhen(
      data: (p) => p.salesCode.trim().isNotEmpty ? p.salesCode : 'KODE-BELUM-DIISI',
      orElse: () => 'KODE-BELUM-DIISI',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. HEADER BRANDING & PROFIL SALES
            // ==========================================
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF002B66), // Biru XL Navy
                    Color(0xFF004080),
                    Color(0xFF0056B3), // Biru Terang
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22002B66),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris Atas: Brand Tag & Avatar Profil
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 14,
                                  color: Color(0xFF00E5FF),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'DSA XL SATU HANDBOOK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // Avatar Profil (Tap untuk buka Info Pengguna)
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const UserInfoScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF00E5FF), width: 1.5),
                              ),
                              child: const CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 20,
                                  color: Color(0xFF002B66),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Sapaan & Nama Sales
                      Text(
                        'Halo, $displayName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Badge Kode Sales & Wilayah
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF15A24).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'KODE: $displayCode',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'XL SATU CILACAP · TSC PIPIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==========================================
                  // 2. BANNER HERO INFORMASI
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF002B66).withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF002B66).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Color(0xFF002B66),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Buku Saku Digital Sales',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF002B66),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Akses cepat kalkulasi insentif, paket jualan resmi, data pasang baru, dan peta lapangan.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. MENU UTAMA (CIRCULAR ICON GRID 3x3)
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menu Utama',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002B66),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF002B66).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '9 Fitur (AI & Sinyal)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF002B66).withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF002B66).withValues(alpha: 0.06),
                      ),
                    ),
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                      children: [
                        // 1. Kalkulator Insentif
                        _buildCircularMenuItem(
                          icon: Icons.calculate_rounded,
                          iconColor: const Color(0xFF0056B3),
                          gradientColors: const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                          shadowColor: const Color(0xFF1976D2).withValues(alpha: 0.25),
                          title: 'Kalkulator Insentif',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CalculatorScreen()),
                            );
                          },
                        ),

                        // 2. Katalog Paket Jualan
                        _buildCircularMenuItem(
                          icon: Icons.local_offer_rounded,
                          iconColor: const Color(0xFFF15A24),
                          gradientColors: const [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                          shadowColor: const Color(0xFFF15A24).withValues(alpha: 0.25),
                          title: 'Katalog Paket',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProductCatalogScreen()),
                            );
                          },
                        ),

                        // 3. Data Pelanggan (SA)
                        _buildCircularMenuItem(
                          icon: Icons.people_alt_rounded,
                          iconColor: const Color(0xFF00897B),
                          gradientColors: const [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
                          shadowColor: const Color(0xFF00897B).withValues(alpha: 0.25),
                          title: 'Data Pelanggan',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SaListScreen()),
                            );
                          },
                        ),

                        // 4. Sinyal & Speed Test (AURA Network)
                        _buildCircularMenuItem(
                          icon: Icons.cell_tower_rounded,
                          iconColor: const Color(0xFF6366F1),
                          gradientColors: const [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                          shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          title: 'Sinyal & Speed',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NetworkToolsScreen()),
                            );
                          },
                        ),

                        // 5. Tanya AI Coach (AURA Offline Assistant)
                        _buildCircularMenuItem(
                          icon: Icons.psychology_outlined,
                          iconColor: const Color(0xFF8B5CF6),
                          gradientColors: const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                          shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                          title: 'Tanya AI Coach',
                          onTap: () {
                            AiCoachChatSheet.show(context);
                          },
                        ),

                        // 6. Peta Coverage & BTS XL
                        _buildCircularMenuItem(
                          icon: Icons.map_rounded,
                          iconColor: const Color(0xFF1E88E5),
                          gradientColors: const [Color(0xFFE1F5FE), Color(0xFFB3E5FC)],
                          shadowColor: const Color(0xFF0288D1).withValues(alpha: 0.25),
                          title: 'Peta Coverage',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CoverageMapScreen()),
                            );
                          },
                        ),

                        // 7. Histori Insentif
                        _buildCircularMenuItem(
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: const Color(0xFF8E24AA),
                          gradientColors: const [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
                          shadowColor: const Color(0xFF8E24AA).withValues(alpha: 0.25),
                          title: 'Histori Insentif',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HistoryScreen()),
                            );
                          },
                        ),

                        // 8. Panduan Skema
                        _buildCircularMenuItem(
                          icon: Icons.menu_book_rounded,
                          iconColor: const Color(0xFFD81B60),
                          gradientColors: const [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
                          shadowColor: const Color(0xFFD81B60).withValues(alpha: 0.25),
                          title: 'Panduan Skema',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const GuideScreen()),
                            );
                          },
                        ),

                        // 9. Catatan Pembaruan & Versi
                        _buildCircularMenuItem(
                          icon: Icons.update_rounded,
                          iconColor: const Color(0xFF546E7A),
                          gradientColors: const [Color(0xFFECEFF1), Color(0xFFCFD8DC)],
                          shadowColor: const Color(0xFF546E7A).withValues(alpha: 0.25),
                          title: 'Info & Versi',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const UpdateNotesScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 4. FOOTER IDENTITAS RESMI
                  // ==========================================
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "DSA XL Satu Handbook • Ver.1.0.6",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Copyright D'Azhars Studio · Offline & Aman",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGET CIRCULAR MENU ITEM
  // ==========================================
  Widget _buildCircularMenuItem({
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required Color shadowColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF002B66),
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
