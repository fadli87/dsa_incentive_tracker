import 'package:intl/intl.dart';
import '../../core/catalog/package_catalog.dart';
import '../../core/models/calculator_models.dart';
import '../core/target_coach_engine.dart';
import '../models/quick_action.dart';

/// Handler untuk intent navigasi halaman, sapaan, bantuan, simulasi target gap, best product mix, pace, dan draf WA.
class NavigationHandlers {
  NavigationHandlers._();

  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Sapaan ramah
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleGreet() {
    return (
      text: 'Halo! Semangat aktivitas jualan hari ini! 🚀\n'
          'Ada yang bisa saya bantu terkait penawaran paket, cek sinyal & ODP, atau simulasi target insentif Anda?',
      actions: const [
        QuickAction(
          label: 'Rekomendasi Paket Sinyal',
          intent: 'rf_analyze',
        ),
        QuickAction(
          label: 'Cara Kejar Target Insentif',
          intent: 'target_gap',
        ),
        QuickAction(
          label: 'Script Closing Rumah',
          intent: 'script_get',
          args: {'segment': 'rumah'},
        ),
        QuickAction(
          label: 'Daftar Paket FTTH',
          intent: 'package_list',
          args: {'type': 'ftth'},
        ),
      ],
      metadata: {'type': 'greet'},
    );
  }

  /// Menu Bantuan
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleHelp() {
    return (
      text: '🤖 **AURA Sales & Network Coach — Menu Bantuan:**\n\n'
          'Saya dapat membantu Anda menyelesaikan berbagai tugas lapangan secara offline:\n'
          '1. **Kalkulasi Insentif**: Hitung estimasi bonus per produk dan simulasi kenaikan tier progresif.\n'
          '2. **Analisis Sinyal (RF)**: Evaluasi kelayakan FWA vs FTTH berdasarkan RSRP & SINR.\n'
          '3. **Katalog Paket**: Info harga, kecepatan, biaya instalasi, dan klasifikasi bucket komisi.\n'
          '4. **Script Closing**: Kalimat penawaran ke calon pelanggan rumah, anak kos, dan warkop.\n'
          '5. **Handling Keberatan**: Tips mengatasi penolakan "kemahalan", "sudah ada WiFi", atau "mikir dulu".\n'
          '6. **Navigasi Cepat**: Langsung buka Speed Test, Peta Cakupan ODP, dan Kalkulator.',
      actions: const [
        QuickAction(
          label: 'Hitung Insentif 15 SA',
          intent: 'incentive_calc',
          args: {'totalSa': 15},
        ),
        QuickAction(
          label: 'Daftar Paket FWA',
          intent: 'package_list',
          args: {'type': 'fwa'},
        ),
        QuickAction(
          label: 'Rekomendasi Paket Sinyal',
          intent: 'rf_analyze',
        ),
      ],
      metadata: {'type': 'help'},
    );
  }

  /// Navigasi ke Speed Test
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleNavSpeedtest() {
    return (
      text: '🚀 **Uji Kecepatan Jaringan (Speed Test)**\n\n'
          'Gunakan fitur Speed Test untuk mengukur kecepatan Download, Upload, dan Ping latensi secara realtime saat demonstrasi ke calon pelanggan.\n\n'
          'Klik tombol di bawah untuk membuka layar Speed Test:',
      actions: [
        QuickAction.nav(
          label: 'Buka Speed Test',
          destination: CoachDestination.speedTest,
        ),
        const QuickAction(
          label: 'Rekomendasi Paket Sinyal',
          intent: 'rf_analyze',
        ),
      ],
      metadata: {'destination': CoachDestination.speedTest.name},
    );
  }

  /// Navigasi ke Peta Cakupan / ODP
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleNavCoverageMap() {
    return (
      text: '🗺️ **Peta Cakupan Jaringan & Titik ODP**\n\n'
          'Fitur Peta Cakupan memungkinkan Anda memeriksa radius tiang ODP fiber terdekat dan status homepass di lapangan.\n\n'
          'Klik tombol di bawah untuk membuka Peta Cakupan:',
      actions: [
        QuickAction.nav(
          label: 'Buka Peta Cakupan',
          destination: CoachDestination.coverageMap,
        ),
        const QuickAction(
          label: 'Daftar Paket FTTH',
          intent: 'package_list',
          args: {'type': 'ftth'},
        ),
      ],
      metadata: {'destination': CoachDestination.coverageMap.name},
    );
  }

  /// Navigasi ke Katalog
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleNavCatalog() {
    return (
      text: '📦 **Katalog Resmi Paket Jualan**\n\n'
          'Lihat seluruh varian paket Internet Only, FMC Kuota HP, Advance Payment PXGY, dan Combo TV beserta rincian OWS.\n\n'
          'Klik tombol di bawah untuk membuka Katalog:',
      actions: [
        QuickAction.nav(
          label: 'Buka Layar Katalog',
          destination: CoachDestination.catalog,
        ),
        const QuickAction(
          label: 'Daftar Paket FWA',
          intent: 'package_list',
          args: {'type': 'fwa'},
        ),
      ],
      metadata: {'destination': CoachDestination.catalog.name},
    );
  }

  /// Navigasi ke Kalkulator
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleNavCalculator() {
    return (
      text: '💰 **Kalkulator Insentif Detail**\n\n'
          'Lakukan simulasi terperinci untuk seluruh posisi (OJT, Pro, Elite, SPV) lengkap dengan Survival M3/M5 dan Quarterly Bonus.\n\n'
          'Klik tombol di bawah untuk membuka Kalkulator:',
      actions: [
        QuickAction.nav(
          label: 'Buka Layar Kalkulator',
          destination: CoachDestination.calculator,
        ),
        const QuickAction(
          label: 'Hitung Insentif 15 SA',
          intent: 'incentive_calc',
          args: {'totalSa': 15},
        ),
      ],
      metadata: {'destination': CoachDestination.calculator.name},
    );
  }

