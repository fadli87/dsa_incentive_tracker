import 'package:flutter/material.dart';

/// Model paket katalog — satu-satunya sumber kebenaran untuk seluruh aplikasi.
/// id stabil (slug), bukan indeks array, agar aman saat menambah/mengurangi paket.
@immutable
class CatalogPackage {
  final String id;        // slug unik, misal: 'fwa-hero-100-mbps'
  final int tab;          // tab index (1..5) di product_catalog_screen
  final String title;     // nama paket marketing
  final int speedMbps;    // kecepatan dasar (int, tanpa simbol "Mbps" atau "➔ 75 Mbps")
  final String speedLabel; // teks asli speed, misal: "100 Mbps", "50 Mbps ➔ 75 Mbps"
  final String type;      // 'ftth', 'fwaOutdoor', 'fwaIndoor', 'fmc', 'pxgy', 'comboTv'
  final int price;        // harga per bulan (Rp, tanpa PPN, integer)
  final String installation; // teks biaya instalasi, misal: 'GRATIS Biaya Instalasi (Rp 0)'
  final bool isFreeInstall; // apakah biaya install gratis
  final String? speedUpgrade; // teks upgrade, misal: 'Basic 100 Mbps ➔ Upgrade ke 250 Mbps (12 Bulan)'
  final List<String> features; // daftar fitur
  final String? hpQuotaGb; // kuota HP tambahan (hanya untuk paket FMC)

  const CatalogPackage({
    required this.id,
    required this.tab,
    required this.title,
    required this.speedMbps,
    required this.speedLabel,
    required this.type,
    required this.price,
    required this.installation,
    required this.isFreeInstall,
    required this.speedUpgrade,
    required this.features,
    this.hpQuotaGb,
  });

  @override
  String toString() => title;
}

class PackageCatalog {
  PackageCatalog._();
  static const List<CatalogPackage> all = packageCatalog;
}

const List<CatalogPackage> packageCatalog = [
  // --- TAB 1: INTERNET ONLY ---
  // Tab 1: Internet Only (index 1)
  CatalogPackage(
    id: 'tactical-ftth-20-mbps',
    tab: 1,
    title: 'Tactical FTTH 20 Mbps',
    speedMbps: 20,
    speedLabel: '20 Mbps',
    type: 'FTTH',
    price: 185000,
    installation: 'Biaya Instalasi Rp 100.000',
    isFreeInstall: false,
    speedUpgrade: null,
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
    price: 219000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: null,
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
    price: 229000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: 'Basic 100 Mbps ➔ Upgrade ke 250 Mbps (12 Bulan)',
    features: [
      'Kecepatan 250 Mbps True Unlimited',
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
    price: 239000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: 'Basic 200 Mbps ➔ Upgrade ke 300 Mbps (12 Bulan)',
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
    price: 299000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: 'Basic 300 Mbps ➔ Upgrade ke 400 Mbps (12 Bulan)',
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
    price: 399000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: null,
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
    price: 899000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: null,
    features: [
      'Kecepatan Maksimal 1 Gbps (1.000 Mbps)',
      'Tersedia di area XL Home Ownbuild & Linknet FTTH',
      'Pengalaman internet kelas enterprise di rumah',
    ],
  ),
  // --- TAB 2: FMC KUOTA HP (BUNDLING) ---
  // Tab 2: FMC Kuota HP (index 2)
  CatalogPackage(
    id: 'fmc-starter-20-mbps',
    tab: 2,
    title: 'FMC STARTER 20 Mbps + 8 GB',
    speedMbps: 20,
    speedLabel: '20 Mbps',
    type: 'FMC Bundling',
    price: 209000,
    installation: 'Biaya Instalasi Rp 100.000',
    isFreeInstall: false,
    speedUpgrade: null,
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
    price: 249000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: 'Bonus Speed Booster 6 bulan menjadi 75 Mbps!',
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
    price: 319000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: 'Bonus Speed Booster 6 bulan menjadi 150 Mbps!',
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
    price: 369000,
    installation: 'GRATIS Biaya Instalasi (Rp 0)',
    isFreeInstall: true,
    speedUpgrade: 'Bonus Speed Booster 6 bulan menjadi 200 Mbps!',
    features: [
      'Internet Rumah 150 Mbps (Boost ke 200 Mbps selama 6 bulan)',
      'Bonus Kuota HP Sekeluarga: 50 GB untuk 3 Anggota',
      'Hanya tambah Rp 70.000 untuk 50 GB kuota HP',
      'Gratis 2 Kartu SIM XL Prabayar dari teknisi',
    ],
    hpQuotaGb: '50',
  ),
  // --- TAB 3: ADVANCE PAYMENT ---
  // Tab 3: Advance Payment (index 3)
  CatalogPackage(
    id: 'advance-50-mbps-4bln',
    tab: 3,
    title: 'ADVANCE PAYMENT 50 Mbps (4 BULAN)',
    speedMbps: 50,
    speedLabel: '50 Mbps',
    type: 'Bayar 3 Dapat 4 Bulan',
    price: 162500, // Amortized
    installation: 'GRATIS Biaya Instalasi (PBI)',
    isFreeInstall: true,
    speedUpgrade: 'Bonus 3 Bulan Akses Vidio & Catchplay+',
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
    price: 197500, // Amortized
    installation: 'GRATIS Biaya Instalasi (PBI)',
    isFreeInstall: true,
    speedUpgrade: 'Bonus 3 Bulan Akses Vidio & Catchplay+',
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
    price: 216667, // Amortized
    installation: 'GRATIS Biaya Instalasi (PBI)',
    isFreeInstall: true,
    speedUpgrade: 'Bonus 3 Bulan Akses Vidio & Catchplay+',
    features: [
      'Bayar di muka 3 bulan hanya Rp 650.000 (Hemat 31%)',
      'Setara hanya Rp 216.667 / bulan untuk 100 Mbps',
      'Termasuk Free 3 Bulan Vidio Lite & Catchplay+',
      'Skema Pay Before Installation (PBI)',
    ],
  ),
  // --- TAB 4: COMBO TV ---
  // Tab 4: Combo TV (index 4) — data awal, bisa diperluas
  // (untuk sekarang Tab 4 diisi placeholder minimal agar kode compile)
  CatalogPackage(
    id: 'combo-joy-value-100-mbps',
    tab: 4,
    title: 'COMBO JOY VALUE 100 Mbps',
    speedMbps: 100,
    speedLabel: '100 Mbps',
    type: 'Combo Internet + TV',
    price: 0, // akan dilengkapi nanti
    installation: '',
    isFreeInstall: true,
    speedUpgrade: null,
    features: [],
  ),
];