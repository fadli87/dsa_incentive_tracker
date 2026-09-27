import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/calculator_provider.dart';
import '../../providers/history_provider.dart';
import '../../data/models/incentive_record.dart';

class SpvCalculatorView extends ConsumerStatefulWidget {
  const SpvCalculatorView({super.key});

  @override
  ConsumerState<SpvCalculatorView> createState() => _SpvCalculatorViewState();
}

class _SpvCalculatorViewState extends ConsumerState<SpvCalculatorView> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final state = ref.read(calculatorProvider);
    _controllers = {
      'regular': TextEditingController(text: _textVal(state.spvQtyRegular)),
      'pxgy': TextEditingController(text: _textVal(state.spvQtyPxgy)),
      'activeAgents':
          TextEditingController(text: _textVal(state.spvActiveAgents)),
      'agentEarnAf':
          TextEditingController(text: _textVal(state.spvAgentEarnAf)),
      'mob': TextEditingController(text: _textVal(state.spvMob)),
      'ojt': TextEditingController(text: _textVal(state.spvOjtCount)),
      'm3Baseline': TextEditingController(text: _textVal(state.spvM3Baseline)),
      'm3Surviving':
          TextEditingController(text: _textVal(state.spvM3Surviving)),
      'm5Baseline': TextEditingController(text: _textVal(state.spvM5Baseline)),
      'm5Surviving':
          TextEditingController(text: _textVal(state.spvM5Surviving)),
      'ojtToProNormal':
          TextEditingController(text: _textVal(state.spvOjtToProNormal)),
      'ojtToProAccel':
          TextEditingController(text: _textVal(state.spvOjtToProAccel)),
      'proToEliteNormal':
          TextEditingController(text: _textVal(state.spvProToEliteNormal)),
      'proToEliteAccel':
          TextEditingController(text: _textVal(state.spvProToEliteAccel)),
      'quarterlyTeamSa':
          TextEditingController(text: _textVal(state.spvQuarterlyTeamSa)),
      'quarterlyM3Rate': TextEditingController(
          text: state.spvQuarterlyM3Rate == 0 ? '' : (state.spvQuarterlyM3Rate * 100).toInt().toString()),
    };
  }

  String _textVal(int v) => v == 0 ? '' : v.toString();

  void _syncControllersWithState(CalculatorState state) {
    _controllers['regular']?.text = _textVal(state.spvQtyRegular);
    _controllers['pxgy']?.text = _textVal(state.spvQtyPxgy);
    _controllers['activeAgents']?.text = _textVal(state.spvActiveAgents);
    _controllers['agentEarnAf']?.text = _textVal(state.spvAgentEarnAf);
    _controllers['mob']?.text = _textVal(state.spvMob);
    _controllers['ojt']?.text = _textVal(state.spvOjtCount);
    _controllers['m3Baseline']?.text = _textVal(state.spvM3Baseline);
    _controllers['m3Surviving']?.text = _textVal(state.spvM3Surviving);
    _controllers['m5Baseline']?.text = _textVal(state.spvM5Baseline);
    _controllers['m5Surviving']?.text = _textVal(state.spvM5Surviving);
    _controllers['ojtToProNormal']?.text = _textVal(state.spvOjtToProNormal);
    _controllers['ojtToProAccel']?.text = _textVal(state.spvOjtToProAccel);
    _controllers['proToEliteNormal']?.text =
        _textVal(state.spvProToEliteNormal);
    _controllers['proToEliteAccel']?.text =
        _textVal(state.spvProToEliteAccel);
    _controllers['quarterlyTeamSa']?.text =
        _textVal(state.spvQuarterlyTeamSa);
    _controllers['quarterlyM3Rate']?.text = state.spvQuarterlyM3Rate == 0
        ? ''
        : (state.spvQuarterlyM3Rate * 100).toInt().toString();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(num val) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(val);
  }

  Widget _buildField({
    required String label,
    required String helper,
    required String fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controllers[fieldKey],
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            hintText: '0',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF002B66), width: 1.5),
            ),
          ),
          onChanged: (val) {
            if (fieldKey == 'quarterlyM3Rate') {
              final parsed = double.tryParse(val) ?? 0.0;
              ref.read(calculatorProvider.notifier).updateSpvQuarterlyM3Rate(parsed / 100.0);
            } else {
              final parsed = int.tryParse(val) ?? 0;
              ref.read(calculatorProvider.notifier).updateSpvField(fieldKey, parsed);
            }
          },
        ),
        if (helper.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            helper,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final notifier = ref.read(calculatorProvider.notifier);
    final res = state.spvCalculationResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preset Shortcuts & Basic Fee Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF002B66), Color(0xFF004098)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF002B66).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.military_tech, color: Colors.amberAccent, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'SKEMA SPV BARU',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'Basic Fee: ${_fmt(res.basicFee)}',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Muat contoh simulasi dari slide acuan September 2026:',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.flash_on, size: 14, color: Colors.amberAccent),
                    label: const Text('Simulasi SPV A', style: TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      notifier.loadSpvPresetA();
                      _syncControllersWithState(ref.read(calculatorProvider));
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.flash_on, size: 14, color: Colors.cyanAccent),
                    label: const Text('Simulasi SPV B', style: TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      notifier.loadSpvPresetB();
                      _syncControllersWithState(ref.read(calculatorProvider));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 1. CARD: POIN 1 - KPI BONUS
        _buildSectionCard(
          title: '1. KPI BONUS (POIN 1)',
          icon: Icons.pie_chart,
          iconColor: Colors.indigo,
          subtotal: res.kpiBonus.totalKpiBonus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step 1: Product Mix
              const Text(
                'Step 1. Productivity Mix (ARPU & PXGY)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'SA Reguler (<279k)',
                      helper:
                          'Rate: ${_fmt(res.kpiBonus.productMix.rateRegular)}/SA',
                      fieldKey: 'regular',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      label: 'SA PXGY & ARPU ≥279k',
                      helper:
                          'Rate: ${_fmt(res.kpiBonus.productMix.ratePxgy)}/SA',
                      fieldKey: 'pxgy',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                'Total Product Mix:',
                _fmt(res.kpiBonus.productMix.totalProductMix),
                isHighlight: true,
              ),

              const Divider(height: 20),

              // Step 2: Participation Bonus
              const Text(
                'Step 2. Participation Bonus (DSA Aktif)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'Agent Earn AF',
                      helper: 'DSA dapat insentif',
                      fieldKey: 'agentEarnAf',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      label: 'Total Active Agents',
                      helper: 'DSA aktif dalam tim',
                      fieldKey: 'activeAgents',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                'Partisipasi (${(res.kpiBonus.participation.participationRate * 100).toStringAsFixed(0)}%):',
                'Multiplier ${res.kpiBonus.participation.multiplier}x ➔ ${_fmt(res.kpiBonus.participation.participationBonus)}',
              ),

              const Divider(height: 20),

              // Step 3: SPV Parameters & Multiplier
              const Text(
                'Step 3. SPV MoB & KPI Multiplier',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'MoB SPV (Bulan)',
                      helper: 'Masa kerja SPV',
                      fieldKey: 'mob',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      label: 'OJT & New Hire',
                      helper:
                          '${(res.kpiBonus.ojtRatio * 100).toStringAsFixed(0)}% komposisi OJT',
                      fieldKey: 'ojt',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                'KPI Multiplier:',
                '${(res.kpiBonus.kpiMultiplier * 100).toStringAsFixed(0)}% ${res.kpiBonus.mobSpv <= 3 ? "(MoB ≤ 3)" : ""}',
                isHighlight: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. CARD: POIN 2 - SURVIVAL RATE INCENTIVE
        _buildSectionCard(
          title: '2. SURVIVAL RATE INCENTIVE (POIN 2)',
          icon: Icons.verified_user,
          iconColor: Colors.teal,
          subtotal: res.totalSurvivalIncentive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // M3
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'M3 Survival (Gate ≥ 90%)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  _buildGateBadge(
                    res.m3Survival.isGatePassed,
                    '${(res.m3Survival.survivalRate * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'Baseline SA M3',
                      helper: 'SA M3',
                      fieldKey: 'm3Baseline',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      label: 'Surviving Subs M3',
                      helper: 'Paid berturut-turut',
                      fieldKey: 'm3Surviving',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildInfoRow(
                'Total M3:',
                _fmt(res.m3Survival.totalBonus),
              ),

              const Divider(height: 18),

              // M5
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'M5 Survival (Gate ≥ 80%)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  _buildGateBadge(
                    res.m5Survival.isGatePassed,
                    '${(res.m5Survival.survivalRate * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'Baseline SA M5',
                      helper: 'SA M5',
                      fieldKey: 'm5Baseline',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      label: 'Surviving Subs M5',
                      helper: 'Paid berturut-turut',
                      fieldKey: 'm5Surviving',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildInfoRow(
                'Total M5:',
                _fmt(res.m5Survival.totalBonus),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. CARD: POIN 3 - GRADUATION BONUS
        _buildSectionCard(
          title: '3. GRADUATION BONUS (POIN 3)',
          icon: Icons.school,
          iconColor: Colors.orange,
          subtotal: res.graduation.totalBonus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Promote OJT ➔ Pro',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'Normal (≥3 bln)',
                      helper: 'Rp 500k / sales',
                      fieldKey: 'ojtToProNormal',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      label: 'Akselerasi (<3 bln)',
                      helper: 'Rp 700k / sales',
                      fieldKey: 'ojtToProAccel',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Promote Pro ➔ Elite',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'Normal (≥3 bln)',
                      helper: 'Rp 600k / sales',
                      fieldKey: 'proToEliteNormal',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      label: 'Akselerasi (<3 bln)',
                      helper: 'Rp 800k / sales',
                      fieldKey: 'proToEliteAccel',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4. CARD: POIN 4 - MONTHLY PERFORMANCE BONUS
        _buildSectionCard(
          title: '4. MONTHLY PERFORMANCE (POIN 4)',
          icon: Icons.trending_up,
          iconColor: Colors.green,
          subtotal: res.monthlyPerformance.bonusAmount,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total SA Tim: ${res.totalTeamSa} Aktivasi',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: res.monthlyPerformance.bonusAmount > 0
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: res.monthlyPerformance.bonusAmount > 0
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      res.monthlyPerformance.tierDescription,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: res.monthlyPerformance.bonusAmount > 0
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• 160+ SA: Rp 2.500.000 | 200+ SA: Rp 3.500.000 | 250+ SA: Rp 5.000.000',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 5. CARD: POIN 5 - QUARTERLY BONUS SPV
        _buildSectionCard(
          title: '5. QUARTERLY BONUS SPV (POIN 5)',
          icon: Icons.emoji_events_rounded,
          iconColor: const Color(0xFFD97706),
          subtotal: res.quarterlyDetail.totalQuarterlyBonus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      label: 'Total SA Tim Kuartal',
                      helper: 'Akumulasi 3 bulan tim',
                      fieldKey: 'quarterlyTeamSa',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      label: 'M3 Survival Kuartal (%)',
                      helper: 'Gate Kelayakan: ≥ 80%',
                      fieldKey: 'quarterlyM3Rate',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status Gate Kelayakan (≥80%):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  _buildGateBadge(
                    res.quarterlyDetail.isGatePassed,
                    '${(res.quarterlyDetail.m3SurvivalRate * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
              if (res.quarterlyDetail.incrementalSa > 0) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  'Bonus Incremental (≥500 SA):',
                  '${res.quarterlyDetail.incrementalSa} SA × Rp 30k = ${_fmt(res.quarterlyDetail.incrementalBonus)}',
                  isHighlight: true,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '• 50–99 (1.5jt) | 100–149 (1.5jt) | 150–199 (2jt) | 200–249 (3jt) | 250–299 (4.5jt) | 300–349 (6jt) | 350–399 (8jt) | 400–449 (10jt) | 450–499 (12jt) | ≥500 (12jt + 30k/inc SA)',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // RINGKASAN GRAND TOTAL SPV
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF002B66).withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.receipt_long, color: Color(0xFF002B66)),
                  SizedBox(width: 8),
                  Text(
                    'RINGKASAN ESTIMASI PAYOUT SPV',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildSummaryLine('Basic Fee SPV (Tetap):', _fmt(res.basicFee)),
              _buildSummaryLine('1. KPI Bonus:', _fmt(res.kpiBonus.totalKpiBonus)),
              _buildSummaryLine(
                  '2. Survival Rate:', _fmt(res.totalSurvivalIncentive)),
              _buildSummaryLine(
                  '3. Graduation Bonus:', _fmt(res.graduation.totalBonus)),
              _buildSummaryLine(
                  '4. Monthly Performance:',
                  _fmt(res.monthlyPerformance.bonusAmount)),
              _buildSummaryLine(
                  '5. Quarterly Bonus SPV:',
                  _fmt(res.quarterlyDetail.totalQuarterlyBonus)),
              const Divider(thickness: 1.5, height: 22),
              _buildSummaryLine(
                'TOTAL INSENTIF:',
                _fmt(res.totalIncentive),
                isBold: true,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF002B66),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TAKE HOME PAY:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _fmt(res.grandTotal),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan ke Histori Insentif'),
                onPressed: () async {
                  final now = DateTime.now();
                  final periodStr = DateFormat('MMMM yyyy', 'id').format(now);
                  final rec = IncentiveRecord(
                    periode: periodStr,
                    position: 'SPV',
                    city: res.city,
                    basicFee: res.basicFee,
                    totalSa: res.totalTeamSa,
                    pmBase: res.kpiBonus.productMix.totalProductMix,
                    multRate: res.kpiBonus.kpiMultiplier,
                    multBonus: res.kpiBonus.totalKpiBonus,
                    progInc: res.totalSurvivalIncentive,
                    specialInc: res.graduation.totalBonus +
                        res.monthlyPerformance.bonusAmount,
                    monthlySubtotal: res.grandTotal,
                    grandTotal: res.grandTotal,
                  );

                  await ref.read(historyProvider.notifier).addRecord(rec);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data insentif SPV berhasil disimpan!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required double subtotal,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _fmt(subtotal),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFF1F5F9) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF002B66) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isBold ? const Color(0xFF002B66) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGateBadge(bool isPassed, String percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPassed ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPassed ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPassed ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: isPassed ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            '$percentage (${isPassed ? "Lolos Gate" : "Tidak Lolos"})',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isPassed ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
