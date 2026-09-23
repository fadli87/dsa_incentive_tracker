import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/calculator_models.dart';
import '../../data/models/incentive_record.dart';
import '../../providers/history_provider.dart';
import '../widgets/result_card.dart';
import '../../core/engine/calculator_engine.dart';

class EditHistoryScreen extends ConsumerStatefulWidget {
  final IncentiveRecord record;

  const EditHistoryScreen({super.key, required this.record});

  @override
  ConsumerState<EditHistoryScreen> createState() => _EditHistoryScreenState();
}

class _EditHistoryScreenState extends ConsumerState<EditHistoryScreen> {
  late final Map<String, TextEditingController> ctrls;

  final Map<String, String> labels = {
    'f0': 'FTTH < 229',
    'f50': 'FTTH 229–299',
    'f100': 'FTTH 300–399',
    'f125': 'FTTH 400–599',
    'f200': 'FTTH ≥ 600',
    'fwa': 'FWA ≥ 219',
    'p35': 'PXGY 3–5 Bln',
    'p6': 'PXGY ≥ 6 Bln',
  };

  @override
  void initState() {
    super.initState();
    ctrls = {
      'f0': TextEditingController(text: widget.record.f0.toString()),
      'f50': TextEditingController(text: widget.record.f50.toString()),
      'f100': TextEditingController(text: widget.record.f100.toString()),
      'f125': TextEditingController(text: widget.record.f125.toString()),
      'f200': TextEditingController(text: widget.record.f200.toString()),
      'fwa': TextEditingController(text: widget.record.fwa.toString()),
      'p35': TextEditingController(text: widget.record.p35.toString()),
      'p6': TextEditingController(text: widget.record.p6.toString()),
    };
  }

  @override
  void dispose() {
    for (var controller in ctrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PositionType _positionFromLabel(String label) {
    switch (label) {
      case 'OJT':
        return PositionType.ojt;
      case 'Pro':
        return PositionType.pro;
      case 'Elite':
        return PositionType.elite;
      default:
        return PositionType.ojt;
    }
  }

  CalculationResult buildPreview() {
    return CalculatorEngine.calculateDetailed(
      position: _positionFromLabel(widget.record.position),
      city: widget.record.city,
      f0: int.tryParse(ctrls['f0']!.text) ?? 0,
      f50: int.tryParse(ctrls['f50']!.text) ?? 0,
      f100: int.tryParse(ctrls['f100']!.text) ?? 0,
      f125: int.tryParse(ctrls['f125']!.text) ?? 0,
      f200: int.tryParse(ctrls['f200']!.text) ?? 0,
      fwa: int.tryParse(ctrls['fwa']!.text) ?? 0,
      p35: int.tryParse(ctrls['p35']!.text) ?? 0,
      p6: int.tryParse(ctrls['p6']!.text) ?? 0,
    );
  }

  Future<void> _saveAndRecalculate() async {
    final newResult = buildPreview();
    final updated = widget.record.copyWith(
      totalSa: newResult.totalSa,
      pmBase: newResult.pmBase,
      multRate: newResult.multRate,
      multBonus: newResult.multBonus,
      progInc: newResult.progInc,
      specialInc: newResult.specialInc,
      monthlySubtotal: newResult.monthlySubtotal,
      grandTotal: newResult.grandTotal,
      f0: int.tryParse(ctrls['f0']!.text) ?? 0,
      f50: int.tryParse(ctrls['f50']!.text) ?? 0,
      f100: int.tryParse(ctrls['f100']!.text) ?? 0,
      f125: int.tryParse(ctrls['f125']!.text) ?? 0,
      f200: int.tryParse(ctrls['f200']!.text) ?? 0,
      fwa: int.tryParse(ctrls['fwa']!.text) ?? 0,
      p35: int.tryParse(ctrls['p35']!.text) ?? 0,
      p6: int.tryParse(ctrls['p6']!.text) ?? 0,
    );

    await ref.read(historyProvider.notifier).updateRecord(updated);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Histori diperbarui & dihitung ulang!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Edit Histori: ${widget.record.periode}'),
        centerTitle: true,
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Input Aktivasi Mentah',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002B66),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...ctrls.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextField(
                          controller: e.value,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: labels[e.key],
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResultCard(calculationResult: buildPreview(), results: const {}),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveAndRecalculate,
                child: const Text(
                  'Simpan & Hitung Ulang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
