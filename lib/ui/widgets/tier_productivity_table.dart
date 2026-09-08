import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/calculator_models.dart';

class TierProductivityTable extends StatelessWidget {
  final CalculationResult result;

  const TierProductivityTable({super.key, required this.result});

  String _fmt(num val) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(val);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_outlined,
                      size: 18, color: Color(0xFF002B66)),
                  const SizedBox(width: 8),
                  Text(
                    'TABEL TIER PRODUKTIVITAS — ${result.position.label}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF002B66),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Table Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Tier',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Rate/Akt',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Mult',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Subtotal Progresif',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Table Rows
            ...result.tierRows.map((tier) {
              final isActive = tier.isCurrentTier;
              return Container(
                color: isActive ? Colors.blue.shade50.withValues(alpha: 0.7) : null,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        tier.tierRange,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive
                              ? const Color(0xFF002B66)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        _fmt(tier.ratePerAkt),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isActive
                              ? const Color(0xFF002B66)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        tier.multiplier > 0 ? '× ${tier.multiplier}' : '—',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive
                              ? const Color(0xFF002B66)
                              : Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tier.unitsInTier > 0
                                ? '${tier.unitsInTier} × ${_fmt(tier.ratePerAkt)} = ${_fmt(tier.subtotalProgressive)}'
                                : '—',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive
                                  ? const Color(0xFF002B66)
                                  : Colors.black87,
                            ),
                          ),
                          if (tier.multiplierBonus > 0)
                            Text(
                              '+ Mult (${tier.multiplier}x): ${_fmt(tier.multiplierBonus)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(thickness: 1.5),

            // Footer Summary Progresif / Multiplier
            if (result.position != PositionType.ojt && result.multRate > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal Progresif (${result.totalSa} SA)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'Rp 0 (Hilang / Multiplier Aktif)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Booster Multiplier (Per Tier)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Text(
                      '+ ${_fmt(result.multBonus)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Insentif Produktivitas',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Color(0xFF002B66),
                      ),
                    ),
                    Text(
                      _fmt(result.multBonus),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF002B66),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal Progresif (${result.totalSa} SA)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _fmt(result.progInc),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // OJT Special Box: Lump Sum Bonus
            if (result.position == PositionType.ojt) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        const Text(
                          'LUMP SUM BONUS OJT',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB76E00),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: result.lumpSumBonus > 0
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            result.lumpSumBonus > 0
                                ? '+ ${_fmt(result.lumpSumBonus)}'
                                : 'Belum Capai Target',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: result.lumpSumBonus > 0
                                  ? Colors.green.shade900
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Min. 3 SA: Rp 325.000\n• Min. 7 SA: Rp 600.000',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.totalSa >= 7
                          ? '✓ Capaian ${result.totalSa} SA: Memperoleh Lump Sum Rp 600.000'
                          : result.totalSa >= 3
                              ? '✓ Capaian ${result.totalSa} SA: Memperoleh Lump Sum Rp 325.000'
                              : 'Butuh ${(3 - result.totalSa).clamp(0, 3)} SA lagi untuk unlock bonus pertama (Rp 325.000)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: result.lumpSumBonus > 0
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // AE PRO Special Box: Performance Bonus & Promotion
            if (result.position == PositionType.pro) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🌟', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXCLUSIVE REWARD AE PRO',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF002B66),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: 26 SA / bulan selama 3 bulan berturut-turut.\nReward: Bonus Rp 2.000.000 + Promosi ke AE Elite.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.indigo.shade900,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
