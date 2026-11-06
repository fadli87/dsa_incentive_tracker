import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../core/services/permission_service.dart';
import '../../data/models/visit_activity.dart';
import '../../maps/utils/location_parser.dart';
import '../../providers/visit_provider.dart';

class VisitFormScreen extends ConsumerStatefulWidget {
  final VisitActivity? initialVisit;
  final String? initialDate;

  const VisitFormScreen({
    super.key,
    this.initialVisit,
    this.initialDate,
  });

  @override
  ConsumerState<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends ConsumerState<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerIdCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _packageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _sharelocCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  VisitCategory? _selectedCategory;
  late DateTime _plannedDate;
  bool _isLocating = false;
  bool _isParsingLink = false;

  @override
  void initState() {
    super.initState();
    final v = widget.initialVisit;
    if (v != null) {
      _customerIdCtrl.text = v.customerId;
      _customerNameCtrl.text = v.customerName;
      _selectedCategory = v.category;
      _packageCtrl.text = v.packageName;
      _addressCtrl.text = v.address;
      _noteCtrl.text = v.note;
      if (v.latitude != null) {
        _latCtrl.text = v.latitude!.toStringAsFixed(6);
      }
      if (v.longitude != null) {
        _lngCtrl.text = v.longitude!.toStringAsFixed(6);
      }
      _plannedDate = DateTime.tryParse(v.plannedDate) ?? DateTime.now();
    } else {
      _plannedDate = (widget.initialDate != null
              ? DateTime.tryParse(widget.initialDate!)
              : null) ??
          DateTime.now();
    }
  }