  /// Target Gap (Strategi Kejar Target)
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleTargetGap({
    Map<String, int>? currentCalcState,
    PositionType position = PositionType.elite,
  }) {
    final gap = TargetCoachEngine.calculateGap(
      currentCalcState: currentCalcState,
      position: position,
    );

    final actions = [
      if (gap.nextTierSa != null)
        QuickAction(
          label: 'Hitung Insentif ${gap.nextTierSa} SA',
          intent: 'incentive_calc',
          args: {'totalSa': gap.nextTierSa},
        ),
      const QuickAction(
        label: 'Produk Insentif Tertinggi',
        intent: 'best_product_mix',
      ),
      const QuickAction(
        label: 'Daftar Paket FTTH',
        intent: 'package_list',
        args: {'type': 'ftth'},
      ),
    ];

    return (
      text: TargetCoachEngine.formatTargetGap(gap),
      actions: actions,
      metadata: {
        'topic': 'target_gap',
        'currentSa': gap.currentSa,
        'neededForNextTier': gap.neededForNextTier,
      },
    );
  }

  /// Best Product Mix
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleBestProductMix({
    Map<String, int>? currentCalcState,
    PositionType position = PositionType.elite,
  }) {
    final rankings = TargetCoachEngine.rankProductMix(
      currentCalcState: currentCalcState,
      position: position,
    );

    final actions = [
      const QuickAction(
        label: 'Daftar Paket FTTH',
        intent: 'package_list',
        args: {'type': 'ftth'},
      ),
      const QuickAction(
        label: 'Daftar Paket FWA',
        intent: 'package_list',
        args: {'type': 'fwa'},
      ),
      const QuickAction(
        label: 'Cara Kejar Target',
        intent: 'target_gap',
      ),
    ];

    return (
      text: TargetCoachEngine.formatProductMix(rankings),
      actions: actions,
      metadata: {'topic': 'best_product_mix'},
    );
  }

  /// Pace Target
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handlePace({
    int currentSa = 0,
    DateTime? now,
  }) {
    final formattedPace = TargetCoachEngine.calculatePace(
      currentSa: currentSa,
      now: now,
    );

    final actions = [
      const QuickAction(
        label: 'Cara Kejar Target',
        intent: 'target_gap',
      ),
      const QuickAction(
        label: 'Hitung Insentif 15 SA',
        intent: 'incentive_calc',
        args: {'totalSa': 15},
      ),
    ];

    return (
      text: formattedPace,
      actions: actions,
      metadata: {'topic': 'pace'},
    );
  }

  /// Draf WhatsApp
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleWaDraft() {
    final ftthSample = PackageCatalog.findById('ftth-hero-250-mbps')!;
    final fwaSample = PackageCatalog.findById('fwa-hero-100-mbps')!;

    final sb = StringBuffer();
    sb.writeln('📲 **Draf Pesan WhatsApp Siap Salin ke Calon Pelanggan:**\n');
    sb.writeln('```');
    sb.writeln('Halo Bapak/Ibu,');
    sb.writeln('Perkenalkan saya dari Tim Resmi XL SATU CILACAP.');
    sb.writeln('');
    sb.writeln('Izin menginfokan promo internet rumah super kencang & hemat:');
    sb.writeln('🚀 ${ftthSample.title} (${_currencyFmt.format(ftthSample.price)}/bln Exc. PPN)');
    sb.writeln('🚀 ${fwaSample.title} (${_currencyFmt.format(fwaSample.price)}/bln Exc. PPN)');
    sb.writeln('🎁 GRATIS Biaya Instalasi + Bonus Kuota HP Sekeluarga!');
    sb.writeln('');
    sb.writeln('Jika berkenan, boleh saya bantu cekkan titik jangkauan tiang jaringan ke rumah Bapak/Ibu?');
    sb.writeln('Terima kasih banyak!');
    sb.writeln('```\n');
    sb.writeln('💡 *Tips:* Anda juga bisa menyalin rincian per paket langsung dari tab Katalog.');

    final actions = [
      QuickAction.nav(
        label: 'Buka Katalog Paket',
        destination: CoachDestination.catalog,
      ),
      const QuickAction(
        label: 'Daftar Paket FWA',
        intent: 'package_list',
        args: {'type': 'fwa'},
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'type': 'wa_draft'},
    );
  }

  /// Fallback Unknown
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleUnknown({
    List<String> suggestions = const [],
  }) {
    final sb = StringBuffer();
    sb.writeln('Maaf, saya belum memahami pertanyaan tersebut secara spesifik.');
    sb.writeln('Berikut opsi bantuan yang paling sering digunakan:\n');
    sb.writeln('1. **Analisis Sinyal & FWA**: Cek kualitas RSRP/SINR di lokasi calon pelanggan.');
    sb.writeln('2. **Kalkulasi Insentif**: Masukkan jumlah SA untuk melihat estimasi bonus cair.');
    sb.writeln('3. **Tips Closing Lapangan**: Cara mengatasi penolakan pelanggan "kemahalan" atau "sudah ada WiFi".');
    sb.writeln('4. **Katalog XL Satu**: Info harga, kecepatan, dan paket promo.');

    final actions = [
      const QuickAction(
        label: 'Daftar Paket XL Satu',
        intent: 'package_list',
      ),
      const QuickAction(
        label: 'Hitung Insentif 15 SA',
        intent: 'incentive_calc',
        args: {'totalSa': 15},
      ),
      const QuickAction(
        label: 'Rekomendasi Paket Sinyal',
        intent: 'rf_analyze',
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'type': 'unknown'},
    );
  }
}
