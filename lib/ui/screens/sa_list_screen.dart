import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/sa_provider.dart';
import '../../core/utils/launcher_helper.dart';
import '../../data/models/sa_record.dart';
import 'sa_form_screen.dart';

class SaListScreen extends ConsumerWidget {
  const SaListScreen({super.key});

  void _showLocationDialog(BuildContext context, SaRecord record) {
    if (!record.hasLocation) return;
    final latLng = LatLng(record.latitude!, record.longitude!);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Row(
          children: [
            const Icon(Icons.location_pin, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lokasi: ${record.nama}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Koordinat: ${record.latitude!.toStringAsFixed(6)}, ${record.longitude!.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Container(
              height: 220,
              width: double.maxFinite,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: latLng,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.dsa.dsa_incentive_tracker',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: latLng,
                        width: 45,
                        height: 45,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002B66),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.directions, size: 18),
            label: const Text('Buka di Google Maps'),
            onPressed: () {
              Navigator.pop(ctx);
              LauncherHelper.openGoogleMaps(record.latitude!, record.longitude!);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saState = ref.watch(saProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'DATA PELANGGAN (SA)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            Text(
              '100% Offline Local DB · XL SATU CILACAP • TSC PIPIN',
              style: TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.cloud_off, size: 13, color: Colors.greenAccent),
                SizedBox(width: 4),
                Text(
                  'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: saState.when(
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 72, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada data pelanggan.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002B66),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Pelanggan Baru'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SaFormScreen()),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              String dateFmt = r.tanggalPasang;
              try {
                dateFmt = DateFormat('dd MMM yyyy')
                    .format(DateTime.parse(r.tanggalPasang));
              } catch (_) {}

              return Dismissible(
                key: Key('sa_${r.id ?? index}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red.shade400,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus Data Pelanggan'),
                      content: Text('Hapus data pelanggan "${r.nama}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) {
                  if (r.id != null) {
                    ref.read(saProvider.notifier).deleteSaRecord(r.id!);
                  }
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF002B66),
                              foregroundColor: Colors.white,
                              child: Text(
                                r.nama.isNotEmpty ? r.nama[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.nama,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          r.paket,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'ID: ${r.idPelanggan}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '• $dateFmt',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18),

                        // Kontak Telepon & WA
                        if (r.noHpUtama.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.phone, size: 16, color: Color(0xFF002B66)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'HP: ${r.noHpUtama}${r.noHpAlternatif.isNotEmpty ? ' / ${r.noHpAlternatif}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Quick Call Button
                                InkWell(
                                  onTap: () => LauncherHelper.makePhoneCall(r.noHpUtama),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.call, size: 16, color: Color(0xFF002B66)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Quick WhatsApp Button
                                InkWell(
                                  onTap: () => LauncherHelper.openWhatsApp(r.noHpUtama),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.chat, size: 16, color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Alamat
                        if (r.alamat.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.home_outlined, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    r.alamat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Pin Lokasi & Aksi Peta
                        if (r.hasLocation)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.red),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${r.latitude!.toStringAsFixed(4)}, ${r.longitude!.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    foregroundColor: const Color(0xFF002B66),
                                  ),
                                  icon: const Icon(Icons.map, size: 15),
                                  label: const Text('Peta', style: TextStyle(fontSize: 11.5)),
                                  onPressed: () => _showLocationDialog(context, r),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => LauncherHelper.openGoogleMaps(r.latitude!, r.longitude!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.directions, size: 14, color: Colors.red),
                                        SizedBox(width: 2),
                                        Text(
                                          'Maps',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SaFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Tambah SA'),
      ),
    );
  }
}
