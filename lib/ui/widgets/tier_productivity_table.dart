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
                        '× ${tier.multiplier}',
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
                      child: Text(
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
                    ),
                  ],
                ),
              );
            }),

            const Divider(thickness: 1.5),

            // Footer Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total (${result.totalSa} aktivasi)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF002B66),
                    ),
                  ),
                  Text(
                    _fmt(result.progInc),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF002B66),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