  @override
  void dispose() {
    _customerIdCtrl.dispose();
    _customerNameCtrl.dispose();
    _packageCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _sharelocCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      await PermissionService.requestInitialPermissions();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS belum aktif. Silakan aktifkan layanan lokasi perangkat.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi ditolak. Tidak dapat mengambil posisi GPS.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Koordinat GPS berhasil diambil!'),
            backgroundColor: Colors.green,
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
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _parseSharelocInput() async {
    final raw = _sharelocCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tempel link Google Maps / WhatsApp Shareloc terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() => _isParsingLink = true);
    try {
      final parsed = await LocationParser.parse(raw);
      if (!mounted) return;
      if (parsed != null) {
        setState(() {
          _latCtrl.text = parsed.point.latitude.toStringAsFixed(6);
          _lngCtrl.text = parsed.point.longitude.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Koordinat berhasil diekstrak: ${parsed.point.latitude.toStringAsFixed(6)}, ${parsed.point.longitude.toStringAsFixed(6)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat menemukan koordinat valid dari teks/link tersebut.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isParsingLink = false);
    }
  }

  String? _validateLatitude(String? value) {
    final latStr = (value ?? '').trim();
    final lngStr = _lngCtrl.text.trim();
    if (latStr.isEmpty && lngStr.isEmpty) return null;
    if (latStr.isEmpty && lngStr.isNotEmpty) {
      return 'Latitude wajib diisi jika Longitude diisi';
    }
    final lat = double.tryParse(latStr);
    if (lat == null) return 'Latitude harus berupa angka desimal';
    if (lat < -90.0 || lat > 90.0) {
      return 'Latitude harus berada di rentang -90 hingga 90';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final lngStr = (value ?? '').trim();
    final latStr = _latCtrl.text.trim();
    if (lngStr.isEmpty && latStr.isEmpty) return null;
    if (lngStr.isEmpty && latStr.isNotEmpty) {
      return 'Longitude wajib diisi jika Latitude diisi';
    }
    final lng = double.tryParse(lngStr);
    if (lng == null) return 'Longitude harus berupa angka desimal';
    if (lng < -180.0 || lng > 180.0) {
      return 'Longitude harus berada di rentang -180 hingga 180';
    }
    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    final category = _selectedCategory;
    if (category == null) return;

    final customerId = _customerIdCtrl.text.trim();
    final plannedDateStr = formatVisitDate(_plannedDate);
    final notifier = ref.read(visitProvider.notifier);

    // Cek duplikat kombinasi Customer ID + Kategori + Tanggal (peringatan non-blocking)
    final isDuplicate = await notifier.hasDuplicate(
      customerId: customerId,
      category: category,
      plannedDate: plannedDateStr,
      excludeId: widget.initialVisit?.id,
    );

    if (isDuplicate && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Target Sudah Ada')),
            ],
          ),
          content: Text(
            'Pelanggan dengan Customer ID "$customerId" untuk kategori ${category.displayLabel} '
            'pada tanggal $plannedDateStr sudah tercatat.\n\n'
            'Apakah Anda tetap ingin menyimpannya?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002B66),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tetap Simpan'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final lat = _latCtrl.text.trim().isEmpty ? null : double.tryParse(_latCtrl.text.trim());
    final lng = _lngCtrl.text.trim().isEmpty ? null : double.tryParse(_lngCtrl.text.trim());
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (widget.initialVisit != null) {
      final updated = widget.initialVisit!.copyWith(
        customerId: customerId,
        customerName: _customerNameCtrl.text.trim(),
        category: category,
        packageName: _packageCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: lat,
        longitude: lng,
        clearLocation: lat == null || lng == null,
        plannedDate: plannedDateStr,
        note: _noteCtrl.text.trim(),
        updatedAt: nowIso,
      );
      await notifier.updateVisit(updated);
    } else {
      final created = VisitActivity(
        clientId: '',
        customerId: customerId,
        customerName: _customerNameCtrl.text.trim(),
        category: category,
        status: VisitStatus.belum,
        packageName: _packageCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: lat,
        longitude: lng,
        plannedDate: plannedDateStr,
        note: _noteCtrl.text.trim(),
        updatedAt: nowIso,
      );
      await notifier.addVisit(created);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialVisit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        title: Text(
          isEditing ? 'Ubah Target Visit' : 'Tambah Target Visit',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Banner Privasi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: Colors.blue.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tersimpan offline terlebih dahulu. Jangan masukkan nomor KTP, serial ONT, atau nomor SIM pelanggan.',
                      style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card Data Pelanggan & Kategori
            Card(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DATA TARGET PELANGGAN',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002B66),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Customer ID (Wajib, Angka)
                    TextFormField(
                      key: const Key('visit_customer_id_field'),
                      controller: _customerIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Customer ID *',
                        hintText: 'Contoh: 32018899',
                        prefixIcon: Icon(Icons.tag_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final trimmed = (v ?? '').trim();
                        if (trimmed.isEmpty) {
                          return 'Customer ID wajib diisi';
                        }
                        if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
                          return 'Customer ID hanya boleh berisi angka';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Kategori (Wajib)
                    DropdownButtonFormField<VisitCategory>(
                      key: const Key('visit_category_dropdown'),
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Kategori Visit *',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: VisitCategory.rvai,
                          child: Text('RVAI (Visit Pasca-Instalasi)'),
                        ),
                        DropdownMenuItem(
                          value: VisitCategory.dismantle,
                          child: Text('Dismantle (Retensi)'),
                        ),
                        DropdownMenuItem(
                          value: VisitCategory.unpaid,
                          child: Text('Unpaid (Follow-up Tagihan)'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedCategory = val),
                      validator: (val) =>
                          val == null ? 'Kategori visit wajib dipilih' : null,
                    ),
                    const SizedBox(height: 14),

                    // Nama Pelanggan
                    TextFormField(
                      key: const Key('visit_customer_name_field'),
                      controller: _customerNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pelanggan',
                        hintText: 'Nama pelanggan (opsional)',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Paket
                    TextFormField(
                      key: const Key('visit_package_field'),
                      controller: _packageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Paket',
                        hintText: 'Contoh: FWA Home 100GB / FTTH 50 Mbps',
                        prefixIcon: Icon(Icons.wifi_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Alamat
                    TextFormField(
                      key: const Key('visit_address_field'),
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Ringkas',
                        hintText: 'Jalan, RT/RW, Desa/Kelurahan, Kecamatan',
                        prefixIcon: Icon(Icons.home_work_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tanggal Rencana
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF002B66)),
                      title: const Text(
                        'Tanggal Rencana Visit',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      subtitle: Text(
                        DateFormat('dd MMM yyyy').format(_plannedDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF002B66),
                        ),
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _plannedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _plannedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Catatan
                    TextFormField(
                      key: const Key('visit_note_field'),
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Visit',
                        hintText: 'Catatan kondisi pelanggan / hasil kunjungan',
                        prefixIcon: Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Lokasi (3 Cara: Lokasi Saya, Shareloc, Lat/Lng Manual)
            Card(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TITIK KOORDINAT LOKASI',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF002B66),
                            letterSpacing: 0.5,
                          ),
                        ),
                        // (a) Tombol Lokasi Saya via Geolocator
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF002B66),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: _isLocating ? null : _useCurrentLocation,
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
                            _isLocating ? 'Mencari...' : 'Lokasi Saya',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // (b) Tempel Link / Shareloc (memakai LocationParser.parse)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('visit_shareloc_field'),
                            controller: _sharelocCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tempel Link Google Maps / WA Shareloc',
                              hintText: 'Contoh: https://maps.google.com/?q=-7.71,109.01',
                              prefixIcon: Icon(Icons.link_rounded),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          key: const Key('visit_parse_shareloc_btn'),
                          onPressed: _isParsingLink ? null : _parseSharelocInput,
                          child: _isParsingLink
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Ambil'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // (c) Input Lat / Lng Manual dengan validasi rentang
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const Key('visit_latitude_field'),
                            controller: _latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude (-90..90)',
                              hintText: '-7.718800',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateLatitude,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            key: const Key('visit_longitude_field'),
                            controller: _lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude (-180..180)',
                              hintText: '109.015600',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateLongitude,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Simpan
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                key: const Key('visit_save_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitForm,
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  isEditing ? 'Simpan Perubahan' : 'Simpan Target Visit',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
