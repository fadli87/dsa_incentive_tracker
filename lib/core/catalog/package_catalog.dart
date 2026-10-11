import 'package:flutter/material.dart';

/// Model paket katalog — satu-satunya sumber kebenaran untuk seluruh aplikasi.
/// id stabil (slug), bukan indeks array, agar aman saat menambah/mengurangi paket.
@immutable
class CatalogPackage {
  final String id; // slug unik, misal: 'fwa-hero-100-mbps'
  final int tab; // tab index (1..4) di product_catalog_screen
  final String title; // nama paket marketing
  final int speedMbps; // kecepatan dasar (int, tanpa simbol "Mbps" atau "➔ 75 Mbps")
  final String speedLabel; // teks asli speed, misal: "100 Mbps", "50 Mbps ➔ 75 Mbps"
  final String type; // 'FTTH', 'FWA Outdoor', 'FWA Indoor', 'FMC Bundling', 'Bayar 3 Dapat 4 Bulan', 'Bayar 3 Bulan', 'Combo Internet + TV', 'Combo Internet + TV + OTT'
  final String tag; // label tag badge, misal: 'Paling Laris 🔥', 'Ekonomis'
  final Color tagColor; // warna tema tag badge
  final int price; // harga per bulan (Rp, tanpa PPN, integer)
  final String installation; // teks biaya instalasi, misal: 'GRATIS Biaya Instalasi (Rp 0)'
  final bool isFreeInstall; // apakah biaya install gratis
  final String? speedUpgrade; // teks upgrade/booster jika ada
  final List<String> features; // daftar fitur keunggulan
  final String? hpQuotaGb; // kuota HP tambahan (hanya untuk paket FMC)
  final int? totalAdvance; // total bayar di muka (khusus PXGY)
  final int? normalAdvance; // harga normal sebelum diskon (khusus PXGY)
  final String? recurring; // catatan tagihan setelah masa promo selesai

  const CatalogPackage({
    required this.id,
    required this.tab,
    required this.title,
    required this.speedMbps,
    required this.speedLabel,
    required this.type,
    required this.tag,
    required this.tagColor,
    required this.price,
    required this.installation,
    required this.isFreeInstall,
    this.speedUpgrade,
    required this.features,
    this.hpQuotaGb,
    this.totalAdvance,
    this.normalAdvance,
    this.recurring,
  });

  @override
  String toString() => title;
}

class PromoPay10Get12 {
  final String name;
  final String speed;
  final int totalPrice;
  final int normalPrice;
  final String equivalent;

  const PromoPay10Get12({
    required this.name,
    required this.speed,
    required this.totalPrice,
    required this.normalPrice,
    required this.equivalent,
  });
}

class PromoComboItem {
  final String name;
  final List<String> items;

  const PromoComboItem({
    required this.name,
    required this.items,
  });
}

class PackageCatalog {
  PackageCatalog._();

  static const List<CatalogPackage> all = _packages;

  static List<CatalogPackage> byTab(int tab) =>
      _packages.where((p) => p.tab == tab).toList();

  static List<CatalogPackage> getFtthPackages() =>
      _packages.where((p) => p.type.toLowerCase().contains('ftth')).toList();

  static List<CatalogPackage> getFwaPackages() =>
      _packages.where((p) => p.type.toLowerCase().contains('fwa')).toList();

