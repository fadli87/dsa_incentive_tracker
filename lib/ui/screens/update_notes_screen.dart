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
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  version,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002B66),
                  ),
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
