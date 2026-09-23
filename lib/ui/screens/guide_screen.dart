import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'PANDUAN & SKEMA INSENTIF',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              "Skema Resmi XL SMART DSA D2D · Effective September 2026",
              style: TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
        children: [
          // Banner Pengenalan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF002B66), Color(0xFF005599)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF002B66).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lightbulb_outline,
                      color: Colors.amberAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'PANDUAN LENGKAP KALKULATOR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pelajari cara kerja perhitungan Basic Fee, Product Mix, Tiering Produktivitas, Booster, hingga Bonus Kuartalan.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Basic Fee Card
          _buildGuideCard(
            title: '1. Basic Fee (Gaji Pokok / Allowance)',
            icon: Icons.account_balance_outlined,
            accentColor: const Color(0xFF002B66),
            children: [
              _buildText(
                'Basic Fee adalah tunjangan bulanan yang diterima tenaga penjual berdasarkan level posisi posisi pada akhir bulan performance (latest position end of month):',
              ),
              const SizedBox(height: 8),
              _buildTierTable(
                headers: ['Posisi Sales', 'Nominal Bulanan', 'Keterangan'],
                rows: [
                  ['AE OJT', 'Rp 1.900.000', 'Masa On Job Training'],
                  ['AE PRO', 'Rp 2.600.000', 'Account Executive Professional'],
                  ['AE ELITE', 'Rp 2.773.184', 'Acuan UMK Kab. Cilacap'],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Product Mix Card
          _buildGuideCard(
            title: '2. Product Mix & Special PXGY',
            icon: Icons.inventory_2_outlined,
            accentColor: const Color(0xFF0077B6),
            children: [
              _buildText(
                'Berlaku untuk SEMUA level posisi (AE OJT, AE Pro, & AE Elite). Dihitung dari harga dasar paket (basic price) atau masa berlangganan Pay X Get Y (PXGY):',
              ),
              const SizedBox(height: 8),
              const Text(
                'A. Regular Plan (FTTH & FWA)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              _buildTierTable(
                headers: ['Plan Tiering / Paket', 'Insentif / SA'],
                rows: [
                  ['FTTH < Rp 229.000', 'Rp 0'],
                  ['FTTH Rp 229.000 – Rp 299.999', 'Rp 50.000'],
                  ['FTTH Rp 300.000 – Rp 399.999', 'Rp 100.000'],
                  ['FTTH Rp 400.000 – Rp 599.999', 'Rp 125.000'],
                  ['FTTH ≥ Rp 600.000', 'Rp 200.000'],
                  ['FWA Regular (≥ Rp 219.000)', 'Rp 50.000'],
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'B. Pay X Get Y (PXGY) — FTTH & FWA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              _buildTierTable(
                headers: ['Masa Paket (Tenure)', 'Product Mix', 'Special Inc.', 'Total / SA'],
                rows: [
                  ['3 – 5 Bulan', 'Rp 125.000', 'Rp 125.000', 'Rp 250.000'],
                  ['≥ 6 Bulan', 'Rp 150.000', 'Rp 150.000', 'Rp 300.000'],
                ],
              ),
              const SizedBox(height: 8),
              _buildAlertBox(
                'Catatan Penting PXGY: Special Incentive PXGY merupakan insentif tambahan langsung di luar Product Mix Base dan dibayarkan penuh per aktivasi.',
                Colors.blue.shade50,
                Colors.blue.shade900,
                Icons.info_outline,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Productivity Incentive (OJT vs Pro/Elite)
          _buildGuideCard(
            title: '3. Productivity Incentive (Perbedaan OJT vs Pro/Elite)',
            icon: Icons.trending_up,
            accentColor: const Color(0xFFF15A24),
            children: [
              _buildText(
                'Terdapat 2 skema yang sangat berbeda antara Account Executive OJT dengan AE Pro/Elite sesuai Guiding Principle Poin 6:',
              ),
              const SizedBox(height: 10),
              // Skema OJT
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A. SKEMA KHUSUS AE OJT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Color(0xFFB76E00),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildText(
                      '• Menggunakan tiering progresif khusus 1–10 SA.\n• TIDAK ada Multiplier Booster terhadap Product Mix.\n• Memiliki Lump Sum Bonus berdasarkan minimum capaian SA:',
                    ),
                    const SizedBox(height: 6),
                    _buildTierTable(
                      headers: ['Jenjang SA OJT', 'Rate Progresif / SA'],
                      rows: [
                        ['1 – 2 SA', 'Rp 80.000'],
                        ['3 – 4 SA', 'Rp 100.000'],
                        ['5 – 6 SA', 'Rp 130.000'],
                        ['7 – 9 SA', 'Rp 150.000'],
                        ['≥ 10 SA', 'Rp 200.000'],
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildTierTable(
                      headers: ['Min. Capaian SA', 'Lump Sum Bonus'],
                      rows: [
                        ['3 SA', 'Rp 325.000'],
                        ['7 SA', 'Rp 600.000'],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Skema Pro & Elite
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'B. SKEMA AE PRO & AE ELITE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Color(0xFF002B66),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildText(
                      '• Menggunakan jenjang tiering 1–6 SA hingga ≥50 SA.\n• Booster Multiplier dikalikan dengan Product Mix Base (tanpa special incentive).\n• Catatan Penting: Insentif Progresif SA akan HILANG jika perhitungan Multiplier sudah ada (capaian ≥ 7 SA). Jika aktivasi 1–6 SA (Multiplier belum ada), AE mendapatkan insentif Progresif SA (Rp 80.000 / SA).\n• Tidak memiliki Lump Sum Bonus OJT.',
                    ),
                    const SizedBox(height: 6),
                    _buildTierTable(
                      headers: ['Jenjang SA Pro/Elite', 'Rate Progresif / SA', 'Multiplier (Booster)'],
                      rows: [
                        ['1 – 6 SA', 'Rp 80.000', '0x (Dapat Progresif SA)'],
                        ['7 – 9 SA', 'Rp 150.000', '1.50x × PM Base (Progresif Hilang)'],
                        ['10 – 13 SA', 'Rp 175.000', '2.00x × PM Base (Progresif Hilang)'],
                        ['14 – 29 SA', 'Rp 200.000', '4.00x × PM Base (Progresif Hilang)'],
                        ['30 – 39 SA', 'Rp 225.000', '4.25x × PM Base (Progresif Hilang)'],
                        ['40 – 49 SA', 'Rp 250.000', '4.50x × PM Base (Progresif Hilang)'],
                        ['≥ 50 SA', 'Rp 275.000', '4.65x × PM Base (Progresif Hilang)'],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Exclusive Reward AE PRO
          _buildGuideCard(
            title: '4. Performance Bonus & Promosi (Khusus AE Pro)',
            icon: Icons.military_tech_outlined,
            accentColor: Colors.purple.shade700,
            children: [
              _buildText(
                'Diberikan khusus kepada AE Pro yang menunjukkan konsistensi kinerja tinggi:',
              ),
              const SizedBox(height: 8),
              _buildTierTable(
                headers: ['Parameter', 'Ketentuan'],
                rows: [
                  ['Threshold Bulanan', 'Minimal 26 SA / bulan'],
                  ['Syarat Durasi', '3 bulan berturut-turut (tidak kumulatif)'],
                  ['Reward 1 (Tunai)', 'Rp 2.000.000'],
                  ['Reward 2 (Karir)', 'Promosi menjadi AE ELITE (Gaji Pokok UMK Penuh)'],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 5. Survival Rate
          _buildGuideCard(
            title: '5. Survival Rate Incentive (M3 & M5)',
            icon: Icons.verified_user_outlined,
            accentColor: Colors.green.shade700,
            children: [
              _buildText(
                'Berlaku untuk SEMUA level posisi (kesempatan setara tanpa dipengaruhi jumlah produktivitas):',
              ),
              const SizedBox(height: 8),
              _buildTierTable(
                headers: ['Periode Retensi', 'Syarat Gate', 'Insentif / Surviving Sub'],
                rows: [
                  ['M3 (Bulan ke-3)', 'Survival Rate ≥ 90%', 'Rp 100.000 / pelanggan aktif'],
                  ['M5 (Bulan ke-5)', 'Survival Rate ≥ 80%', 'Rp 80.000 / pelanggan aktif'],
                ],
              ),
              const SizedBox(height: 8),
              _buildText(
                'Syarat: Pelanggan berstatus PAID berturut-turut tanpa UNPAID di tengah periode. M3 hanya membayarkan produk regular (monthly), M5 tidak membayarkan paket ≥ 5 bulan.',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 6. Quarterly Bonus & Net Add Incentive
          _buildGuideCard(
            title: '6. Bonus Kuartalan & Net Add (Khusus Pro & Elite)',
            icon: Icons.workspace_premium_outlined,
            accentColor: Colors.deepOrange.shade700,
            children: [
              _buildText(
                'Hanya berlaku untuk AE PRO dan AE ELITE (OJT tidak eligible):',
              ),
              const SizedBox(height: 8),
              const Text(
                'A. Quarterly Bonus (Syarat: M3 Survival Kuartal ≥ 90%)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              _buildTierTable(
                headers: ['Produktivitas Kuartal', 'Nominal Bonus'],
                rows: [
                  ['30 – 44 SA', 'Rp 2.000.000'],
                  ['45 – 59 SA', 'Rp 15.000.000'],
                  ['≥ 60 SA', 'Rp 20.000.000 + (Rp 10.000 × SA di atas 60)'],
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'B. Monthly Net Add Incentive (Capped maks. 10 SA Incremental)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              _buildTierTable(
                headers: ['Ending Active Subs', 'Insentif / Net Add'],
                rows: [
                  ['80 – 99 Subs', 'Rp 50.000 / incremental SA'],
                  ['100 – 199 Subs', 'Rp 100.000 / incremental SA'],
                  ['≥ 200 Subs', 'Rp 150.000 / incremental SA'],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 7. Guiding Principles
          _buildGuideCard(
            title: '7. Ketentuan & Aturan Validasi (Guiding Principles)',
            icon: Icons.rule_outlined,
            accentColor: const Color(0xFF002B66),
            children: [
              _buildBullet('1. Skema berlaku mulai Performance 1 September 2026 (Payout 15 Oktober 2026).'),
              _buildBullet('2. Populasi SA yang diperhitungkan adalah SA month 1 bulan full sesuai data Power BI (tidak menggunakan SO dan SA Paid, carry over tidak berlaku lagi).'),
              _buildBullet('3. Posisi sales yang digunakan dalam perhitungan Activation Fee adalah latest position end of month.'),
              _buildBullet('4. Jika AE terbukti melakukan FRAUD, maka seluruh Insentif dan Basic Fee tidak akan dibayarkan.'),
            ],
          ),
          const SizedBox(height: 24),

          // Footer Copyright
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.copyright, size: 13, color: Color(0xFF002B66)),
                  SizedBox(width: 4),
                  Text(
                    "Copyright D'Azhars Studio",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Creative Tech Agency · All Rights Reserved • Ver.1.0.2',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.3,
                    ),
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

  Widget _buildText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        color: Colors.grey.shade800,
        height: 1.4,
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200),
            verticalInside: BorderSide(color: Colors.grey.shade200),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.blue.shade50),
              children: headers
                  .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Text(
                          h,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF002B66),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            ...rows.map(
              (r) => TableRow(
                children: r
                    .map((cell) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                          child: Text(
                            cell,
                            style: const TextStyle(fontSize: 10.5, color: Colors.black87),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBox(String text, Color bgColor, Color textColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: textColor, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
