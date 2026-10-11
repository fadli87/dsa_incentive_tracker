import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/catalog/package_catalog.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _includePpn = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatPrice(int excPpnPrice) {
    if (_includePpn) {
      final incPpn = (excPpnPrice * 1.11).round();
      return '${currencyFmt.format(incPpn)} / bln (Inc. PPN)';
    }
    return '${currencyFmt.format(excPpnPrice)} / bln (Exc. PPN)';
  }

  void _copyToClipboard(BuildContext context, String text, String packageName) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Rincian paket "$packageName" berhasil disalin! Siap dikirim ke WhatsApp.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'KATALOG PAKET JUALAN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Acuan Resmi Launch 19 Sep 2026 · XL SATU CILACAP • TSC PIPIN',
              style: TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            children: [
              // Search & PPN Switch bar
              Container(
                color: const Color(0xFF001F4D),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Cari paket (cth: 250 Mbps, Smart, Pay 3)...',
                            hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF002B66)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // PPN Switch
                    InkWell(
                      onTap: () => setState(() => _includePpn = !_includePpn),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _includePpn ? const Color(0xFFF15A24) : Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _includePpn ? const Color(0xFFF15A24) : Colors.white30,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _includePpn ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 15,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'PPN 11%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // TabBar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFFF15A24),
                indicatorWeight: 3.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: const [
                  Tab(text: '1. Internet Only'),
                  Tab(text: '2. FMC Kuota HP'),
                  Tab(text: '3. Advance (PXGY)'),
                  Tab(text: '4. Combo TV (FM)'),
                  Tab(text: '5. S&K & Kode OWS'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInternetOnlyTab(),
          _buildFmcTab(),
          _buildAdvancePayTab(),
          _buildComboTvTab(),
          _buildSnkAndOwsTab(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: INTERNET ONLY
  // -------------------------------------------------------------
  Widget _buildInternetOnlyTab() {
    final packages = PackageCatalog.byTab(1);

    final filtered = packages.where((p) {
      if (_searchQuery.isEmpty) return true;
      final text = '${p.title} ${p.speedLabel} ${p.type}'.toLowerCase();
      return text.contains(_searchQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildInfoBanner(
          'Seluruh paket Internet Only berlaku harga flat selama berlangganan. Speed Upgrade berlaku 12 bulan dan dapat diperpanjang bila pembayaran lancar.',
        ),
        const SizedBox(height: 10),
        ...filtered.map((p) => _buildPackageCard(p)),

        // FWA Booster section
        const SizedBox(height: 16),
        _buildBoosterSection(),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 2: FMC KUOTA HP (BUNDLING)
  // -------------------------------------------------------------
  Widget _buildFmcTab() {
    final packages = PackageCatalog.byTab(2);
    final promosPay10Get12 = PackageCatalog.promosPay10Get12;

    final filtered = packages.where((p) {
      if (_searchQuery.isEmpty) return true;
      final text = '${p.title} ${p.speedLabel} ${p.type}'.toLowerCase();
      return text.contains(_searchQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildInfoBanner(
          'Paket FMC menggabungkan Internet Rumah Cepat + Kuota HP Sekeluarga yang bisa dibagi hingga 3 anggota keluarga. Plus gratis 2 kartu perdana XL!',
        ),
        const SizedBox(height: 10),
        ...filtered.map((p) => _buildPackageCard(p)),

        // Section Pay 10 Get 12
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade400, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.stars, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'PROMO PAY 10 GET 12 (BAYAR 10 DAPAT 12 BULAN)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Bayar 10 bulan di depan, gratis bulan ke-11 dan ke-12! Solusi hemat tanpa repot bayar bulanan.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
              ),
              const Divider(height: 18),
              ...promosPay10Get12.map((promo) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            promo.speed,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currencyFmt.format(promo.totalPrice),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFFF15A24),
                                    ),
                                  ),
                                  Text(
                                    'Normal: ${currencyFmt.format(promo.normalPrice)}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade500,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                promo.equivalent,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: ADVANCE PAYMENT (PAY X GET Y)
  // -------------------------------------------------------------
  Widget _buildAdvancePayTab() {
    final packages = PackageCatalog.byTab(3);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildInfoBanner(
          'Skema Advance Payment (Pay X Get Y): Pembayaran di muka selesai sebelum teknisi melakukan instalasi (PBI). Pelanggan menikmati diskon bundling besar di awal dan bonus OTT 3 bulan.',
        ),
        const SizedBox(height: 10),
        ...packages.map((p) => _buildAdvanceCard(p)),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 4: COMBO INTERNET + TV (FIRSTMEDIA FOOTPRINT)
  // -------------------------------------------------------------
  Widget _buildComboTvTab() {
    final packages = PackageCatalog.byTab(4);
    final promos = PackageCatalog.promosCombo;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildInfoBanner(
          'Paket Combo menggabungkan Internet Rumah + Siaran TV Berkualitas + Kuota HP Sekeluarga untuk area Firstmedia (FM Footprint).',
        ),
        const SizedBox(height: 10),
        ...packages.map((p) => _buildComboCard(p)),

        const SizedBox(height: 16),
        // Promo Silver & Gold Section
        ...promos.map((pr) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.loyalty, color: Color(0xFFF15A24), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        pr.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF002B66)),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  ...pr.items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFFF15A24), fontWeight: FontWeight.bold)),
                            Expanded(child: Text(it, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                ],
              ),
            )),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 5: S&K & KODE OWS
  // -------------------------------------------------------------
  Widget _buildSnkAndOwsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildCardSection(
          title: 'Syarat & Ketentuan Umum Penjualan',
          icon: Icons.gavel,
          children: const [
            _Bullet(
              'Paket berlaku untuk program akuisisi pelanggan baru di area footprint XL SATU dan FM (Homepass Class HOME & BIZ).',
            ),
            _Bullet(
              'Minimum masa berlangganan adalah 12 bulan. Pelanggan yang berhenti sebelum 12 bulan dikenakan penalti Rp 1.000.000.',
            ),
            _Bullet(
              'Harga yang tertera belum termasuk PPN 11% (kecuali disebutkan Inc. PPN).',
            ),
            _Bullet(
              'Harga flat berlaku selama pelanggan aktif berlangganan tanpa perubahan paket.',
            ),
            _Bullet(
              'Pelanggan mendapatkan 2 SIM card XL Prabayar gratis yang diserahkan langsung oleh teknisi saat pemasangan.',
            ),
            _Bullet(
              'Apabila lokasi tercover Homepass FTTH, wajib ditawarkan produk FTTH. Jika hanya tercover FWA, ditawarkan paket FWA.',
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildCardSection(
          title: 'Panduan Aktivasi Layanan OTT (Vidio & Catchplay+)',
          icon: Icons.live_tv,
          children: const [
            _Bullet(
              'Aktivasi Otomatis (H+3): Akun Vidio & Catchplay+ aktif maksimal 3 hari kerja setelah instalasi selesai dan pelanggan menerima Welcoming WABA (WhatsApp).',
            ),
            _Bullet(
              'Login Vidio: Buka aplikasi Vidio ➔ Masuk ➔ Gunakan nomor HP/MSISDN yang didaftarkan saat registrasi XL Satu ➔ Masukkan kode OTP via WA.',
            ),
            _Bullet(
              'Login Catchplay+: Buka web/app Catchplay+ ➔ Masuk via Nomor HP terdaftar ➔ Gunakan password default 8 digit terakhir nomor HP.',
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildCardSection(
          title: 'Referensi Kode Bundling OWS (Untuk Input Order Sales)',
          icon: Icons.code,
          children: const [
            _OwsRow('FTTH 20 Mbps', 'BDL_L4_XL_SATU_SPARK_STARTER_FTTH', 'Rp 185.000'),
            _OwsRow('FTTH 250 Mbps', 'BDL_FTTH_HOME_250MBPS_NONTV', 'Rp 229.000'),
            _OwsRow('FTTH 300 Mbps', 'BDL_FTTH_HOME_300MBPS_NONTV', 'Rp 239.000'),
            _OwsRow('FTTH 400 Mbps', 'BDL_FTTH_HOME_400MBPS_NONTV', 'Rp 299.000'),
            _OwsRow('FTTH 500 Mbps', 'BDL_FTTH_HOME_500MBPS_NONTV', 'Rp 399.000'),
            _OwsRow('FTTH 1 Gbps', 'BDL_FTTH_HOME_1GBPS_NONTV', 'Rp 899.000'),
            _OwsRow('FWA 100 Mbps', 'BFWA_XL_Satu_100Mbps_ODU_NP', 'Rp 219.000'),
            _OwsRow('FMC Smart 50M', 'BDL_L2.1_FTTH_XL_SATU_BASIC_SMART', 'Rp 249.000'),
            _OwsRow('FMC Family 100M', 'BDL_L2.1_FTTH_XL_SATU_BASIC_FAMILY', 'Rp 319.000'),
            _OwsRow('Advance 50M 4Bln', 'TAC_PAY3_GET4_SPARK_50MBPS', 'Rp 650.000'),
            _OwsRow('Advance 100M 4Bln', 'TAC_PAY3_GET4_SPARK_100MBPS', 'Rp 790.000'),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // REUSABLE CARDS & WIDGETS
  // -------------------------------------------------------------
  Widget _buildInfoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF002B66), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(CatalogPackage p) {
    final priceStr = _formatPrice(p.price);
    final isFree = p.isFreeInstall;

    final shareText = '''
*PENAWARAN PAKET XL SATU*
---------------------------------
📦 Paket: ${p.title}
🚀 Kecepatan: ${p.speedLabel}
💰 Biaya: ${_formatPrice(p.price)}
🎁 Instalasi: ${p.installation}
${p.speedUpgrade != null ? '⚡ Benefit: ${p.speedUpgrade}\n' : ''}⭐ Keunggulan:
${p.features.map((f) => '  • $f').join('\n')}
---------------------------------
Tertarik pasang? Hubungi saya untuk cek jangkauan jaringan rumah Anda!
(XL SATU CILACAP · TSC PIPIN)
''';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.tagColor),
                  ),
                  child: Text(
                    p.tag,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: p.tagColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Speed Upgrade Badge if available
            if (p.speedUpgrade != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        p.speedUpgrade!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Price & Install Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  priceStr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF15A24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  isFree ? Icons.check_circle : Icons.payment,
                  size: 13,
                  color: isFree ? Colors.green : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  p.installation,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isFree ? FontWeight.bold : FontWeight.normal,
                    color: isFree ? Colors.green.shade800 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            const Divider(height: 18),

            // Features list
            ...p.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Color(0xFF002B66), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(f, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 10),

            // Share / Copy button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share, size: 14),
                label: const Text('Salin Rincian Penawaran', style: TextStyle(fontSize: 11.5)),
                onPressed: () => _copyToClipboard(context, shareText, p.title),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvanceCard(CatalogPackage p) {
    final totalAdv = p.totalAdvance ?? p.price;
    final normalAdv = p.normalAdvance ?? (p.price * 1.5).round();
    final recurringStr = p.recurring ?? '';

    final shareText = '''
*PROMO BAYAR DI MUKA XL SATU (PXGY)*
---------------------------------
📦 Paket: ${p.title}
🚀 Kecepatan: ${p.speedLabel}
💵 Total Bayar: ${currencyFmt.format(totalAdv)} (Hemat!)
💰 Setara: ${currencyFmt.format(p.price)} / bulan
🎁 Instalasi: GRATIS
📺 Bonus OTT: Free 3 Bulan Vidio & Catchplay+
---------------------------------
Minat pasang sekarang? Hubungi saya (Sales Resmi XL SATU CILACAP).
''';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF002B66)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.tagColor),
                  ),
                  child: Text(
                    p.tag,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: p.tagColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Pembayaran di Muka:', style: TextStyle(fontSize: 10.5, color: Colors.black54)),
                      Text(
                        currencyFmt.format(totalAdv),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      Text(
                        'Normal: ${currencyFmt.format(normalAdv)}',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, decoration: TextDecoration.lineThrough),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        const Text('Setara Biaya/Bulan', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                        Text(
                          currencyFmt.format(p.price),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF15A24)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (recurringStr.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(recurringStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
            const Divider(height: 16),

            ...p.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                )),

            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share, size: 14),
                label: const Text('Salin Rincian Penawaran', style: TextStyle(fontSize: 11.5)),
                onPressed: () => _copyToClipboard(context, shareText, p.title),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboCard(CatalogPackage p) {
    final priceStr = _formatPrice(p.price);

    final shareText = '''
*PAKET COMBO XL SATU (INTERNET + TV)*
---------------------------------
📦 Paket: ${p.title}
🚀 Kecepatan: ${p.speedLabel}
💰 Biaya: ${_formatPrice(p.price)}
🎁 Biaya Pasang: GRATIS (Rp 0)
⭐ Keunggulan:
${p.features.map((f) => '  • $f').join('\n')}
---------------------------------
Tertarik pasang? Hubungi saya (Sales Resmi XL SATU CILACAP).
''';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF002B66)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.tagColor),
                  ),
                  child: Text(
                    p.tag,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: p.tagColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              priceStr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF15A24)),
            ),
            const Divider(height: 16),
            ...p.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.tv, size: 14, color: Color(0xFF002B66)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share, size: 14),
                label: const Text('Salin Rincian Penawaran', style: TextStyle(fontSize: 11.5)),
                onPressed: () => _copyToClipboard(context, shareText, p.title),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoosterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.speed, color: Color(0xFF002B66), size: 20),
              SizedBox(width: 8),
              Text(
                'PAKET BOOSTER FWA (Dapat Dibeli di myXL)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF002B66)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• FWA Indoor (Berbasis Kuota): Menambah kuota internet langsung diakumulasi:\n   - 25 GB = Rp 25.000\n   - 50 GB = Rp 35.000\n   - 100 GB = Rp 50.000',
            style: TextStyle(fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 6),
          const Text(
            '• FWA Outdoor (Berbasis Kecepatan): Mengembalikan kecepatan internet menjadi normal (50 atau 100 Mbps) setelah FUP:\n   - 200 GB = Rp 50.000\n   - 450 GB = Rp 100.000',
            style: TextStyle(fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF002B66), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF002B66)),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFFF15A24), fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _OwsRow extends StatelessWidget {
  final String label;
  final String code;
  final String price;

  const _OwsRow(this.label, this.code, this.price);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 5,
            child: Text(
              code,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.blue.shade900,
                backgroundColor: Colors.blue.shade50,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              price,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF15A24)),
            ),
          ),
        ],
      ),
    );
  }
}
