import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/sa_provider.dart';
import '../../data/models/sa_record.dart';

class SaFormScreen extends ConsumerStatefulWidget {
  final SaRecord? initialRecord;
  final double? initialLatitude;
  final double? initialLongitude;

  const SaFormScreen({
    super.key,
    this.initialRecord,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  ConsumerState<SaFormScreen> createState() => _SaFormScreenState();
}

class _SaFormScreenState extends ConsumerState<SaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _noHpUtamaCtrl = TextEditingController();
  final _noHpAltCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final MapController _mapController = MapController();

  String _paket = 'FTTH Reguler';
  DateTime _selectedDate = DateTime.now();

  // Titik default Cilacap
  static const LatLng _cilacapCenter = LatLng(-7.7188, 109.0156);
  LatLng? _selectedLocation;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRecord != null) {
      final r = widget.initialRecord!;
      _idCtrl.text = r.idPelanggan;
      _namaCtrl.text = r.nama;
      _noHpUtamaCtrl.text = r.noHpUtama;
      _noHpAltCtrl.text = r.noHpAlternatif;
      _alamatCtrl.text = r.alamat;
      _paket = r.paket;
      try {
        _selectedDate = DateTime.parse(r.tanggalPasang);
      } catch (_) {}
      if (r.hasLocation) {
        _selectedLocation = LatLng(r.latitude!, r.longitude!);
      }
    } else if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _namaCtrl.dispose();
    _noHpUtamaCtrl.dispose();
    _noHpAltCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Layanan lokasi (GPS) belum aktif. Silakan aktifkan GPS perangkat.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Izin akses lokasi ditolak.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = latLng;
      });
      _mapController.move(latLng, 16.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Titik koordinat berhasil didapatkan dari GPS!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil lokasi GPS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRecord != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Data Pelanggan' : 'Input Data Pelanggan Baru'),
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Banner Privasi & Offline
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.green.shade800, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Penyimpanan 100% Offline Lokal. Tanpa KTP demi privasi. Dilengkapi titik pin peta dan kontak telepon.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Identitas Pelanggan
            TextFormField(
              controller: _idCtrl,
              decoration: const InputDecoration(
                labelText: 'ID Pelanggan *',
                hintText: 'Contoh: CIL-10023 / SA-889',
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
                labelText: 'Nama Pelanggan *',
                hintText: 'Nama lengkap pelanggan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama Pelanggan wajib diisi' : null,
            ),
            const SizedBox(height: 14),

            // No HP Utama & Alternatif
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _noHpUtamaCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'No. HP Utama *',
                      hintText: '0812xxxx',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'No. HP Utama wajib diisi'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _noHpAltCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'HP Alternatif',
                      hintText: 'Opsional',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _alamatCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alamat Pemasangan',
                hintText: 'Nama jalan, RT/RW, kelurahan, kecamatan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Paket & Tanggal
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
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.calendar_month, color: Color(0xFF002B66)),
              title: const Text('Tanggal Pasang'),
              subtitle: Text(
                DateFormat('dd MMMM yyyy').format(_selectedDate),
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
            const SizedBox(height: 20),

            // Bagian Pin Peta & Lokasi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.location_on, color: Color(0xFF002B66)),
                          SizedBox(width: 6),
                          Text(
                            'Titik Lokasi Pemasangan (Peta)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF002B66),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLocating ? null : _getCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002B66),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                        ),
                        icon: _isLocating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location, size: 15),
                        label: Text(
                          _isLocating ? 'Mencari...' : 'GPS Saya',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ketuk pada peta untuk menandai titik koordinat rumah pelanggan:',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),

                  // Map Container
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation ?? _cilacapCenter,
                        initialZoom: 13.0,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedLocation = point;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.dsa.dsa_incentive_tracker',
                        ),
                        if (_selectedLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Coordinate Status Bar
                  if (_selectedLocation != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 16, color: Color(0xFF002B66)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Koordinat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF002B66),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _selectedLocation = null),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.close, size: 16, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          'Belum ada pin lokasi yang dipilih (opsional).',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF002B66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(isEditing ? Icons.check_circle_outline : Icons.save),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final record = SaRecord(
                    id: widget.initialRecord?.id,
                    idPelanggan: _idCtrl.text.trim(),
                    nama: _namaCtrl.text.trim(),
                    noHpUtama: _noHpUtamaCtrl.text.trim(),
                    noHpAlternatif: _noHpAltCtrl.text.trim(),
                    alamat: _alamatCtrl.text.trim(),
                    paket: _paket,
                    tanggalPasang: _selectedDate.toIso8601String(),
                    latitude: _selectedLocation?.latitude,
                    longitude: _selectedLocation?.longitude,
                  );
                  if (isEditing) {
                    await ref.read(saProvider.notifier).updateSaRecord(record);
                  } else {
                    await ref.read(saProvider.notifier).addSaRecord(record);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing
                            ? 'Data Pelanggan Berhasil Diperbarui!'
                            : 'Data Pelanggan Berhasil Disimpan (Offline)!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context);
                  }
                }
              },
              label: Text(
                isEditing ? 'Perbarui Data Pelanggan' : 'Simpan Data Pelanggan',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
