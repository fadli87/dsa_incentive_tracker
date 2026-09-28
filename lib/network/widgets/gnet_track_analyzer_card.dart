import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/cell_signal_info.dart';
import '../models/wifi_info.dart';
import '../providers/network_monitor_provider.dart';

/// Widget komprehensif penampil parameter seluler setara G-NetTrack Lite
/// yang dilengkapi mesin AURA Smart RF Analyzer agar sangat mudah dianalisis.
class GNetTrackAnalyzerCard extends ConsumerStatefulWidget {
  const GNetTrackAnalyzerCard({super.key});

  @override
  ConsumerState<GNetTrackAnalyzerCard> createState() => _GNetTrackAnalyzerCardState();
}

class _GNetTrackAnalyzerCardState extends ConsumerState<GNetTrackAnalyzerCard> {
  int _selectedView = 0; // 0: Analisis Cerdas, 1: Matriks G-NetTrack, 2: Neighbor & Riwayat

  @override
  Widget build(BuildContext context) {
    final cellAsync = ref.watch(cellSignalProvider);
    final wifiAsync = ref.watch(wifiInfoProvider);
    final trafficAsync = ref.watch(liveThroughputProvider);
    final gpsAsync = ref.watch(liveGpsProvider);
    final tracker = ref.watch(cellTrackerProvider);
    final rfAnalysis = ref.watch(rfAnalysisProvider);

    return cellAsync.when(
      loading: () => const _CardLoading(),
      error: (err, _) => _CardError(error: err.toString()),
      data: (snapshot) => _buildContent(
        context,
        snapshot: snapshot,
        wifi: wifiAsync.value,
        traffic: trafficAsync.value ?? const LiveThroughput(),
        gps: gpsAsync.value ?? const LiveGpsInfo(),
        tracker: tracker,
        analysis: rfAnalysis,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required TelephonySnapshot snapshot,
    required WifiInfo? wifi,
    required LiveThroughput traffic,
    required LiveGpsInfo gps,
    required CellTrackerState tracker,
    required RfAnalysisReport analysis,
  }) {
    final cell = snapshot.servingCell;
    final quality = cell?.signalQuality ?? SignalQuality.unknown;
    final primaryColor = Color(quality.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -----------------------------------------------------------------
          // 1. HEADER BAR: Operator, Network Type, Serving Time, Data State
          // -----------------------------------------------------------------
          _buildHeaderBar(snapshot, wifi, tracker, primaryColor),

          // -----------------------------------------------------------------
          // 2. VIEW SWITCHER (Segmented Control)
          // -----------------------------------------------------------------
          _buildViewSwitcher(),

          const Divider(color: Colors.white12, height: 1),

          // -----------------------------------------------------------------
          // 3. TAB CONTENT
          // -----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(16),
            child: switch (_selectedView) {
              0 => _buildSmartAnalysisTab(cell, analysis, primaryColor, snapshot),
              1 => _buildGNetMatrixTab(cell, snapshot, wifi, traffic, gps, tracker),
              _ => _buildNeighborAndHistoryTab(snapshot, tracker),
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER BAR
  // ===========================================================================

  Widget _buildHeaderBar(
    TelephonySnapshot snapshot,
    WifiInfo? wifi,
    CellTrackerState tracker,
    Color primaryColor,
  ) {
    final dataStateText = (wifi != null && wifi.isConnected)
        ? 'WIFI-"${wifi.ssid.isNotEmpty ? wifi.ssid : "Connected"}" DATA'
        : '${snapshot.networkType} MOBILE DATA';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Operator Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operator: ${snapshot.operatorDisplayName.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'RobotoMono',
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dataStateText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontFamily: 'RobotoMono',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Serving Time Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF4FC3F7)),
                    const SizedBox(width: 4),
                    Text(
                      'Serving: ${tracker.servingTimeDisplay}',
                      style: const TextStyle(
                        color: Color(0xFF4FC3F7),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Dual-SIM Slot Switcher (Tepat 2 slot fisik: SIM 1 & SIM 2)
          Consumer(
            builder: (context, ref, _) {
              final simSlotsAsync = ref.watch(simSlotsProvider);
              final selectedSlot = ref.watch(selectedSlotProvider);
              final detectedSlots = (simSlotsAsync.value ?? const [])
                  .where((s) => s.simSlotIndex == 0 || s.simSlotIndex == 1)
                  .toList();

              final slot0 = detectedSlots.where((s) => s.simSlotIndex == 0).firstOrNull ??
                  const SimSlotInfo(
                    subscriptionId: 1,
                    simSlotIndex: 0,
                    displayName: 'SIM 1',
                    carrierName: 'SIM 1',
                    isActive: true,
                  );

              final slot1 = detectedSlots.where((s) => s.simSlotIndex == 1).firstOrNull ??
                  const SimSlotInfo(
                    subscriptionId: 2,
                    simSlotIndex: 1,
                    displayName: 'SIM 2',
                    carrierName: 'SIM 2',
                    isActive: false,
                  );

              final List<SimSlotInfo> slots = [slot0, slot1];

              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        'SLOT:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: slots.map((sim) {
                            final isSelected = selectedSlot == sim.simSlotIndex;
                            final displayName = sim.carrierName.isNotEmpty &&
                                    sim.carrierName != 'SIM ${sim.simSlotIndex + 1}'
                                ? 'SIM ${sim.simSlotIndex + 1}: ${sim.carrierName}'
                                : 'SIM ${sim.simSlotIndex + 1}';

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  ref.read(selectedSlotProvider.notifier).select(sim.simSlotIndex);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF00E5FF)
                                          : Colors.white24,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF00E5FF)
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 6,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sim_card,
                                        size: 13,
                                        color: isSelected
                                            ? const Color(0xFF00E5FF)
                                            : Colors.white54,
                                      ),
                                      const SizedBox(width: 5),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 130),
                                        child: Text(
                                          displayName,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize: 11,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontFamily: 'RobotoMono',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF00E5FF),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. VIEW SWITCHER TABS
  // ===========================================================================

  Widget _buildViewSwitcher() {
    final tabs = [
      (Icons.auto_awesome, 'Analisis Cerdas'),
      (Icons.grid_view_rounded, 'Matriks G-Net'),
      (Icons.cell_tower, 'Sel Tetangga & Log'),
    ];

    return Container(
      color: Colors.black26,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedView == idx;
          final tab = tabs[idx];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedView = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4FC3F7).withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4FC3F7) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.$1,
                        size: 13,
                        color: isSelected ? const Color(0xFF4FC3F7) : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tab.$2,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // 3. TAB 1: AURA SMART RF ANALYSIS (MUDAN DIANALISA)
  // ===========================================================================

  Widget _buildSmartAnalysisTab(
    CellData? cell,
    RfAnalysisReport analysis,
    Color primaryColor,
    TelephonySnapshot snapshot,
  ) {
    if (cell == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Menunggu data sinyal seluler...', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RF Health Score Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: 0.15),
                Colors.black26,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Circle Score
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black45,
                  border: Border.all(color: primaryColor, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    '${analysis.overallScore}',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skor Kualitas RF: ${analysis.scoreGrade}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      analysis.coverageRating,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      analysis.coverageExplanation,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Auto-Diagnostics Verdict Narrative Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.psychology, size: 20, color: Color(0xFF4FC3F7)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Diagnosa Otomatis AURA',
                      style: TextStyle(
                        color: Color(0xFF4FC3F7),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      analysis.verdictSummary,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4 Core Pillar Grid: Coverage, Noise, Distance, Modulation
        Row(
          children: [
            Expanded(
              child: _buildAnalysisMetricCard(
                icon: Icons.signal_cellular_alt,
                label: 'Cakupan (RSRP)',
                value: cell.rsrpDisplay,
                subtitle: analysis.coverageRating,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAnalysisMetricCard(
                icon: Icons.graphic_eq,
                label: 'Kemurnian (SINR)',
                value: cell.sinrDisplay,
                subtitle: analysis.interferenceRating,
                color: (cell.sinr != null && cell.sinr! >= 8)
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildAnalysisMetricCard(
                icon: Icons.near_me,
                label: 'Jarak BTS',
                value: cell.distanceDisplay,
                subtitle: analysis.distanceEstimate,
                color: const Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAnalysisMetricCard(
                icon: Icons.speed,
                label: 'Modulasi (CQI)',
                value: cell.cqiDisplay,
                subtitle: analysis.modulationCapability,
                color: const Color(0xFFB388FF),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Radio Spectrum Breakdown
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.radio, size: 14, color: Colors.white70),
                  SizedBox(width: 6),
                  Text(
                    'Informasi Spektrum & Frekuensi',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubInfo('Band', cell.bandShortCode),
                  _buildSubInfo('Bandwidth', cell.bandwidthDisplay),
                  _buildSubInfo('EARFCN', cell.arfcnDisplay),
                  _buildSubInfo('Duplex', cell.earfcnInfo?.duplexMode ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubInfo('Frekuensi DL', cell.fDlDisplay),
                  _buildSubInfo('Frekuensi UL', cell.fUlDisplay),
                  _buildSubInfo('eNodeB ID', cell.eNodeBIdDisplay),
                  _buildSubInfo('Sector CID', cell.cidDisplay),
                ],
              ),
            ],
          ),
        ),

        // Neighbor Evaluation Note if available
        if (analysis.bestNeighborComparison != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2412),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analysis.bestNeighborComparison!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Practical Advice Tips
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saran Praktis:',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...analysis.practicalAdvice.map(
                (adv) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Color(0xFF4FC3F7))),
                      Expanded(
                        child: Text(
                          adv,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
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
    );
  }

  Widget _buildAnalysisMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              Icon(icon, size: 13, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'RobotoMono',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSubInfo(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 9.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'RobotoMono',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. TAB 2: MATRIKS G-NETTRACK (100% PARITAS PARAMETER)
  // ===========================================================================

  Widget _buildGNetMatrixTab(
    CellData? cell,
    TelephonySnapshot snapshot,
    WifiInfo? wifi,
    LiveThroughput traffic,
    LiveGpsInfo gps,
    CellTrackerState tracker,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C101D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Row 1: MCC, MNC, TAC, Type
          _buildGNetRow([
            ('MCC', cell?.mcc ?? '510'),
            ('MNC', cell?.mnc ?? '01'),
            ('TAC', cell?.tacDisplay ?? '-'),
            ('Type', cell?.cellType ?? snapshot.networkType),
          ]),
          const SizedBox(height: 6),

          // Row 2: eNB, CID, PCI, TA
          _buildGNetRow([
            ('eNB', cell?.eNodeBIdDisplay ?? '-'),
            ('CID', cell?.cidDisplay ?? '-'),
            ('PCI', cell?.pciDisplay ?? '-'),
            ('TA', cell?.timingAdvanceDisplay ?? '-'),
          ]),
          const SizedBox(height: 6),

          // Row 3: ARFCN, BAND, BW
          _buildGNetRow([
            ('ARFCN', cell?.arfcnDisplay ?? '-'),
            ('BAND', cell?.bandShortCode ?? '-'),
            ('BW', cell?.bandwidthDisplay ?? '-'),
          ]),
          const SizedBox(height: 6),

          // Row 4: F DL, F UL
          _buildGNetRow([
            ('F DL', cell?.fDlDisplay ?? '-'),
            ('F UL', cell?.fUlDisplay ?? '-'),
          ]),
          const SizedBox(height: 6),

          // Row 5: RSRP, RSRQ, SNR, CQI, RSSI
          _buildGNetRow([
            ('RSRP', cell?.rsrp != null ? '${cell!.rsrp}' : '-'),
            ('RSRQ', cell?.rsrq != null ? '${cell!.rsrq}' : '-'),
            ('SNR', cell?.sinr != null ? '${cell!.sinr}.0' : '-'),
            ('CQI', cell?.cqiDisplay ?? '-'),
            ('RSSI', cell?.rssi != null ? '${cell!.rssi}' : '-'),
          ]),
          const SizedBox(height: 6),

          // Row 6: Longitude, Latitude
          _buildGNetRow([
            ('Longitude', gps.longitudeDisplay),
            ('Latitude', gps.latitudeDisplay),
          ]),
          const SizedBox(height: 6),

          // Row 7: Speed, Hdg, GPS Acc
          _buildGNetRow([
            ('Speed', gps.speedDisplay),
            ('Hdg', gps.headingDisplay),
            ('GPS Acc', gps.accuracyDisplay),
          ]),
          const SizedBox(height: 6),

          // Row 8: Height, Altitude, Ground
          _buildGNetRow([
            ('Height', gps.altitudeDisplay),
            ('Altitude', gps.altitudeDisplay),
            ('Ground', '0m'),
          ]),
          const SizedBox(height: 6),

          // Row 9: UL, DL
          _buildGNetRow([
            ('UL', traffic.ulDisplay),
            ('DL', traffic.dlDisplay),
          ]),
          const SizedBox(height: 6),

          // Row 10: Data state
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Data: ${(wifi != null && wifi.isConnected) ? 'WIFI-"${wifi.ssid}"' : snapshot.networkType}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'RobotoMono'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'DATA',
                  style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Row 11: Serving time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Serving time: ${tracker.servingTimeDisplay}',
                  style: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'RobotoMono',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGNetRow(List<(String, String)> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: items.map((it) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11),
                    children: [
                      TextSpan(
                        text: '${it.$1}: ',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      TextSpan(
                        text: it.$2,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // 5. TAB 3: NEIGHBOR CELLS & SERVING CELL HISTORY TABLE
  // ===========================================================================

  Widget _buildNeighborAndHistoryTab(
    TelephonySnapshot snapshot,
    CellTrackerState tracker,
  ) {
    final serving = snapshot.servingCell;
    final neighbors = snapshot.neighborCells;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header Label
        const Text(
          'Tabel Sel & Riwayat (Paritas G-NetTrack):',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Scrollable Matrix Table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: DataTable(
              columnSpacing: 14,
              headingRowHeight: 32,
              dataRowMinHeight: 28,
              dataRowMaxHeight: 32,
              headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
              columns: const [
                DataColumn(label: Text('TIME', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('EVENT', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('AC', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('CELLID', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('CI', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('ARFCN', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('LEVEL', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('QUAL', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('TYPE', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
                DataColumn(label: Text('SERV', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontFamily: 'RobotoMono'))),
              ],
              rows: [
                // Current serving row
                if (serving != null)
                  DataRow(
                    color: WidgetStateProperty.all(const Color(0xFF1B5E20).withValues(alpha: 0.3)),
                    cells: [
                      DataCell(Text(
                        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'RobotoMono'),
                      )),
                      const DataCell(Text('SERV', style: TextStyle(color: Color(0xFF81C784), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'))),
                      DataCell(Text(serving.tacDisplay, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(serving.eNodeBCidDisplay, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'))),
                      DataCell(Text(serving.pciDisplay, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(serving.arfcnDisplay, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text('${serving.primarySignalDbm ?? "-"}', style: const TextStyle(color: Color(0xFF81C784), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'))),
                      DataCell(Text('${serving.rsrq ?? "-"}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(serving.networkType, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      const DataCell(Icon(Icons.check_circle, size: 13, color: Color(0xFF81C784))),
                    ],
                  ),

                // Neighbor rows
                ...neighbors.map((n) {
                  return DataRow(
                    cells: [
                      const DataCell(Text('-', style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'RobotoMono'))),
                      const DataCell(Text('NEI', style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(n.tacDisplay, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(n.eNodeBCidDisplay, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(n.pciDisplay, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(n.arfcnDisplay, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text('${n.primarySignalDbm ?? "-"}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text('${n.rsrq ?? "-"}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(n.networkType, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'))),
                      const DataCell(Text('', style: TextStyle(fontSize: 10))),
                    ],
                  );
                }),

                // History rows
                ...tracker.history.map((h) {
                  return DataRow(
                    cells: [
                      DataCell(Text(h.time, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(h.event, style: TextStyle(color: h.event == 'HANDOVER' ? Colors.orange : Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(h.areaCode, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(h.cellId, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(h.pci, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(h.arfcn, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(h.level, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(h.qual, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      DataCell(Text(h.type, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'RobotoMono'))),
                      const DataCell(Text('-', style: TextStyle(color: Colors.white24, fontSize: 10))),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Neighbor Signal Comparison Bars
        if (neighbors.isNotEmpty) ...[
          const Text(
            'Perbandingan Sinyal Sel Tetangga (Neighbor Cells):',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...neighbors.map((n) {
            final nRsrp = n.primarySignalDbm;
            final sRsrp = serving?.primarySignalDbm;
            final delta = (nRsrp != null && sRsrp != null) ? nRsrp - sRsrp : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'PCI ${n.pciDisplay} (${n.bandShortCode})',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      n.rsrpDisplay,
                      style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontFamily: 'RobotoMono'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (delta != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: delta > 0 ? Colors.orange.withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${delta > 0 ? "+" : ""}$delta dB',
                        style: TextStyle(
                          color: delta > 0 ? Colors.orange : Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF101426),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4FC3F7)),
      ),
    );
  }
}

class _CardError extends StatelessWidget {
  final String error;
  const _CardError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.signal_cellular_connected_no_internet_4_bar, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Izin Lokasi & Status Telepon diperlukan untuk membaca sensor seluler.\n$error',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002B66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await [
                  Permission.location,
                  Permission.phone,
                ].request();
              },
              icon: const Icon(Icons.verified_user, size: 16),
              label: const Text('Berikan Izin Sinyal & Lokasi', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
