import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/visit_form_config.dart';
import '../../core/utils/launcher_helper.dart';
import '../../data/models/visit_activity.dart';
import '../../providers/visit_provider.dart';
import 'visit_form_screen.dart';
import 'visit_map_screen.dart';

class VisitDailyScreen extends ConsumerWidget {
  const VisitDailyScreen({super.key});

  Color _categoryColor(VisitCategory cat) {
    switch (cat) {
      case VisitCategory.rvai:
        return Colors.green.shade700;
      case VisitCategory.dismantle:
        return Colors.red.shade700;
      case VisitCategory.unpaid:
        return Colors.amber.shade700;
    }
  }

  Color _categoryBgColor(VisitCategory cat) {
    switch (cat) {
      case VisitCategory.rvai:
        return Colors.green.shade50;
      case VisitCategory.dismantle:
        return Colors.red.shade50;
      case VisitCategory.unpaid:
        return Colors.amber.shade50;
    }
  }

  void _shiftDate(WidgetRef ref, int days) {
    final currentStr = ref.read(visitSelectedDateProvider);
    final current = DateTime.tryParse(currentStr) ?? DateTime.now();
    final next = current.add(Duration(days: days));
    ref.read(visitSelectedDateProvider.notifier).state = formatVisitDate(next);
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final currentStr = ref.read(visitSelectedDateProvider);
    final current = DateTime.tryParse(currentStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      ref.read(visitSelectedDateProvider.notifier).state = formatVisitDate(picked);
    }
  }

