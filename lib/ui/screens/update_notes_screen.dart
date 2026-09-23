import 'package:flutter/material.dart';

class UpdateNotesScreen extends StatelessWidget {
  const UpdateNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Catatan Update'),
        centerTitle: true,
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVersionCard(
              version: 'Ver.1.0.5',
              date: 'September 2026',
              isLatest: true,
              changes: [
                'Penambahan Screen Baru: Katalog Paket Jualan Sales XL Satu (Launch 19 September 2026) pada menu navigasi utama.',
                'Katalog 5 Kategori Tab: Internet Only (FTTH & FWA), FMC Kuota HP Sekeluarga, Advance Pay (PXGY Bayar 3 Dapat 4), Combo TV (FM Footprint), dan S&K + Kode OWS.',
                'Fitur Toggle Simulasi PPN 11% untuk menghitung harga bersih tagihan bulanan pelanggan secara instan.',
                'Fitur Pencarian Paket Cepat berdasarkan nama, kecepatan (Mbps), atau tipe jaringan.',
                'Tombol "Salin Rincian Penawaran (WhatsApp)" untuk menyalin format pesan promosi rapi siap kirim ke calon pelanggan.',
                'Panduan aktivasi OTT Vidio & Catchplay+ serta tabel referensi kode bundling OWS untuk sales.',
              ],
            ),
            const SizedBox(height: 16),
            _buildVersionCard(
              version: 'Ver.1.0.4',
              date: 'September 2026',
              isLatest: false,
              changes: [
                'Penambahan titik Pin Lokasi & Peta Interaktif (OpenStreetMap & GPS) pada Data SA Pelanggan tanpa API key berbayar.',
                'Fitur Navigasi Cepat: Dialog pratinjau peta dalam aplikasi dan integrasi buka di Google Maps eksternal.',
                'Penambahan kontak No. HP Utama & HP Alternatif pada pelanggan dengan tombol panggil telepon dan WhatsApp langsung.',
                'Penyimpanan database SA 100% offline lokal dengan penghapusan nomor KTP demi privasi dan keamanan data.',
                'Penambahan modul Panduan Skema Supervisor (SPV) September 2026 (Basic Fee, Bonus KPI, Survival Rate, Graduation Bonus, Monthly Performance Bonus).',
                'Screen baru Info Pengguna (Nama Sales & Sales Code) dengan Virtual ID Card dan penyimpanan lokal persisten.',
                'Penyematan identitas resmi watermark "XL SATU CILACAP · TSC PIPIN" pada antarmuka aplikasi.',
              ],
            ),
            const SizedBox(height: 16),
            _buildVersionCard(
              version: 'Ver.1.0.3',
              date: 'September 2026',
              changes: [
                'Implementasi skema kalkulator SPV September 2026 (Basic Fee Rp 4.5jt, Bonus KPI, Survival, Graduation & Monthly Performance).',
                'Pembaruan fitur edit histori insentif dan sinkronisasi data.',
                'Penyempurnaan kalkulasi multiplier dan unit tests.',
              ],
            ),
            const SizedBox(height: 16),
            _buildVersionCard(
              version: 'Ver.1.0.2',
              date: 'September 2026',
              changes: [
                'Penambahan fitur Edit Histori Insentif.',
                'Perbaikan bug pada layar kalkulator.',
                'Penambahan label versi pada footer.',
              ],
            ),
            const SizedBox(height: 16),
            _buildVersionCard(
              version: 'Ver.1.0.1',
              date: 'September 2026',
              changes: [
                'Rilis awal aplikasi DSA Incentive Tracker.',
                'Fitur kalkulasi insentif otomatis berdasarkan skema D2D.',
                'Penyimpanan histori pencapaian lokal menggunakan SQLite.',
                'Dukungan lintas platform (Web dan Mobile).',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard({
    required String version,
    required String date,
    required List<String> changes,
    bool isLatest = false,
  }) {
    return Card(
      elevation: isLatest ? 3 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLatest
            ? const BorderSide(color: Color(0xFF002B66), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      version,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002B66),
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF002B66),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'TERBARU',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...changes.map((change) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFFF15A24),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          change,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
