import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/sa_provider.dart';
import '../../data/models/sa_record.dart';

class SaFormScreen extends ConsumerStatefulWidget {
  const SaFormScreen({super.key});

  @override
  ConsumerState<SaFormScreen> createState() => _SaFormScreenState();
}

class _SaFormScreenState extends ConsumerState<SaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _ktpCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  String _paket = 'FTTH Reguler';
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _idCtrl.dispose();
    _namaCtrl.dispose();
    _ktpCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Data Pelanggan Baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _idCtrl,
              decoration: const InputDecoration(
                labelText: 'ID Pelanggan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'ID Pelanggan wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _namaCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Pelanggan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama Pelanggan wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ktpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'No KTP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _alamatCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Alamat Pemasangan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _paket,
              decoration: const InputDecoration(
                labelText: 'Pilih Paket',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
              items: [
                'FTTH Reguler',
                'FWA Reguler',
                'PXGY (3-5 Bln)',
                'PXGY (>=6 Bln)'
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _paket = v);
                }
              },
            ),
            const SizedBox(height: 14),
            ListTile(
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.calendar_month, color: Color(0xFF002B66)),
              title: const Text('Tanggal Pasang'),
              subtitle: Text(
                DateFormat('dd MMM yyyy').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF002B66),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final record = SaRecord(
                    idPelanggan: _idCtrl.text.trim(),
                    nama: _namaCtrl.text.trim(),
                    noKtp: _ktpCtrl.text.trim(),
                    alamat: _alamatCtrl.text.trim(),
                    paket: _paket,
                    tanggalPasang: _selectedDate.toIso8601String(),
                  );
                  await ref.read(saProvider.notifier).addSaRecord(record);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Data Pelanggan Berhasil Disimpan!')),
                    );
                    Navigator.pop(context);
                  }
                }
              },
              label: const Text(
                'Simpan Data Pelanggan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
