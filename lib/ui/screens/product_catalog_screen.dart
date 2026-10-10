import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
    final packages = [
      {
        'title': 'Tactical FTTH 20 Mbps',
        'speed': '20 Mbps',
        'type': 'FTTH',
        'tag': 'Ekonomis',
        'tagColor': Colors.teal,
        'speedUpgrade': null,
        'price': 185000,
        'installation': 'Biaya Instalasi Rp 100.000',
        'isFreeInstall': false,
        'features': [
          'Kecepatan 20 Mbps Unlimited',
          'Cocok untuk 1-3 perangkat ringan',
          'Khusus area tercover Fiber FTTH',
        ],
      },
      {
        'title': 'FWA Hero 100 Mbps',
        'speed': '100 Mbps',
        'type': 'FWA Outdoor',
        'tag': 'FWA Unggulan',
        'tagColor': Colors.purple,
        'speedUpgrade': null,
        'price': 219000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Kecepatan 100 Mbps (Unlimited with FUP 1.024 GB)',
          'Teknologi Wireless 5G+ Dedicated Outdoor CPE & Router',
          'Pilihan terbaik untuk area yang belum tercover kabel Fiber',
          'Instalasi dilakukan teknisi resmi ke rumah',
        ],
      },
      {
        'title': 'FTTH Hero 250 Mbps',
        'speed': '250 Mbps',
        'type': 'FTTH',
        'tag': 'Paling Laris 🔥',
        'tagColor': const Color(0xFFF15A24),
        'speedUpgrade': 'Basic 100 Mbps ➔ Upgrade ke 250 Mbps (12 Bulan)',
        'price': 229000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Kecepatan Super 250 Mbps True Unlimited',
          'Benefit Speed Upgrade 12 Bulan (dapat diperpanjang)',
          'Hanya selisih Rp 10rb dari FWA untuk 2.5x lebih cepat!',
          'Cocok untuk streaming 4K, gaming keluarga & WFH',
        ],
      },
      {
        'title': 'FTTH Hero 300 Mbps',
        'speed': '300 Mbps',
        'type': 'FTTH',
        'tag': 'Populer',
        'tagColor': const Color(0xFF002B66),
        'speedUpgrade': 'Basic 200 Mbps ➔ Upgrade ke 300 Mbps (12 Bulan)',
        'price': 239000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Kecepatan 300 Mbps Unlimited',
          'Hanya tambah Rp 10rb dari 250 Mbps dapat ekstra 50 Mbps!',
          'Stabil dengan latensi rendah untuk multi-user',
        ],
      },
      {
        'title': 'FTTH Hero 400 Mbps',
        'speed': '400 Mbps',
        'type': 'FTTH',
        'tag': 'Kecepatan Tinggi',
        'tagColor': Colors.indigo,
        'speedUpgrade': 'Basic 300 Mbps ➔ Upgrade ke 400 Mbps (12 Bulan)',
        'price': 299000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Kecepatan 400 Mbps Unlimited',
          'Harga baru lebih hemat (sebelumnya Rp 300K+)',
          'Optimal untuk smart home, content creator & kantor mini',
        ],
      },
      {
        'title': 'FTTH Ultra High Speed 500 Mbps',
        'speed': '500 Mbps',
        'type': 'FTTH',
        'tag': 'Ultra Speed',
        'tagColor': Colors.blueGrey,
        'speedUpgrade': null,
        'price': 399000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Kecepatan 500 Mbps murni tanpa upgrade (sebelumnya 500K)',
          'Download & upload file besar super cepat tanpa buffer',
        ],
      },
      {
        'title': 'FTTH Ultra High Speed 1 Gbps',
        'speed': '1 Gbps (1000 Mbps)',
        'type': 'FTTH',
        'tag': 'Flagship Maximum',
        'tagColor': Colors.amber.shade900,
        'speedUpgrade': null,
        'price': 899000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Kecepatan Maksimal 1 Gbps (1.000 Mbps)',
          'Tersedia di area XL Home Ownbuild & Linknet FTTH',
          'Pengalaman internet kelas enterprise di rumah',
        ],
      },
    ];

    final filtered = packages.where((p) {
      if (_searchQuery.isEmpty) return true;
      final text = '${p['title']} ${p['speed']} ${p['type']}'.toLowerCase();
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
    final packages = [
      {
        'title': 'FMC STARTER 20 Mbps + 8 GB',
        'speed': '20 Mbps',
        'type': 'FMC Bundling',
        'tag': 'Pemula',
        'tagColor': Colors.teal,
        'speedUpgrade': null,
        'price': 209000,
        'installation': 'Biaya Instalasi Rp 100.000',
        'isFreeInstall': false,
        'features': [
          'Internet Rumah Speed up to 20 Mbps',
          'Bonus Kuota HP Sekeluarga: 8 GB untuk 2 Anggota',
          'Hanya tambah Rp 24.000 dari internet only',
          'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
        ],
      },
      {
        'title': 'FMC SMART 50 Mbps + 10 GB',
        'speed': '50 Mbps ➔ 75 Mbps',
        'type': 'FMC Bundling',
        'tag': 'Rekomendasi Keluarga',
        'tagColor': const Color(0xFFF15A24),
        'speedUpgrade': 'Bonus Speed Booster 6 bulan menjadi 75 Mbps!',
        'price': 249000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Internet Rumah 50 Mbps (Boost ke 75 Mbps selama 6 bulan)',
          'Bonus Kuota HP Sekeluarga: 10 GB untuk 2 Anggota',
          'Hanya tambah Rp 20.000 dari paket reguler',
          'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
        ],
      },
      {
        'title': 'FMC FAMILY 100 Mbps + 25 GB',
        'speed': '100 Mbps ➔ 150 Mbps',
        'type': 'FMC Bundling',
        'tag': 'Paling Favorit',
        'tagColor': const Color(0xFF002B66),
        'speedUpgrade': 'Bonus Speed Booster 6 bulan menjadi 150 Mbps!',
        'price': 319000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Internet Rumah 100 Mbps (Boost ke 150 Mbps selama 6 bulan)',
          'Bonus Kuota HP Sekeluarga: 25 GB untuk 2 Anggota',
          'Hanya tambah Rp 40.000 untuk 25 GB kuota HP',
          'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
        ],
      },
      {
        'title': 'FMC SUPERUSER 150 Mbps + 50 GB',
        'speed': '150 Mbps ➔ 200 Mbps',
        'type': 'FMC Bundling',
        'tag': 'Heavy Users',
        'tagColor': Colors.indigo,
        'speedUpgrade': 'Bonus Speed Booster 6 bulan menjadi 200 Mbps!',
        'price': 369000,
        'installation': 'GRATIS Biaya Instalasi (Rp 0)',
        'isFreeInstall': true,
        'features': [
          'Internet Rumah 150 Mbps (Boost ke 200 Mbps selama 6 bulan)',
          'Bonus Kuota HP Sekeluarga: 50 GB untuk 3 Anggota',
          'Hanya tambah Rp 70.000 untuk 50 GB kuota HP',
          'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
        ],
      },
    ];

    final promosPay10Get12 = [
      {
        'name': 'PROMO PAY 10 GET 12 - BASIC SMART',
        'speed': '50 Mbps (Booster 75 Mbps 6 bln) + 10 GB HP',
        'totalPrice': 2490000,
        'normalPrice': 2988000,
        'equivalent': 'Setara Rp 207.500 / bulan (Hemat Rp 498.000)',
      },
      {
        'name': 'PROMO PAY 10 GET 12 - BASIC FAMILY',
        'speed': '100 Mbps (Booster 150 Mbps 6 bln) + 25 GB HP',
        'totalPrice': 3190000,
        'normalPrice': 3828000,
        'equivalent': 'Setara Rp 265.833 / bulan (Hemat Rp 638.000)',
      },
      {
        'name': 'PROMO PAY 10 GET 12 - BASIC SUPERUSER',
        'speed': '150 Mbps (Booster 200 Mbps 6 bln) + 50 GB HP',
        'totalPrice': 3690000,
        'normalPrice': 4428000,
        'equivalent': 'Setara Rp 307.500 / bulan (Hemat Rp 738.000)',
      },
    ];

    final filtered = packages.where((p) {
      if (_searchQuery.isEmpty) return true;
      final text = '${p['title']} ${p['speed']} ${p['type']}'.toLowerCase();
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
                            promo['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            promo['speed'] as String,
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
                                    currencyFmt.format(promo['totalPrice']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFFF15A24),
                                    ),
                                  ),
                                  Text(
                                    'Normal: ${currencyFmt.format(promo['normalPrice'])}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade500,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                promo['equivalent'] as String,
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
    final packages = [
      {
        'title': 'ADVANCE PAYMENT 50 Mbps (4 BULAN)',
        'speed': '50 Mbps',
        'type': 'Bayar 3 Dapat 4 Bulan',
        'tag': 'Hemat 40% ⚡',
        'tagColor': Colors.green.shade800,
        'speedUpgrade': 'Bonus 3 Bulan Akses Vidio & Catchplay+',
        'price': 162500, // Amortized
        'totalAdvance': 650000,
        'normalAdvance': 1085000,
        'recurring': 'Tagihan normal bln ke-5: Rp 199.000/bln',
        'installation': 'GRATIS Biaya Instalasi (PBI)',
        'isFreeInstall': true,
        'features': [
          'Bayar di muka 4 bulan hanya Rp 650.000 (Hemat 40%)',
          'Setara hanya Rp 162.500 / bulan',
          'Termasuk Free 3 Bulan Vidio Lite & Catchplay+',
          'Skema Pay Before Installation (PBI)',
        ],
      },
      {
        'title': 'ADVANCE PAYMENT 100 Mbps (4 BULAN)',
        'speed': '100 Mbps',
        'type': 'Bayar 3 Dapat 4 Bulan',
        'tag': 'Hemat 32% 🚀',
        'tagColor': const Color(0xFFF15A24),
        'speedUpgrade': 'Bonus 3 Bulan Akses Vidio & Catchplay+',
        'price': 197500, // Amortized
        'totalAdvance': 790000,
        'normalAdvance': 1161000,
        'recurring': 'Tagihan normal bln ke-5: Rp 219.000/bln',
        'installation': 'GRATIS Biaya Instalasi (PBI)',
        'isFreeInstall': true,
        'features': [
          'Bayar di muka 4 bulan hanya Rp 790.000 (Hemat 32%)',
          'Setara hanya Rp 197.500 / bulan untuk 100 Mbps!',
          'Termasuk Free 3 Bulan Vidio Lite & Catchplay+',
          'Skema Pay Before Installation (PBI)',
        ],
      },
      {
        'title': 'ADVANCE PAYMENT 100 Mbps (3 BULAN)',
        'speed': '100 Mbps',
        'type': 'Bayar 3 Bulan',
        'tag': 'Hemat 31%',
        'tagColor': const Color(0xFF002B66),
        'speedUpgrade': 'Bonus 3 Bulan Akses Vidio & Catchplay+',
        'price': 216667, // Amortized
        'totalAdvance': 650000,
        'normalAdvance': 942000,
        'recurring': 'Tagihan normal bln ke-4: Rp 219.000/bln',
        'installation': 'GRATIS Biaya Instalasi (PBI)',
        'isFreeInstall': true,
        'features': [
          'Bayar di muka 3 bulan hanya Rp 650.000 (Hemat 31%)',
          'Setara hanya Rp 216.667 / bulan untuk 100 Mbps',
          'Termasuk Free 3 Bulan Vidio Lite & Catchplay+',
          'Skema Pay Before Installation (PBI)',
        ],
      },
    ];

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
    final packages = [
      {
        'title': 'COMBO JOY VALUE 100 Mbps',
        'speed': '100 Mbps',
        'type': 'Combo Internet + TV',
        'tag': 'Starter TV',
        'tagColor': Colors.teal,
        'price': 350000,
        'features': [
          'Internet Super Cepat 100 Mbps',
          '107 TV Channel Pilihan Keluarga',
          'Bonus Kuota HP Sekeluarga: 25 GB untuk 2 Member',
          'Gratis 2 SIM Card XL Prabayar dari teknisi',
          'Biaya Instalasi Rp 0,-',
        ],
      },
      {
        'title': 'COMBO JOY PRO 150 Mbps',
        'speed': '150 Mbps',
        'type': 'Combo Internet + TV',
        'tag': 'Best Value',
        'tagColor': const Color(0xFFF15A24),
        'price': 425000,
        'features': [
          'Internet Super Cepat 150 Mbps',
          '107 TV Channel Pilihan Keluarga',
          'Bonus Kuota HP Sekeluarga: 50 GB untuk 3 Member',
          'Gratis 2 SIM Card XL Prabayar dari teknisi',
          'Biaya Instalasi Rp 0,-',
        ],
      },
      {
        'title': 'COMBO JOY PREMIUM 200 Mbps',
        'speed': '200 Mbps',
        'type': 'Combo Internet + TV',
        'tag': 'Channel Lengkap',
        'tagColor': const Color(0xFF002B66),
        'price': 675000,
        'features': [
          'Internet Super Cepat 200 Mbps',
          '167 TV Channel Lengkap & Premium',
          'Bonus Kuota HP Sekeluarga: 50 GB untuk 3 Member',
          'Gratis 2 SIM Card XL Prabayar dari teknisi',
          'Biaya Instalasi Rp 0,-',
        ],
      },
      {
        'title': 'COMBO STAR VALUE 300 Mbps',
        'speed': '300 Mbps',
        'type': 'Combo Internet + TV + OTT',
        'tag': 'Viu + Catchplay+',
        'tagColor': Colors.deepPurple,
        'price': 985000,
        'features': [
          'Internet Ekstra Cepat 300 Mbps',
          '187 TV Channel',
          'Langganan Catchplay+ & Viu Termasuk',
          'Bonus Kuota HP Sekeluarga: 100 GB untuk 4 Member',
          'Biaya Instalasi Rp 0,-',
        ],
      },
      {
        'title': 'COMBO STAR PRO 500 Mbps',
        'speed': '500 Mbps',
        'type': 'Combo Internet + TV + OTT',
        'tag': 'High Tier',
        'tagColor': Colors.blueGrey,
        'price': 1850000,
        'features': [
          'Internet Ultra Cepat 500 Mbps',
          '189 TV Channel',
          'Langganan Catchplay+ & Viu Termasuk',
          'Bonus Kuota HP Sekeluarga: 100 GB untuk 4 Member',
          'Biaya Instalasi Rp 0,-',
        ],
      },
      {
        'title': 'COMBO STAR PREMIUM 1 Gbps',
        'speed': '1 Gbps',
        'type': 'Combo Internet + TV + OTT',
        'tag': 'Ultimate Flagship',
        'tagColor': Colors.amber.shade900,
        'price': 4500000,
        'features': [
          'Internet Maksimal 1 Gbps (1000 Mbps)',
          '196 TV Channel Super Lengkap',
          'Catchplay+ & Viu & Lionsgate Play Termasuk',
          'Bonus Kuota HP Sekeluarga: 100 GB untuk 4 Member',
          'Biaya Instalasi Rp 0,-',
        ],
      },
    ];

    final promos = [
      {
        'name': 'PROMO SILVER (Bayar 6 Dapat 8 Bulan)',
        'items': [
          'Joy Value (100 Mbps): Rp 2.100.000 (Setara Rp 262.500 / bln)',
          'Joy Pro (150 Mbps): Rp 2.550.000 (Setara Rp 318.750 / bln)',
          'Joy Premium (200 Mbps): Rp 4.050.000 (Setara Rp 506.250 / bln)',
        ],
      },
      {
        'name': 'PROMO GOLD (Bayar 9 Dapat 12 Bulan)',
        'items': [
          'Joy Value (100 Mbps): Rp 3.150.000 (Setara Rp 262.500 / bln)',
          'Joy Pro (150 Mbps): Rp 3.850.000 (Setara Rp 320.833 / bln)',
          'Joy Premium (200 Mbps): Rp 6.000.000 (Setara Rp 500.000 / bln)',
        ],
      },
    ];

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
                        pr['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF002B66)),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  ...(pr['items'] as List<String>).map((it) => Padding(
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

  Widget _buildPackageCard(Map<String, dynamic> p) {
    final priceStr = _formatPrice(p['price'] as int);
    final isFree = p['isFreeInstall'] as bool;

    final shareText = '''
*PENAWARAN PAKET XL SATU*
---------------------------------
📦 Paket: ${p['title']}
🚀 Kecepatan: ${p['speed']}
💰 Biaya: ${_formatPrice(p['price'] as int)}
🎁 Instalasi: ${p['installation']}
${p['speedUpgrade'] != null ? '⚡ Benefit: ${p['speedUpgrade']}\n' : ''}⭐ Keunggulan:
${(p['features'] as List<String>).map((f) => '  • $f').join('\n')}
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
                    p['title'] as String,
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
                    color: (p['tagColor'] as Color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p['tagColor'] as Color),
                  ),
                  child: Text(
                    p['tag'] as String,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: p['tagColor'] as Color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Speed Upgrade Badge if available
            if (p['speedUpgrade'] != null)
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
                        p['speedUpgrade'] as String,
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
                  p['installation'] as String,
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
            ...(p['features'] as List<String>).map((f) => Padding(
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
                onPressed: () => _copyToClipboard(context, shareText, p['title'] as String),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvanceCard(Map<String, dynamic> p) {
    final shareText = '''
*PROMO BAYAR DI MUKA XL SATU (PXGY)*
---------------------------------
📦 Paket: ${p['title']}
🚀 Kecepatan: ${p['speed']}
💵 Total Bayar: ${currencyFmt.format(p['totalAdvance'])} (Hemat!)
💰 Setara: ${currencyFmt.format(p['price'])} / bulan
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
                    p['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF002B66)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (p['tagColor'] as Color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p['tagColor'] as Color),
                  ),
                  child: Text(
                    p['tag'] as String,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: p['tagColor'] as Color),
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
                        currencyFmt.format(p['totalAdvance']),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      Text(
                        'Normal: ${currencyFmt.format(p['normalAdvance'])}',
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
                          currencyFmt.format(p['price']),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF15A24)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(p['recurring'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const Divider(height: 16),

            ...(p['features'] as List<String>).map((f) => Padding(
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
                onPressed: () => _copyToClipboard(context, shareText, p['title'] as String),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboCard(Map<String, dynamic> p) {
    final priceStr = _formatPrice(p['price'] as int);

    final shareText = '''
*PAKET COMBO XL SATU (INTERNET + TV)*
---------------------------------
📦 Paket: ${p['title']}
🚀 Kecepatan: ${p['speed']}
💰 Biaya: ${_formatPrice(p['price'] as int)}
🎁 Biaya Pasang: GRATIS (Rp 0)
⭐ Keunggulan:
${(p['features'] as List<String>).map((f) => '  • $f').join('\n')}
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
                    p['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF002B66)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (p['tagColor'] as Color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p['tagColor'] as Color),
                  ),
                  child: Text(
                    p['tag'] as String,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: p['tagColor'] as Color),
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
            ...(p['features'] as List<String>).map((f) => Padding(
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
                onPressed: () => _copyToClipboard(context, shareText, p['title'] as String),
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
