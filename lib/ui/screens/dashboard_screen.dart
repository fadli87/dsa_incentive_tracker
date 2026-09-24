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

class DashboardScreen extends ConsumerWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

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
                  // 3. MENU UTAMA (8 FITUR HANDBOOK)
                  // ==========================================
                  const Text(
                    'Menu Utama',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.55,
                    children: [
                      // 1. Kalkulator Insentif
                      _buildMenuCard(
                        icon: Icons.calculate_rounded,
                        iconColor: const Color(0xFF002B66),
                        iconBgColor: const Color(0xFF002B66).withValues(alpha: 0.08),
                        title: 'Kalkulator Insentif',
                        subtitle: 'Simulasi komisi AE',
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(1);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CalculatorScreen()),
                            );
                          }
                        },
                      ),

                      // 2. Katalog Paket Jualan
                      _buildMenuCard(
                        icon: Icons.local_offer_rounded,
                        iconColor: const Color(0xFFF15A24),
                        iconBgColor: const Color(0xFFF15A24).withValues(alpha: 0.08),
                        title: 'Katalog Paket',
                        subtitle: 'FTTH, FWA & FMC',
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(2);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProductCatalogScreen()),
                            );
                          }
                        },
                      ),

                      // 3. Data Pelanggan (SA)
                      _buildMenuCard(
                        icon: Icons.people_alt_rounded,
                        iconColor: const Color(0xFF00897B),
                        iconBgColor: const Color(0xFF00897B).withValues(alpha: 0.08),
                        title: 'Data Pelanggan',
                        subtitle: 'Pencatatan pasang baru',
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(3);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SaListScreen()),
                            );
                          }
                        },
                      ),

                      // 4. Peta Sebaran Pelanggan
                      _buildMenuCard(
                        icon: Icons.map_rounded,
                        iconColor: const Color(0xFF1E88E5),
                        iconBgColor: const Color(0xFF1E88E5).withValues(alpha: 0.08),
                        title: 'Peta Pelanggan',
                        subtitle: 'Pin lokasi & GPS',
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(3);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SaListScreen()),
                            );
                          }
                        },
                      ),

                      // 5. Histori Insentif
                      _buildMenuCard(
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: const Color(0xFF7B1FA2),
                        iconBgColor: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
                        title: 'Histori Insentif',
                        subtitle: 'Rekap pencapaian',
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(4);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HistoryScreen()),
                            );
                          }
                        },
                      ),

                      // 6. Panduan Skema
                      _buildMenuCard(
                        icon: Icons.menu_book_rounded,
                        iconColor: const Color(0xFFD81B60),
                        iconBgColor: const Color(0xFFD81B60).withValues(alpha: 0.08),
                        title: 'Panduan Skema',
                        subtitle: 'Aturan AE & SPV',
                        onTap: () {
                          if (onNavigateToTab != null) {
                            onNavigateToTab!(5);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const GuideScreen()),
                            );
                          }
                        },
                      ),

                      // 7. ID Card Sales
                      _buildMenuCard(
                        icon: Icons.badge_rounded,
                        iconColor: const Color(0xFF3949AB),
                        iconBgColor: const Color(0xFF3949AB).withValues(alpha: 0.08),
                        title: 'ID Card Sales',
                        subtitle: 'Profil & identitas resmi',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const UserInfoScreen()),
                          );
                        },
                      ),

                      // 8. Catatan Pembaruan
                      _buildMenuCard(
                        icon: Icons.update_rounded,
                        iconColor: const Color(0xFF455A64),
                        iconBgColor: const Color(0xFF455A64).withValues(alpha: 0.08),
                        title: 'Info & Pembaruan',
                        subtitle: 'Versi aplikasi & bantuan',
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
  // HELPER WIDGET MENU CARD
  // ==========================================
  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