  static CatalogPackage? findById(String id) {
    try {
      return _packages.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<CatalogPackage> search({
    String? query,
    String? type,
    int? maxPrice,
    int? minSpeed,
  }) {
    return _packages.where((p) {
      if (type != null && type.isNotEmpty) {
        final t = type.toLowerCase();
        if (t == 'fwa') {
          if (!p.type.toLowerCase().contains('fwa') &&
              !p.title.toLowerCase().contains('fwa')) {
            return false;
          }
        } else if (t == 'ftth' || t == 'fiber') {
          if (!p.type.toLowerCase().contains('ftth') &&
              !p.title.toLowerCase().contains('ftth')) {
            return false;
          }
        } else if (t == 'fmc') {
          if (!p.type.toLowerCase().contains('fmc') &&
              !p.title.toLowerCase().contains('fmc')) {
            return false;
          }
        } else if (t == 'pxgy' || t == 'advance') {
          if (p.tab != 3 && !p.type.toLowerCase().contains('bayar')) {
            return false;
          }
        } else if (t == 'combo' || t == 'tv') {
          if (p.tab != 4 && !p.type.toLowerCase().contains('combo')) {
            return false;
          }
        }
      }

      if (maxPrice != null && p.price > maxPrice) {
        return false;
      }

      if (minSpeed != null && p.speedMbps < minSpeed) {
        return false;
      }

      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final match = p.title.toLowerCase().contains(q) ||
            p.speedLabel.toLowerCase().contains(q) ||
            p.type.toLowerCase().contains(q) ||
            p.features.any((f) => f.toLowerCase().contains(q));
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  static const List<PromoPay10Get12> promosPay10Get12 = [
    PromoPay10Get12(
      name: 'PROMO PAY 10 GET 12 - BASIC SMART',
      speed: '50 Mbps (Booster 75 Mbps 6 bln) + 10 GB HP',
      totalPrice: 2490000,
      normalPrice: 2988000,
      equivalent: 'Setara Rp 207.500 / bulan (Hemat Rp 498.000)',
    ),
    PromoPay10Get12(
      name: 'PROMO PAY 10 GET 12 - BASIC FAMILY',
      speed: '100 Mbps (Booster 150 Mbps 6 bln) + 25 GB HP',
      totalPrice: 3190000,
      normalPrice: 3828000,
      equivalent: 'Setara Rp 265.833 / bulan (Hemat Rp 638.000)',
    ),
    PromoPay10Get12(
      name: 'PROMO PAY 10 GET 12 - BASIC SUPERUSER',
      speed: '150 Mbps (Booster 200 Mbps 6 bln) + 50 GB HP',
      totalPrice: 3690000,
      normalPrice: 4428000,
      equivalent: 'Setara Rp 307.500 / bulan (Hemat Rp 738.000)',
    ),
  ];

  static const List<PromoComboItem> promosCombo = [
    PromoComboItem(
      name: 'PROMO SILVER (Bayar 6 Dapat 8 Bulan)',
      items: [
        'Joy Value (100 Mbps): Rp 2.100.000 (Setara Rp 262.500 / bln)',
        'Joy Pro (150 Mbps): Rp 2.550.000 (Setara Rp 318.750 / bln)',
        'Joy Premium (200 Mbps): Rp 4.050.000 (Setara Rp 506.250 / bln)',
      ],
    ),
    PromoComboItem(
      name: 'PROMO GOLD (Bayar 9 Dapat 12 Bulan)',
      items: [
        'Joy Value (100 Mbps): Rp 3.150.000 (Setara Rp 262.500 / bln)',
        'Joy Pro (150 Mbps): Rp 3.850.000 (Setara Rp 320.833 / bln)',
        'Joy Premium (200 Mbps): Rp 6.000.000 (Setara Rp 500.000 / bln)',
      ],
    ),
  ];
}

const List<CatalogPackage> _packages = [
  // =============================================================
  // TAB 1: INTERNET ONLY
  // =============================================================
  CatalogPackage(
    id: 'tactical-ftth-20-mbps',
    tab: 1,
    title: 'Tactical FTTH 20 Mbps',
    speedMbps: 20,
    speedLabel: '20 Mbps',
    type: 'FTTH',
    tag: 'Ekonomis',
    tagColor: Colors.teal,
    speedUpgrade: null,
    price: 185000,
    installation: 'Biaya Instalasi Rp 100.000',
    isFreeInstall: false,
    features: [
      'Kecepatan 20 Mbps Unlimited',
      'Cocok untuk 1-3 perangkat ringan',
      'Khusus area tercover Fiber FTTH',
    ],
  ),
  CatalogPackage(
    id: 'fwa-hero-100-mbps',
    tab: 1,
    title: 'FWA Hero 100 Mbps',
    speedMbps: 100,
    speedLabel: '100 Mbps',
    type: 'FWA Outdoor',
    tag: 'FWA Unggulan',
    tagColor: Colors.purple,
    speedUpgrade: null,
    price: 219000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Kecepatan 100 Mbps (Unlimited with FUP 1.024 GB)',
      'Teknologi Wireless 5G+ Dedicated Outdoor CPE & Router',
      'Pilihan terbaik untuk area yang belum tercover kabel Fiber',
      'Instalasi dilakukan teknisi resmi ke rumah',
    ],
  ),
  CatalogPackage(
    id: 'ftth-hero-250-mbps',
    tab: 1,
    title: 'FTTH Hero 250 Mbps',
    speedMbps: 250,
    speedLabel: '250 Mbps',
    type: 'FTTH',
    tag: 'Paling Laris 🔥',
    tagColor: Color(0xFFF15A24),
    speedUpgrade: 'Basic 100 Mbps ➔ Upgrade ke 250 Mbps (12 Bulan)',
    price: 229000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Kecepatan Super 250 Mbps True Unlimited',
      'Benefit Speed Upgrade 12 Bulan (dapat diperpanjang)',
      'Hanya selisih Rp 10rb dari FWA untuk 2.5x lebih cepat!',
      'Cocok untuk streaming 4K, gaming keluarga & WFH',
    ],
  ),
  CatalogPackage(
    id: 'ftth-hero-300-mbps',
    tab: 1,
    title: 'FTTH Hero 300 Mbps',
    speedMbps: 300,
    speedLabel: '300 Mbps',
    type: 'FTTH',
    tag: 'Populer',
    tagColor: Color(0xFF002B66),
    speedUpgrade: 'Basic 200 Mbps ➔ Upgrade ke 300 Mbps (12 Bulan)',
    price: 239000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Kecepatan 300 Mbps Unlimited',
      'Hanya tambah Rp 10rb dari 250 Mbps dapat ekstra 50 Mbps!',
      'Stabil dengan latensi rendah untuk multi-user',
    ],
  ),
  CatalogPackage(
    id: 'ftth-hero-400-mbps',
    tab: 1,
    title: 'FTTH Hero 400 Mbps',
    speedMbps: 400,
    speedLabel: '400 Mbps',
    type: 'FTTH',
    tag: 'Kecepatan Tinggi',
    tagColor: Colors.indigo,
    speedUpgrade: 'Basic 300 Mbps ➔ Upgrade ke 400 Mbps (12 Bulan)',
    price: 299000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Kecepatan 400 Mbps Unlimited',
      'Harga baru lebih hemat (sebelumnya Rp 300K+)',
      'Optimal untuk smart home, content creator & kantor mini',
    ],
  ),
  CatalogPackage(
    id: 'ftth-ultra-high-500-mbps',
    tab: 1,
    title: 'FTTH Ultra High Speed 500 Mbps',
    speedMbps: 500,
    speedLabel: '500 Mbps',
    type: 'FTTH',
    tag: 'Ultra Speed',
    tagColor: Colors.blueGrey,
    speedUpgrade: null,
    price: 399000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Kecepatan 500 Mbps murni tanpa upgrade (sebelumnya 500K)',
      'Download & upload file besar super cepat tanpa buffer',
    ],
  ),
  CatalogPackage(
    id: 'ftth-ultra-high-1-gbps',
    tab: 1,
    title: 'FTTH Ultra High Speed 1 Gbps',
    speedMbps: 1000,
    speedLabel: '1 Gbps (1000 Mbps)',
    type: 'FTTH',
    tag: 'Flagship Maximum',
    tagColor: Color(0xFFE65100),
    speedUpgrade: null,
    price: 899000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Kecepatan Maksimal 1 Gbps (1.000 Mbps)',
      'Tersedia di area XL Home Ownbuild & Linknet FTTH',
      'Pengalaman internet kelas enterprise di rumah',
    ],
  ),

  // =============================================================
  // TAB 2: FMC KUOTA HP (BUNDLING)
  // =============================================================
  CatalogPackage(
    id: 'fmc-starter-20-mbps',
    tab: 2,
    title: 'FMC STARTER 20 Mbps + 8 GB',
    speedMbps: 20,
    speedLabel: '20 Mbps',
    type: 'FMC Bundling',
    tag: 'Pemula',
    tagColor: Colors.teal,
    speedUpgrade: null,
    price: 209000,
    installation: 'Biaya Instalasi Rp 100.000',
    isFreeInstall: false,
    features: [
      'Internet Rumah Speed up to 20 Mbps',
      'Bonus Kuota HP Sekeluarga: 8 GB untuk 2 Anggota',
      'Hanya tambah Rp 24.000 dari internet only',
      'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
    ],
    hpQuotaGb: '8',
  ),
  CatalogPackage(
    id: 'fmc-smart-50-mbps',
    tab: 2,
    title: 'FMC SMART 50 Mbps + 10 GB',
    speedMbps: 50,
    speedLabel: '50 Mbps ➔ 75 Mbps',
    type: 'FMC Bundling',
    tag: 'Rekomendasi Keluarga',
    tagColor: Color(0xFFF15A24),
    speedUpgrade: 'Bonus Speed Booster 6 bulan menjadi 75 Mbps!',
    price: 249000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Internet Rumah 50 Mbps (Boost ke 75 Mbps selama 6 bulan)',
      'Bonus Kuota HP Sekeluarga: 10 GB untuk 2 Anggota',
      'Hanya tambah Rp 20.000 dari paket reguler',
      'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
    ],
    hpQuotaGb: '10',
  ),
  CatalogPackage(
    id: 'fmc-family-100-mbps',
    tab: 2,
    title: 'FMC FAMILY 100 Mbps + 25 GB',
    speedMbps: 100,
    speedLabel: '100 Mbps ➔ 150 Mbps',
    type: 'FMC Bundling',
    tag: 'Paling Favorit',
    tagColor: Color(0xFF002B66),
    speedUpgrade: 'Bonus Speed Booster 6 bulan menjadi 150 Mbps!',
    price: 319000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Internet Rumah 100 Mbps (Boost ke 150 Mbps selama 6 bulan)',
      'Bonus Kuota HP Sekeluarga: 25 GB untuk 2 Anggota',
      'Hanya tambah Rp 40.000 untuk 25 GB kuota HP',
      'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
    ],
    hpQuotaGb: '25',
  ),
  CatalogPackage(
    id: 'fmc-superuser-150-mbps',
    tab: 2,
    title: 'FMC SUPERUSER 150 Mbps + 50 GB',
    speedMbps: 150,
    speedLabel: '150 Mbps ➔ 200 Mbps',
    type: 'FMC Bundling',
    tag: 'Heavy Users',
    tagColor: Colors.indigo,
    speedUpgrade: 'Bonus Speed Booster 6 bulan menjadi 200 Mbps!',
    price: 369000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    features: [
      'Internet Rumah 150 Mbps (Boost ke 200 Mbps selama 6 bulan)',
      'Bonus Kuota HP Sekeluarga: 50 GB untuk 3 Anggota',
      'Hanya tambah Rp 70.000 untuk 50 GB kuota HP',
      'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
    ],
    hpQuotaGb: '50',
  ),

  // =============================================================
  // TAB 3: ADVANCE PAYMENT (PXGY)
  // =============================================================
  CatalogPackage(
    id: 'advance-50-mbps-4bln',
    tab: 3,
    title: 'ADVANCE PAYMENT 50 Mbps (4 BULAN)',
    speedMbps: 50,
    speedLabel: '50 Mbps',
    type: 'Bayar 3 Dapat 4 Bulan',
    tag: 'Hemat 40% ⚡',
    tagColor: Color(0xFF2E7D32),
    speedUpgrade: 'Bonus 3 Bulan Akses Vidio & Catchplay+',
    price: 162500, // Amortized
    totalAdvance: 650000,
    normalAdvance: 1085000,
    recurring: 'Tagihan normal bln ke-5: Rp 199.000/bln',
    installation: 'GRATIS Biaya Instalasi (PBI)',
    isFreeInstall: true,
    features: [
      'Bayar di muka 4 bulan hanya Rp 650.000 (Hemat 40%)',
      'Setara hanya Rp 162.500 / bulan',
      'Termasuk Free 3 Bulan Vidio Lite & Catchplay+',
      'Skema Pay Before Installation (PBI)',
    ],
  ),
  CatalogPackage(
    id: 'advance-100-mbps-4bln',
    tab: 3,
    title: 'ADVANCE PAYMENT 100 Mbps (4 BULAN)',
    speedMbps: 100,
    speedLabel: '100 Mbps',
    type: 'Bayar 3 Dapat 4 Bulan',
    tag: 'Hemat 32% 🚀',
    tagColor: Color(0xFFF15A24),
    speedUpgrade: 'Bonus 3 Bulan Akses Vidio & Catchplay+',
    price: 197500, // Amortized
    totalAdvance: 790000,
    normalAdvance: 1161000,
    recurring: 'Tagihan normal bln ke-5: Rp 219.000/bln',
    installation: 'GRATIS Biaya Instalasi (PBI)',
    isFreeInstall: true,
    features: [
      'Bayar di muka 4 bulan hanya Rp 790.000 (Hemat 32%)',
      'Setara hanya Rp 197.500 / bulan untuk 100 Mbps!',
      'Termasuk Free 3 Bulan Vidio Lite & Catchplay+',
      'Skema Pay Before Installation (PBI)',
    ],
  ),
  CatalogPackage(
    id: 'advance-100-mbps-3bln',
    tab: 3,
    title: 'ADVANCE PAYMENT 100 Mbps (3 BULAN)',
    speedMbps: 100,
    speedLabel: '100 Mbps',
    type: 'Bayar 3 Bulan',
    tag: 'Hemat 31%',
    tagColor: Color(0xFF002B66),
    speedUpgrade: 'Bonus 3 Bulan Akses Vidio & Catchplay+',
    price: 216667, // Amortized
    totalAdvance: 650000,
    normalAdvance: 942000,
    recurring: 'Tagihan normal bln ke-4: Rp 219.000/bln',
    installation: 'GRATIS Biaya Instalasi (PBI)',
    isFreeInstall: true,
    features: [
      'Bayar di muka 3 bulan hanya Rp 650.000 (Hemat 31%)',
      'Setara hanya Rp 216.667 / bulan untuk 100 Mbps',
      'Termasuk Free 3 Bulan Vidio Lite & Catchplay+',
      'Skema Pay Before Installation (PBI)',
    ],
  ),

  // =============================================================
  // TAB 4: COMBO INTERNET + TV (FIRSTMEDIA FOOTPRINT)
  // =============================================================
  CatalogPackage(
    id: 'combo-joy-value-100-mbps',
    tab: 4,
    title: 'COMBO JOY VALUE 100 Mbps',
    speedMbps: 100,
    speedLabel: '100 Mbps',
    type: 'Combo Internet + TV',
    tag: 'Starter TV',
    tagColor: Colors.teal,
    price: 350000,
    installation: 'Biaya Instalasi Rp 0,-',
    isFreeInstall: true,
    features: [
      'Internet Super Cepat 100 Mbps',
      '107 TV Channel Pilihan Keluarga',
      'Bonus Kuota HP Sekeluarga: 25 GB untuk 2 Member',
      'Gratis 2 SIM Card XL Prabayar dari teknisi',
      'Biaya Instalasi Rp 0,-',
    ],
  ),
  CatalogPackage(
    id: 'combo-joy-pro-150-mbps',
    tab: 4,
    title: 'COMBO JOY PRO 150 Mbps',
    speedMbps: 150,
    speedLabel: '150 Mbps',
    type: 'Combo Internet + TV',
    tag: 'Best Value',
    tagColor: Color(0xFFF15A24),
    price: 425000,
    installation: 'Biaya Instalasi Rp 0,-',
    isFreeInstall: true,
    features: [
      'Internet Super Cepat 150 Mbps',
      '107 TV Channel Pilihan Keluarga',
      'Bonus Kuota HP Sekeluarga: 50 GB untuk 3 Member',
      'Gratis 2 SIM Card XL Prabayar dari teknisi',
      'Biaya Instalasi Rp 0,-',
    ],
  ),
  CatalogPackage(
    id: 'combo-joy-premium-200-mbps',
    tab: 4,
    title: 'COMBO JOY PREMIUM 200 Mbps',
    speedMbps: 200,
    speedLabel: '200 Mbps',
    type: 'Combo Internet + TV',
    tag: 'Channel Lengkap',
    tagColor: Color(0xFF002B66),
    price: 675000,
    installation: 'Biaya Instalasi Rp 0,-',
    isFreeInstall: true,
    features: [
      'Internet Super Cepat 200 Mbps',
      '167 TV Channel Lengkap & Premium',
      'Bonus Kuota HP Sekeluarga: 50 GB untuk 3 Member',
      'Gratis 2 SIM Card XL Prabayar dari teknisi',
      'Biaya Instalasi Rp 0,-',
    ],
  ),
  CatalogPackage(
    id: 'combo-star-value-300-mbps',
    tab: 4,
    title: 'COMBO STAR VALUE 300 Mbps',
    speedMbps: 300,
    speedLabel: '300 Mbps',
    type: 'Combo Internet + TV + OTT',
    tag: 'Viu + Catchplay+',
    tagColor: Colors.deepPurple,
    price: 985000,
    installation: 'Biaya Instalasi Rp 0,-',
    isFreeInstall: true,
    features: [
      'Internet Ekstra Cepat 300 Mbps',
      '187 TV Channel',
      'Langganan Catchplay+ & Viu Termasuk',
      'Bonus Kuota HP Sekeluarga: 100 GB untuk 4 Member',
      'Biaya Instalasi Rp 0,-',
    ],
  ),
  CatalogPackage(
    id: 'combo-star-pro-500-mbps',
    tab: 4,
    title: 'COMBO STAR PRO 500 Mbps',
    speedMbps: 500,
    speedLabel: '500 Mbps',
    type: 'Combo Internet + TV + OTT',
    tag: 'High Tier',
    tagColor: Colors.blueGrey,
    price: 1850000,
    installation: 'Biaya Instalasi Rp 0,-',
    isFreeInstall: true,
    features: [
      'Internet Ultra Cepat 500 Mbps',
      '189 TV Channel',
      'Langganan Catchplay+ & Viu Termasuk',
      'Bonus Kuota HP Sekeluarga: 100 GB untuk 4 Member',
      'Biaya Instalasi Rp 0,-',
    ],
  ),
  CatalogPackage(
    id: 'combo-star-premium-1-gbps',
    tab: 4,
    title: 'COMBO STAR PREMIUM 1 Gbps',
    speedMbps: 1000,
    speedLabel: '1 Gbps',
    type: 'Combo Internet + TV + OTT',
    tag: 'Ultimate Flagship',
    tagColor: Color(0xFFE65100),
    price: 4500000,
    installation: 'Biaya Instalasi Rp 0,-',
    isFreeInstall: true,
    features: [
      'Internet Maksimal 1 Gbps (1000 Mbps)',
      '196 TV Channel Super Lengkap',
      'Catchplay+ & Viu & Lionsgate Play Termasuk',
      'Bonus Kuota HP Sekeluarga: 100 GB untuk 4 Member',
      'Biaya Instalasi Rp 0,-',
    ],
  ),
];