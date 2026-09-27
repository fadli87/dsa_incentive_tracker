import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';
import '../../ui/screens/sa_form_screen.dart';
import '../../ai/widgets/ai_coach_chat_sheet.dart';

class MapInspectorSheet extends StatelessWidget {
  final BtsTower? tower;
  final HomepassPoint? homepass;
  final LatLng point;
  final String? districtName;
  final double? distanceMeters;
  final String? searchSource;

  const MapInspectorSheet({
    super.key,
    this.tower,
    this.homepass,
    required this.point,
    this.districtName,
    this.distanceMeters,
    this.searchSource,
  });

  static void show(
    BuildContext context, {
    BtsTower? tower,
    HomepassPoint? homepass,
    required LatLng point,
    String? districtName,
    double? distanceMeters,
    String? searchSource,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MapInspectorSheet(
        tower: tower,
        homepass: homepass,
        point: point,
        districtName: districtName,
        distanceMeters: distanceMeters,
        searchSource: searchSource,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTower = tower != null;
    final isHomepass = homepass != null;
    final isSearch = searchSource != null;

    final String distDisplay = distanceMeters != null
        ? distanceMeters! >= 1000
            ? '${(distanceMeters! / 1000).toStringAsFixed(1)} km dari posisi Anda'
            : '${distanceMeters!.round()} m dari posisi Anda'
        : 'Cilacap Area';

    final String title = isTower
        ? tower!.siteName
        : isHomepass
            ? 'Homepass ID: ${homepass!.id}'
            : isSearch
                ? 'Hasil Pencarian Koordinat / ShareLoc'
                : 'Titik Lokasi Prospek';

    final String subtitle = isTower
        ? 'Tower ID: ${tower!.towerId} • ${tower!.city5g ?? "4G/5G"}'
        : isHomepass
            ? '${homepass!.village}, ${homepass!.district} • Cluster ${homepass!.cluster}'
            : (districtName ?? 'Kabupaten Cilacap');

    final IconData icon = isTower
        ? Icons.cell_tower_rounded
        : isHomepass
            ? Icons.home_work_rounded
            : isSearch
                ? Icons.share_location_rounded
                : Icons.location_on_rounded;

    final Color iconColor = isTower
        ? tower!.markerColor
        : isHomepass
            ? homepass!.categoryColor
            : isSearch
                ? const Color(0xFF00E5FF)
                : const Color(0xFF6366F1);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: iconColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Info Grid
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: [
                  if (isTower) ...[
                    _buildInfoRow('eNodeB ID', tower!.enodebId, Icons.router_rounded, isDark),
                    const Divider(height: 12),
                    _buildInfoRow('Tinggi Antena', '${tower!.antennaHeight} meter', Icons.height_rounded, isDark),
                    if (tower!.payload != null && tower!.payload!.isNotEmpty) ...[
                      const Divider(height: 12),
                      _buildInfoRow('Payload Kapasitas', tower!.payload!, Icons.speed_rounded, isDark),
                    ],
                    const Divider(height: 12),
                  ] else if (isHomepass) ...[
                    _buildInfoRow('Prioritas Kunjungan', homepass!.priority, Icons.flag_rounded, isDark),
                    const Divider(height: 12),
                    _buildInfoRow('Kategori / Tipe', '${homepass!.category} (${homepass!.netType})', Icons.category_rounded, isDark),
                    const Divider(height: 12),
                    _buildInfoRow('Desa / Kelurahan', homepass!.village, Icons.location_city_rounded, isDark),
                    const Divider(height: 12),
                  ],
                  if (isSearch && searchSource != null) ...[
                    _buildInfoRow('Sumber ShareLoc', searchSource!, Icons.link_rounded, isDark),
                    const Divider(height: 12),
                  ],
                  _buildInfoRow('Koordinat GPS', '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}', Icons.my_location_rounded, isDark),
                  const Divider(height: 12),
                  _buildInfoRow('Jarak Estimasi', distDisplay, Icons.straighten_rounded, isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                    ),
                    icon: const Icon(Icons.psychology_outlined, color: Color(0xFF6366F1), size: 18),
                    label: const Text(
                      'Tanya AI',
                      style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      AiCoachChatSheet.show(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF002B66),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text(
                      'Input SA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SaFormScreen(
                            initialLatitude: point.latitude,
                            initialLongitude: point.longitude,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
