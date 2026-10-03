import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/calculator_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/user_info_provider.dart';
import '../../data/models/incentive_record.dart';
import '../../core/models/calculator_models.dart';
import '../widgets/position_selector_tabs.dart';
import '../widgets/tier_productivity_table.dart';
import '../widgets/result_card.dart';
import '../widgets/spv_calculator_view.dart';
import 'guide_screen.dart';
import 'update_notes_screen.dart';
import 'user_info_screen.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'f0': TextEditingController(),
      'f50': TextEditingController(),
      'f100': TextEditingController(),
      'f125': TextEditingController(),
      'f200': TextEditingController(),
      'fwa': TextEditingController(),
      'p35': TextEditingController(),
      'p6': TextEditingController(),
      'dsaM3Baseline': TextEditingController(),
      'dsaM3Surviving': TextEditingController(),
      'dsaM5Baseline': TextEditingController(),
      'dsaM5Surviving': TextEditingController(),
      'dsaQuarterlySa': TextEditingController(),
      'dsaQuarterlyM3Rate': TextEditingController(),
      'dsaBaselineActiveSubs': TextEditingController(),
      'dsaCurrentActiveSubs': TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clearAllFields() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    ref.read(calculatorProvider.notifier).reset();
  }

  String _fmt(num val) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(val);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final notifier = ref.read(calculatorProvider.notifier);
    final result = state.calculationResult;
    final userProfileAsync = ref.watch(userInfoProvider);

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
              'KALKULATOR INCENTIVE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'XL SATU CILACAP · TSC PIPIN · Effective Sept 2026',
              style: TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Info Pengguna',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserInfoScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "Tentang & Copyright",
            onPressed: () => _showAboutStudioDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Input',
            onPressed: _clearAllFields,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
        children: [
          // Banner Info Pengguna
          userProfileAsync.when(
            data: (profile) {
              final hasName = profile.name.trim().isNotEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF002B66).withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserInfoScreen()),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF002B66),
                        foregroundColor: Colors.white,
                        child: Text(
                          hasName ? profile.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasName ? profile.name : 'Atur Info Pengguna (Nama & Sales Code)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: hasName ? const Color(0xFF002B66) : Colors.orange.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (profile.salesCode.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF002B66).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      profile.salesCode,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF002B66),
                                      ),
                                    ),
                                  ),
                                ],
                                const Expanded(
                                  child: Text(
                                    'XL SATU CILACAP · TSC PIPIN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        hasName ? Icons.edit_outlined : Icons.arrow_forward_ios,
                        size: 16,
                        color: const Color(0xFF002B66),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // 1. Selector Tabs Posisi
          PositionSelectorTabs(
            selectedPosition: state.position,
            onPositionChanged: (pos) => notifier.setPosition(pos),
          ),
          const SizedBox(height: 14),

          if (state.position == PositionType.spv) ...[
            const SpvCalculatorView(),
          ] else ...[

          // 2. Card Wilayah & Basic Fee
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text('📍', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text(
                        'WILAYAH',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002B66),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'KAB. CILACAP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        Icon(Icons.location_on,
                            color: Color(0xFF002B66), size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Basic Fee ${result.position.label}: ${_fmt(result.basicFee)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Card Input Produk Aktivasi
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text('📦', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text(
                        'PRODUK AKTIVASI (FTTH)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002B66),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputRow('FTTH < 229', 'Rp 0/aktivasi', 'f0', notifier),
                  _buildInputRow('FTTH 229–299', 'Rp 50.000/aktivasi', 'f50',
                      notifier),
                  _buildInputRow('FTTH 300–399', 'Rp 100.000/aktivasi', 'f100',
                      notifier),
                  _buildInputRow('FTTH 400–599', 'Rp 125.000/aktivasi', 'f125',
                      notifier),
                  _buildInputRow('FTTH ≥ 600', 'Rp 200.000/aktivasi', 'f200',
                      notifier),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Card Bonus FWA & PXGY
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text('⚡', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text(
                        'BONUS FWA & PXGY',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002B66),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputRow(
                      'FWA ≥ 219', '+Rp 50.000/aktivasi', 'fwa', notifier),
                  _buildInputRow('PXGY 3–5 Bln', 'PM 125k + Spec 125k', 'p35',
                      notifier),
                  _buildInputRow('PXGY ≥ 6 Bln', 'PM 150k + Spec 150k', 'p6',
                      notifier),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4b. Card Simulator Survival Rate (M3 & M5)
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.white,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                title: Row(
                  children: [
                    const Text('🛡️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    const Text(
                      'SIMULATOR SURVIVAL RATE',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002B66),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (result.survivalDetail.totalSurvivalBonus > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          _fmt(result.survivalDetail.totalSurvivalBonus),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF002B66).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '• M3 Regular: Gate ≥ 90% (Rp 100.000 / surviving)\n'
                            '• M5 Advance: Gate ≥ 80% (Rp 80.000 / surviving)',
                            style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF002B66)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'M3 Survival (Paket Regular / Bulanan)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controllers['dsaM3Baseline'],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Baseline SA',
                                  labelStyle: const TextStyle(fontSize: 11),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) => _updateDsaSurvival(notifier),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controllers['dsaM3Surviving'],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Surviving Subs',
                                  labelStyle: const TextStyle(fontSize: 11),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) => _updateDsaSurvival(notifier),
                              ),
                            ),
                          ],
                        ),
                        if (result.survivalDetail.m3Base > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Rate M3: ${result.survivalDetail.m3Rate.toStringAsFixed(1)}% '
                            '(${result.survivalDetail.m3GatePassed ? "Lolos Gate ≥ 90% -> ${_fmt(result.survivalDetail.m3Total)}" : "Tidak Lolos Gate < 90%"})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: result.survivalDetail.m3GatePassed ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'M5 Survival (Paket < 5 Bulan)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controllers['dsaM5Baseline'],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Baseline SA',
                                  labelStyle: const TextStyle(fontSize: 11),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) => _updateDsaSurvival(notifier),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controllers['dsaM5Surviving'],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Surviving Subs',
                                  labelStyle: const TextStyle(fontSize: 11),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) => _updateDsaSurvival(notifier),
                              ),
                            ),
                          ],
                        ),
                        if (result.survivalDetail.m5Base > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Rate M5: ${result.survivalDetail.m5Rate.toStringAsFixed(1)}% '
                            '(${result.survivalDetail.m5GatePassed ? "Lolos Gate ≥ 80% -> ${_fmt(result.survivalDetail.m5Total)}" : "Tidak Lolos Gate < 80%"})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: result.survivalDetail.m5GatePassed ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4c. Card Simulator Quarterly Bonus & Net Add
          if (state.position != PositionType.ojt) ...[
            Card(
              elevation: 2,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: Colors.white,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  title: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      const Text(
                        'SIMULATOR BONUS KUARTAL',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002B66),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      if (result.quarterlyDetail.totalQuarterlyBonus + result.netAddDetail.totalNetAddBonus > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.purple.shade300),
                          ),
                          child: Text(
                            _fmt(result.quarterlyDetail.totalQuarterlyBonus + result.netAddDetail.totalNetAddBonus),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '• Tiering Quarterly Bonus (Gate M3 ≥ 90%):\n'
                              '  30-44 SA: Rp 2Jt | 45-59 SA: Rp 15Jt | ≥60 SA: Rp 20Jt + 10k/inc SA\n'
                              '• Net Add Active Subs (Capping max 10 inc SA):\n'
                              '  Base 80-99: @50k | Base 100-199: @100k | Base ≥200: @150k',
                              style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF4A148C)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Payout Quarterly Bonus',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controllers['dsaQuarterlySa'],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Total SA Kuartal',
                                    labelStyle: const TextStyle(fontSize: 11),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => _updateDsaQuarterly(notifier),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _controllers['dsaQuarterlyM3Rate'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'M3 Rate (%)',
                                    labelStyle: const TextStyle(fontSize: 11),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => _updateDsaQuarterly(notifier),
                                ),
                              ),
                            ],
                          ),
                          if (result.quarterlyDetail.quarterlySa > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${result.quarterlyDetail.isGatePassed ? "Lolos Gate (≥ 90%) -> ${_fmt(result.quarterlyDetail.totalQuarterlyBonus)}" : "Tidak Lolos Gate M3 (< 90%)"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: result.quarterlyDetail.isGatePassed ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Text(
                            '2. Net Add Active Subs Booster',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controllers['dsaBaselineActiveSubs'],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Baseline Subs (Q Prev)',
                                    labelStyle: const TextStyle(fontSize: 10.5),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => _updateDsaNetAdd(notifier),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _controllers['dsaCurrentActiveSubs'],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Current Subs (Q Ini)',
                                    labelStyle: const TextStyle(fontSize: 10.5),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => _updateDsaNetAdd(notifier),
                                ),
                              ),
                            ],
                          ),
                          if (result.netAddDetail.baselineActiveSubs > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Net Add: +${result.netAddDetail.incrementalSa} SA (Inc) @ ${_fmt(result.netAddDetail.ratePerSa)} -> ${_fmt(result.netAddDetail.totalNetAddBonus)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: result.netAddDetail.totalNetAddBonus > 0 ? Colors.green.shade700 : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 5. Total Aktivasi Highlight Box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL AKTIVASI',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002B66),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.totalSa} SA Terinput',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF002B66),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      result.multRate > 0 && result.position != PositionType.ojt
                          ? 'Booster (${result.multRate}x): ${_fmt(result.multBonus)}'
                          : 'Progresif: ${_fmt(result.progInc)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Product Mix: ${_fmt(result.pmBase)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Tabel Tier Produktivitas
          TierProductivityTable(result: result),
          const SizedBox(height: 16),

          // 7. Rincian & Grand Total
          ResultCard(
            calculationResult: result,
            results: state.results,
          ),
          const SizedBox(height: 20),

          // 8. Tombol Simpan Histori
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: const Color(0xFF002B66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            icon: const Icon(Icons.save),
            onPressed: () async {
              if (result.totalSa == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Total SA masih 0. Masukkan pencapaian terlebih dahulu.'),
                  ),
                );
                return;
              }
              final record = IncentiveRecord(
                periode: DateFormat('MMM yyyy').format(DateTime.now()),
                position: result.position.label,
                city: result.city,
                basicFee: result.basicFee,
                totalSa: result.totalSa,
                pmBase: result.pmBase,
                multRate: result.multRate,
                multBonus: result.multBonus,
                progInc: result.progInc,
                specialInc: result.specialInc,
                monthlySubtotal: result.monthlySubtotal,
                grandTotal: result.grandTotal,
                f0: int.tryParse(_controllers['f0']!.text) ?? 0,
                f50: int.tryParse(_controllers['f50']!.text) ?? 0,
                f100: int.tryParse(_controllers['f100']!.text) ?? 0,
                f125: int.tryParse(_controllers['f125']!.text) ?? 0,
                f200: int.tryParse(_controllers['f200']!.text) ?? 0,
                fwa: int.tryParse(_controllers['fwa']!.text) ?? 0,
                p35: int.tryParse(_controllers['p35']!.text) ?? 0,
                p6: int.tryParse(_controllers['p6']!.text) ?? 0,
              );
              await ref.read(historyProvider.notifier).addRecord(record);
              _clearAllFields();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pencapaian berhasil disimpan ke histori!'),
                  ),
                );
              }
            },
            label: const Text(
              'Simpan Histori Pencapaian',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          ],
          const SizedBox(height: 18),

          // 9. Copyright Footer
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.copyright, size: 12, color: Color(0xFF002B66)),
                    SizedBox(width: 4),
                    Text(
                      "Copyright D'Azhars Studio",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002B66),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Creative Tech Agency · All Rights Reserved • Ver.1.0.8',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutStudioDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'DSA INCENTIVE TRACKER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002B66),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Effective September 2026',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFF15A24),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aplikasi kalkulator dan pencatatan insentif untuk tim Account Executive DSA D2D.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const Divider(height: 24),
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
              'Creative Tech Agency · All Rights Reserved • Ver.1.0.8',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF002B66),
              side: const BorderSide(color: Color(0xFF002B66)),
            ),
            icon: const Icon(Icons.menu_book, size: 16),
            label: const Text('Buka Panduan Skema'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GuideScreen()),
              );
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF002B66),
              side: const BorderSide(color: Color(0xFF002B66)),
            ),
            icon: const Icon(Icons.system_update, size: 16),
            label: const Text('Catatan Update'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpdateNotesScreen()),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Tutup',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(
    String label,
    String rateText,
    String fieldKey,
    CalculatorNotifier notifier,
  ) {
    final controller = _controllers[fieldKey]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  rateText,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 40,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey.shade400),
              ),
              onChanged: (v) {
                final val = int.tryParse(v) ?? 0;
                notifier.updateField(fieldKey, val);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _updateDsaSurvival(CalculatorNotifier notifier) {
    final m3Base = int.tryParse(_controllers['dsaM3Baseline']!.text) ?? 0;
    final m3Surv = int.tryParse(_controllers['dsaM3Surviving']!.text) ?? 0;
    final m5Base = int.tryParse(_controllers['dsaM5Baseline']!.text) ?? 0;
    final m5Surv = int.tryParse(_controllers['dsaM5Surviving']!.text) ?? 0;

    notifier.setDsaM3Survival(m3Base, m3Surv);
    notifier.setDsaM5Survival(m5Base, m5Surv);
  }

  void _updateDsaQuarterly(CalculatorNotifier notifier) {
    final qSa = int.tryParse(_controllers['dsaQuarterlySa']!.text) ?? 0;
    final qM3 = double.tryParse(_controllers['dsaQuarterlyM3Rate']!.text) ?? 0.0;

    notifier.setDsaQuarterly(qSa, qM3);
  }

  void _updateDsaNetAdd(CalculatorNotifier notifier) {
    final baseSubs = int.tryParse(_controllers['dsaBaselineActiveSubs']!.text) ?? 0;
    final currSubs = int.tryParse(_controllers['dsaCurrentActiveSubs']!.text) ?? 0;

    notifier.setDsaNetAdd(baseSubs, currSubs);
  }
}
