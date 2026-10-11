import '../../network/models/cell_signal_info.dart';
import '../core/entity_extractor.dart';
import '../models/quick_action.dart';

/// Handler untuk intent analisis sinyal seluler (RF), uji kelayakan FWA, dan cakupan area.
class SignalCoverageHandlers {
  SignalCoverageHandlers._();

  /// Ambang batas skor kelayakan FWA (nilai tetap, tanpa pengubahan rumus)
  static const int fwaReadyScoreThreshold = 60;

  /// Handler untuk `rf_analyze`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleRf({
    TelephonySnapshot? rf,
    required ExtractedEntities entities,
  }) {
    if (rf == null || rf.servingCell == null) {
      return (
        text: '📶 **Analisis Sinyal & Kelayakan Paket**\n\n'
            'Saat ini belum ada data sinyal aktif dari perangkat.\n'
            'Silakan buka tab **"Sinyal 5G/4G"** pada Network Tools untuk mendeteksi sinyal seluler lokasi Anda secara realtime!\n\n'
            '💡 **Pedoman Cepat Lapangan:**\n'
            '• **5G+ / 4G Kuat (RSRP > -90 dBm, SINR > 12 dB):** Sangat disarankan tawarkan **XL Satu FWA Hero 100 Mbps**.\n'
            '• **Sinyal Sedang (RSRP -90 s/d -105 dBm):** FWA Standard atau cek ODP Fiber terdekat (FTTH).\n'
            '• **Sinyal Lemah (RSRP < -105 dBm):** Utamakan **XL Satu Fiber (FTTH)** jika area tercover tiang kabel.',
        actions: [
          const QuickAction(
            label: 'Daftar Paket FWA',
            intent: 'package_list',
            args: {'type': 'fwa'},
          ),
          const QuickAction(
            label: 'Daftar Paket FTTH',
            intent: 'package_list',
            args: {'type': 'ftth'},
          ),
          QuickAction.nav(
            label: 'Buka Sinyal 5G/4G',
            destination: CoachDestination.signalTab,
          ),
        ],
        metadata: {'hasSignal': false},
      );
    }

    final eval = RfAnalyzer.evaluate(rf);
    final cell = rf.servingCell!;
    final is5G = cell.cellType.contains('NR') || cell.cellType.contains('5G');
    final isFwaReady = eval.overallScore >= fwaReadyScoreThreshold;

    final sb = StringBuffer();
    sb.writeln('📶 **Hasil Analisis Cerdas Sinyal Lokasi:**\n');
    sb.writeln('• **Jaringan:** ${cell.networkType} ${is5G ? "⚡ (5G+ Ultra)" : ""}');
    sb.writeln('• **Operator:** ${rf.operatorDisplayName}');
    sb.writeln('• **RSRP:** ${cell.rsrpDisplay} | **SINR:** ${cell.sinrDisplay}');
    sb.writeln('• **Skor Kualitas:** ${eval.overallScore}/100 (Grade ${eval.scoreGrade})');
    sb.writeln('• **Status FWA:** ${isFwaReady ? "✅ SANGAT DIREKOMENDASIKAN UNTUK FWA" : "⚠️ Sinyal Kurang Kuat, Prioritaskan FTTH/Kabel"}\n');

    sb.writeln('💡 **Diagnosa Otomatis:**');
    sb.writeln('${eval.verdictSummary}\n');

    sb.writeln('🎯 **Saran Lapangan:**');
    for (final adv in eval.practicalAdvice) {
      sb.writeln('• $adv');
    }

    final actions = [
      const QuickAction(
        label: 'Script Closing FWA',
        intent: 'script_get',
        args: {'type': 'fwa'},
      ),
      const QuickAction(
        label: 'Daftar Paket FWA',
        intent: 'package_list',
        args: {'type': 'fwa'},
      ),
      QuickAction.nav(
        label: 'Cek Speed Test',
        destination: CoachDestination.speedTest,
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {
        'score': eval.overallScore,
        'fwaReady': isFwaReady,
        'networkType': cell.networkType,
      },
    );
  }

  /// Handler untuk `coverage_check`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleCoverageCheck({
    required ExtractedEntities entities,
  }) {
    final districtName = entities.district;

    final sb = StringBuffer();
    if (districtName != null && districtName.isNotEmpty) {
      sb.writeln('🗺️ **Pemeriksaan Cakupan Area: ${districtName.toUpperCase()}**\n');
      sb.writeln('Kecamatan $districtName telah terdaftar dalam basis data peta jaringan XL SATU Cilacap.');
      sb.writeln('Untuk memastikan titik tiang ODP dan status homepass persis di depan rumah calon pelanggan, silakan gunakan fitur Peta Cakupan.');
    } else {
      sb.writeln('🗺️ **Cek Cakupan & Jangkauan Jaringan Lapangan:**\n');
      sb.writeln('Anda dapat memverifikasi ketersediaan jaringan kabel optik FTTH (tiang ODP) dan perkiraan homepass langsung di aplikasi.');
    }

    sb.writeln('\n💡 **Langkah Pengecekan:**');
    sb.writeln('1. Buka menu **Peta Cakupan**.');
    sb.writeln('2. Masukkan nama jalan atau aktifkan GPS di lokasi pelanggan.');
    sb.writeln('3. Lihat titik ODP terdekat dan jarak ke rumah calon pelanggan.');

    final actions = [
      QuickAction.nav(
        label: 'Buka Peta Cakupan',
        destination: CoachDestination.coverageMap,
      ),
      const QuickAction(
        label: 'Daftar Paket FTTH',
        intent: 'package_list',
        args: {'type': 'ftth'},
      ),
      const QuickAction(
        label: 'Rekomendasi Paket Sinyal',
        intent: 'rf_analyze',
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'district': districtName},
    );
  }
}
