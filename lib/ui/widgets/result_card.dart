import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/calculator_models.dart';
import '../../core/engine/calculator_engine.dart';

class ResultCard extends StatelessWidget {
  final CalculationResult? calculationResult;
  final Map<String, dynamic> results;

  const ResultCard({
    super.key,
    this.calculationResult,
    required this.results,
  });

  String _fmt(num val) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(val);
  }

  @override
  Widget build(BuildContext context) {
    final positionName = calculationResult?.position.label ??
        (results['position'] as String? ?? 'Elite');
    final city = calculationResult?.city ??
        (results['city'] as String? ?? CalculatorEngine.defaultCity);
    final basicFee = calculationResult?.basicFee ??
        ((results['basicFee'] as num?)?.toDouble() ?? 0.0);
    final totalSa = calculationResult?.totalSa ??
        ((results['totalSa'] as num?)?.toInt() ?? 0);
    final progInc = calculationResult?.progInc ??
        ((results['progInc'] as num?)?.toDouble() ?? 0.0);
    final pmBase = calculationResult?.pmBase ??
        ((results['pmBase'] as num?)?.toDouble() ?? 0.0);
    final multRate = calculationResult?.multRate ??
        ((results['multRate'] as num?)?.toDouble() ?? 0.0);
    final multBonus = calculationResult?.multBonus ??
        ((results['multBonus'] as num?)?.toDouble() ?? 0.0);
    final specialInc = calculationResult?.specialInc ??
        ((results['specialInc'] as num?)?.toDouble() ?? 0.0);
    final lumpSumBonus = calculationResult?.lumpSumBonus ??
        ((results['lumpSumBonus'] as num?)?.toDouble() ?? 0.0);
    final isOjt = calculationResult?.position == PositionType.ojt ||
        positionName == 'OJT';
    final monthlySubtotal = calculationResult?.monthlySubtotal ??
        ((results['monthlySubtotal'] as num?)?.toDouble() ??
            ((results['grandTotal'] as num?)?.toDouble() ?? 0.0));
    final grandTotal = calculationResult?.grandTotal ??
        ((results['grandTotal'] as num?)?.toDouble() ?? 0.0);

    return Column(
      children: [
        // Rincian Bulanan Card
        Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Rincian
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF002B66),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.payments_outlined,
                          size: 18, color: Colors.amberAccent),
                      SizedBox(width: 8),
                      Text(
                        'RINCIAN PERHITUNGAN BULANAN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                _buildRincianItem(
                  title: 'Basic Fee',
                  subtitle: 'Gaji pokok posisi $positionName ($city)',
                  value: _fmt(basicFee),
                  highlightValue: false,
                ),
                const Divider(height: 16),

                _buildRincianItem(
                  title: 'Progresif SA',
                  subtitle: isOjt
                      ? 'Tier OJT kumulatif $totalSa aktivasi'
                      : multRate > 0
                          ? 'Hilang karena perhitungan Multiplier aktif (${multRate}x)'
                          : 'Tier Pro/Elite kumulatif $totalSa aktivasi',
                  value: _fmt(progInc),
                  highlightValue: progInc > 0,
                  badge: isOjt || multRate == 0
                      ? '$totalSa aktivasi'
                      : 'Diganti Booster',
                ),
                const Divider(height: 16),

                _buildRincianItem(
                  title: 'Product Mix Base',
                  subtitle: 'Total insentif dasar paket aktivasi',
                  value: _fmt(pmBase),
                  highlightValue: pmBase > 0,
                ),
                const Divider(height: 16),

                if (isOjt) ...[
                  _buildRincianItem(
                    title: 'Lump Sum Bonus OJT',
                    subtitle: totalSa >= 7
                        ? 'Capaian ≥ 7 SA (Rp 600.000)'
                        : totalSa >= 3
                            ? 'Capaian ≥ 3 SA (Rp 325.000)'
                            : 'Belum mencapai syarat min. 3 SA',
                    value: _fmt(lumpSumBonus),
                    highlightValue: lumpSumBonus > 0,
                  ),
                  const Divider(height: 16),
                  _buildRincianItem(
                    title: 'Booster (Multiplier)',
                    subtitle: 'Tidak berlaku untuk OJT (khusus Pro & Elite)',
                    value: 'Rp 0',
                    highlightValue: false,
                  ),
                  const Divider(height: 16),
                ] else ...[
                  _buildRincianItem(
                    title: multRate > 0
                        ? 'Booster Multiplier (${multRate}x)'
                        : 'Booster Multiplier',
                    subtitle: multBonus > 0
                        ? '${multRate}x × Product Mix Base (${_fmt(pmBase)})'
                        : 'Belum mencapai syarat multiplier min. 7 SA',
                    value: _fmt(multBonus),
                    highlightValue: multBonus > 0,
                  ),
                  const Divider(height: 16),
                ],

                _buildRincianItem(
                  title: 'Special PXGY',
                  subtitle: 'Insentif khusus paket PXGY',
                  value: _fmt(specialInc),
                  highlightValue: specialInc > 0,
                ),

                if (calculationResult != null &&
                    calculationResult!.survivalDetail.totalSurvivalBonus > 0) ...[
                  const Divider(height: 16),
                  _buildRincianItem(
                    title: 'Insentif Survival Rate',
                    subtitle:
                        'M3: ${_fmt(calculationResult!.survivalDetail.m3Total)} | M5: ${_fmt(calculationResult!.survivalDetail.m5Total)}',
                    value: _fmt(calculationResult!.survivalDetail.totalSurvivalBonus),
                    highlightValue: true,
                  ),
                ],

                if (calculationResult != null &&
                    calculationResult!.quarterlyDetail.totalQuarterlyBonus > 0) ...[
                  const Divider(height: 16),
                  _buildRincianItem(
                    title: 'Quarterly Bonus DSA',
                    subtitle:
                        'Pencapaian Kuartal: ${calculationResult!.quarterlyDetail.quarterlySa} SA (M3: ${(calculationResult!.quarterlyDetail.m3SurvivalRate * 100).toStringAsFixed(0)}%)',
                    value: _fmt(calculationResult!.quarterlyDetail.totalQuarterlyBonus),
                    highlightValue: true,
                  ),
                ],

                if (calculationResult != null &&
                    calculationResult!.netAddDetail.totalNetAddBonus > 0) ...[
                  const Divider(height: 16),
                  _buildRincianItem(
                    title: 'Net Add Incentive',
                    subtitle:
                        'Kenaikan: ${calculationResult!.netAddDetail.incrementalSa} SA @ ${_fmt(calculationResult!.netAddDetail.ratePerSa)}',
                    value: _fmt(calculationResult!.netAddDetail.totalNetAddBonus),
                    highlightValue: true,
                  ),
                ],

                const Divider(height: 20, thickness: 1.5),

                // Subtotal Bulanan Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      calculationResult != null &&
                              calculationResult!.totalComprehensive != grandTotal
                          ? 'Total Komprehensif'
                          : 'Subtotal Bulanan',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _fmt(calculationResult?.totalComprehensive ?? monthlySubtotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF002B66),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Grand Total Gradient Banner
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF002B66), Color(0xFF006699)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF002B66).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          child: Column(
            children: [
              const Text(
                'ESTIMASI TOTAL PENGHASILAN KESELURUHAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _fmt(grandTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$positionName · Bulanan ${_fmt(monthlySubtotal)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified, size: 12, color: Colors.amberAccent),
                    SizedBox(width: 4),
                    Text(
                      'XL SATU CILACAP · TSC PIPIN',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRincianItem({
    required String title,
    required String subtitle,
    required String value,
    required bool highlightValue,
    String? badge,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Colors.black87,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: highlightValue ? Colors.green.shade800 : Colors.black87,
          ),
        ),
      ],
    );
  }
}