  void _showVisitDetailSheet(BuildContext context, WidgetRef ref, VisitActivity visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _VisitDetailBottomSheet(visit: visit),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDateStr = ref.watch(visitSelectedDateProvider);
    final selectedCategory = ref.watch(visitSelectedCategoryProvider);
    final visitsAsync = ref.watch(visitProvider);
    final countsAsync = ref.watch(visitCountsByCategoryProvider);

    final counts = countsAsync.valueOrNull ??
        const {
          VisitCategory.rvai: 0,
          VisitCategory.dismantle: 0,
          VisitCategory.unpaid: 0,
        };
    final totalCount = (counts[VisitCategory.rvai] ?? 0) +
        (counts[VisitCategory.dismantle] ?? 0) +
        (counts[VisitCategory.unpaid] ?? 0);

    final parsedDate = DateTime.tryParse(selectedDateStr);
    final formattedDate = parsedDate != null
        ? DateFormat('EEEE, dd MMM yyyy').format(parsedDate)
        : selectedDateStr;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AKTIVITAS HARIAN VISIT',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            Text(
              'Monitoring RVAI · Dismantle · Unpaid',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buka Peta Visit',
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitMapScreen(initialDate: selectedDateStr),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Tambah Target',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitFormScreen(initialDate: selectedDateStr),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Bar Pemilih Tanggal & Filter Kategori
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pemilih Tanggal
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF002B66)),
                      onPressed: () => _shiftDate(ref, -1),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(context, ref),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today, size: 15, color: Color(0xFF002B66)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF002B66),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF002B66)),
                      onPressed: () => _shiftDate(ref, 1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Chip Kategori Semua / RVAI / Dismantle / Unpaid dengan jumlah
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        key: const Key('filter_chip_all'),
                        label: Text('Semua ($totalCount)'),
                        selected: selectedCategory == null,
                        selectedColor: const Color(0xFF002B66),
                        labelStyle: TextStyle(
                          color: selectedCategory == null ? Colors.white : const Color(0xFF002B66),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          ref.read(visitSelectedCategoryProvider.notifier).state = null;
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const Key('filter_chip_rvai'),
                        label: Text('RVAI (${counts[VisitCategory.rvai] ?? 0})'),
                        selected: selectedCategory == VisitCategory.rvai,
                        selectedColor: Colors.green.shade700,
                        labelStyle: TextStyle(
                          color: selectedCategory == VisitCategory.rvai
                              ? Colors.white
                              : Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          ref.read(visitSelectedCategoryProvider.notifier).state =
                              VisitCategory.rvai;
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const Key('filter_chip_dismantle'),
                        label: Text('Dismantle (${counts[VisitCategory.dismantle] ?? 0})'),
                        selected: selectedCategory == VisitCategory.dismantle,
                        selectedColor: Colors.red.shade700,
                        labelStyle: TextStyle(
                          color: selectedCategory == VisitCategory.dismantle
                              ? Colors.white
                              : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          ref.read(visitSelectedCategoryProvider.notifier).state =
                              VisitCategory.dismantle;
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const Key('filter_chip_unpaid'),
                        label: Text('Unpaid (${counts[VisitCategory.unpaid] ?? 0})'),
                        selected: selectedCategory == VisitCategory.unpaid,
                        selectedColor: Colors.amber.shade700,
                        labelStyle: TextStyle(
                          color: selectedCategory == VisitCategory.unpaid
                              ? Colors.white
                              : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          ref.read(visitSelectedCategoryProvider.notifier).state =
                              VisitCategory.unpaid;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Daftar Kartu Visit
          Expanded(
            child: visitsAsync.when(
              data: (visits) {
                if (visits.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada target visit pada tanggal ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tekan tombol "Tambah Target" di kanan bawah untuk mencatat rencana visit RVAI, Dismantle, atau Unpaid.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: visits.length,
                  itemBuilder: (context, index) {
                    final visit = visits[index];
                    final catColor = _categoryColor(visit.category);
                    final catBg = _categoryBgColor(visit.category);

                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: catColor.withValues(alpha: 0.45), width: 1.2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showVisitDetailSheet(context, ref, visit),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Badge Kategori Berwarna
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: catBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: catColor),
                                    ),
                                    child: Text(
                                      visit.category.displayLabel.toUpperCase(),
                                      style: TextStyle(
                                        color: catColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Chip Status
                                  _buildStatusChip(visit.status),
                                  const Spacer(),

                                  // Ikon sudah isi Google Form
                                  if (visit.formSubmitted)
                                    Tooltip(
                                      message: 'Sudah isi Google Form',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.green.shade400),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.fact_check_rounded,
                                              size: 13,
                                              color: Colors.green.shade800,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Form OK',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Customer ID & Nama
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      visit.customerName.isNotEmpty
                                          ? '${visit.customerId} · ${visit.customerName}'
                                          : 'ID: ${visit.customerId}',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF002B66),
                                      ),
                                    ),
                                  ),
                                  if (visit.hasLocation)
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                ],
                              ),
                              if (visit.address.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  visit.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              if (visit.note.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Catatan: ${visit.note}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(VisitStatus status) {
    final (label, color, bg) = switch (status) {
      VisitStatus.belum => ('Belum Visit', Colors.grey.shade800, Colors.grey.shade200),
      VisitStatus.sudahVisit => ('Sudah Visit', Colors.green.shade800, Colors.green.shade100),
      VisitStatus.followUp => ('Follow-up', Colors.orange.shade900, Colors.orange.shade100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _VisitDetailBottomSheet extends ConsumerStatefulWidget {
  final VisitActivity visit;

  const _VisitDetailBottomSheet({required this.visit});

  @override
  ConsumerState<_VisitDetailBottomSheet> createState() => _VisitDetailBottomSheetState();
}

class _VisitDetailBottomSheetState extends ConsumerState<_VisitDetailBottomSheet> {
  late VisitStatus _status;
  late TextEditingController _noteCtrl;
  late bool _formSubmitted;

  @override
  void initState() {
    super.initState();
    _status = widget.visit.status;
    _noteCtrl = TextEditingController(text: widget.visit.note);
    _formSubmitted = widget.visit.formSubmitted;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveQuickUpdate() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    String? visitedAt = widget.visit.visitedAt;
    if (_status == VisitStatus.sudahVisit && (visitedAt == null || visitedAt.isEmpty)) {
      visitedAt = nowIso;
    }

    final updated = widget.visit.copyWith(
      status: _status,
      note: _noteCtrl.text.trim(),
      visitedAt: visitedAt,
      formSubmitted: _formSubmitted,
      updatedAt: nowIso,
    );

    await ref.read(visitProvider.notifier).updateVisit(updated);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status visit berhasil diperbarui!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openGoogleForm() async {
    final uri = VisitFormConfig.buildPrefillUri(
      customerId: widget.visit.customerId,
      category: widget.visit.category,
    );
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!mounted) return;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sudah Mengisi Google Form?'),
        content: const Text(
          'Apakah Anda sudah selesai mengirim laporan hasil visit di Google Form manajemen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Belum'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sudah Isi'),
          ),
        ],
      ),
    );

    if (submitted == true && mounted) {
      setState(() => _formSubmitted = true);
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final updated = widget.visit.copyWith(
        status: _status,
        note: _noteCtrl.text.trim(),
        formSubmitted: true,
        updatedAt: nowIso,
      );
      await ref.read(visitProvider.notifier).updateVisit(updated);
    }
  }

  Future<void> _confirmDelete() async {
    final id = widget.visit.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Target Visit?'),
        content: Text(
          'Target pelanggan ID ${widget.visit.customerId} akan dihapus dari daftar harian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await ref.read(visitProvider.notifier).deleteVisit(id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formConfigured = VisitFormConfig.isConfigured;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.visit.customerName.isNotEmpty
                        ? '${widget.visit.customerId} · ${widget.visit.customerName}'
                        : 'Customer ID: ${widget.visit.customerId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Lengkap',
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF002B66)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitFormScreen(initialVisit: widget.visit),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Hapus Target',
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  onPressed: _confirmDelete,
                ),
              ],
            ),
            if (widget.visit.address.isNotEmpty) ...[
              Text(
                widget.visit.address,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
            ],

            const Divider(),
            const SizedBox(height: 8),

            // Pilih Status
            const Text(
              'Status Kunjungan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: VisitStatus.values.map((st) {
                final selected = _status == st;
                return ChoiceChip(
                  label: Text(st.displayLabel),
                  selected: selected,
                  onSelected: (_) => setState(() => _status = st),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Catatan Hasil
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan Hasil Visit',
                hintText: 'Tulis hasil kunjungan atau tindak lanjut',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Tombol Navigasi & Isi Google Form
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Navigasi'),
                    onPressed: widget.visit.hasLocation
                        ? () {
                            LauncherHelper.openGoogleMaps(
                              widget.visit.latitude!,
                              widget.visit.longitude!,
                            );
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('visit_open_google_form_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Isi Google Form'),
                    onPressed: formConfigured ? _openGoogleForm : null,
                  ),
                ),
              ],
            ),

            if (!formConfigured) ...[
              const SizedBox(height: 6),
              Text(
                'Link Google Form belum dikonfigurasi (VISIT_FORM_URL kosong saat build).',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                ),
                onPressed: _saveQuickUpdate,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Simpan Status & Catatan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
