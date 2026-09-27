import '../../network/models/cell_signal_info.dart';

/// Ultra-lightweight Offline AI Sales & RF Expert Coach (< 150 KB memory footprint)
/// Runs 100% locally on-device without internet or external heavy weights.
class SalesAiCoach {
  static const String welcomeMessage =
      'Halo! Saya **AURA Sales & Network Coach** 🤖⚡\n\n'
      'Saya siap membantu Anda:\n'
      '• 📶 Rekomendasi paket berdasarkan sinyal (FWA vs FTTH)\n'
      '• 💰 Simulasi target & hitung potensi insentif\n'
      '• 🎯 Strategi & script closing ke calon pelanggan\n'
      '• 📋 Info lengkap paket XL Satu, FWA, FMC, & PXGY\n\n'
      'Ketik pertanyaan Anda atau pilih topik cepat di bawah ini!';

  static const List<String> defaultQuickReplies = [
    'Rekomendasi Paket Sinyal',
    'Cara Kejar Target Insentif',
    'Script Closing Pelanggan Rumah',
    'Perbedaan FWA vs FTTH',
    'Daftar Paket XL Satu',
  ];

  /// Process user query and return intelligent response with quick replies and metadata
  static AiCoachResponse reply(String query, {TelephonySnapshot? currentRfSignal}) {
    final lower = query.toLowerCase().trim();

    // 1. RF Signal & Coverage Context
    if (lower.contains('sinyal') ||
        lower.contains('sinyal fwa') ||
        lower.contains('rekomendasi paket sinyal') ||
        lower.contains('coverage') ||
        lower.contains('5g') ||
        lower.contains('rsrp') ||
        lower.contains('sinr') ||
        lower.contains('fwa')) {
      return _handleRfQuery(currentRfSignal, lower);
    }

    // 2. Incentive & Target Calculation
    if (lower.contains('insentif') ||
        lower.contains('target') ||
        lower.contains('kejar target') ||
        lower.contains('hitung') ||
        lower.contains('skema') ||
        lower.contains('spv') ||
        lower.contains('dsa')) {
      return _handleIncentiveQuery(lower);
    }

    // 3. Sales Closing Script / Objection Handling
    if (lower.contains('script') ||
        lower.contains('closing') ||
        lower.contains('cara tawar') ||
        lower.contains('kemahalan') ||
        lower.contains('ragu') ||
        lower.contains('rumah') ||
        lower.contains('kos') ||
        lower.contains('umkm') ||
        lower.contains('objection')) {
      return _handleScriptQuery(lower);
    }

    // 4. Product Catalog & Packages
    if (lower.contains('paket') ||
        lower.contains('fwa') ||
        lower.contains('ftth') ||
        lower.contains('fmc') ||
        lower.contains('pxgy') ||
        lower.contains('xl satu') ||
        lower.contains('harga') ||
        lower.contains('kecepatan')) {
      return _handleProductQuery(lower);
    }

    // 5. General Greeting & Fallback
    if (lower.contains('halo') || lower.contains('hai') || lower.contains('pagi') || lower.contains('siang') || lower.contains('malam')) {
      return const AiCoachResponse(
        text: 'Halo! Semangat jualan hari ini! 🚀\nAda yang bisa saya bantu terkait penawaran paket, cek sinyal, atau kalkulasi insentif Anda?',
        quickReplies: defaultQuickReplies,
      );
    }

    // Default Smart Assistant Fallback
    return const AiCoachResponse(
      text: 'Berikut opsi bantuan yang paling sering digunakan:\n\n'
          '1. **Analisis Sinyal & FWA**: Cek kelayakan RSRP/SINR di lokasi calon pelanggan.\n'
          '2. **Simulasi Insentif**: Masukkan jumlah SA untuk melihat estimasi bonus cair.\n'
          '3. **Tips Closing Lapangan**: Cara mengatasi penolakan pelanggan "lagi mikir-mikir" atau "udah ada WiFi lain".\n'
          '4. **Katalog XL Satu**: Perbandingan kecepatan & harga paket.',
      quickReplies: defaultQuickReplies,
    );
  }

  // --- Handlers ---

  static AiCoachResponse _handleRfQuery(TelephonySnapshot? rf, String query) {
    if (rf == null || rf.servingCell == null) {
      return const AiCoachResponse(
        text: '📶 **Analisis Sinyal & Kelayakan Paket**\n\n'
            'Saat ini belum ada data sinyal aktif dari perangkat.\n'
            'Silakan buka tab **"Sinyal 5G/4G"** pada Network Tools untuk mendeteksi sinyal seluler lokasi Anda secara realtime!\n\n'
            '💡 **Pedoman Cepat Lapangan:**\n'
            '• **5G+ / 4G Kuat (RSRP > -90 dBm, SINR > 12 dB):** Sangat disarankan tawarkan **XL Satu FWA Prime / Ultra** (Kecepatan up to 100-300 Mbps).\n'
            '• **Sinyal Sedang (RSRP -90 s/d -105 dBm):** FWA Standard (30-50 Mbps) atau cek ODP Fiber terdekat (FTTH).\n'
            '• **Sinyal Lemah (RSRP < -105 dBm):** Utamakan **XL Satu Fiber (FTTH)** jika area tercover tiang kabel.',
        quickReplies: [
          'Daftar Paket FWA',
          'Daftar Paket FTTH',
          'Cara Cek ODP Fiber',
        ],
      );
    }

    final eval = RfAnalyzer.evaluate(rf);
    final cell = rf.servingCell!;
    final is5G = cell.cellType.contains('NR') || cell.cellType.contains('5G');
    final isFwaReady = eval.overallScore >= 60;

    return AiCoachResponse(
      text: '📶 **Hasil Analisis Cerdas Sinyal Lokasi:**\n\n'
          '• **Jaringan:** ${cell.networkType} ${is5G ? "⚡ (5G+ Ultra)" : ""}\n'
          '• **Operator:** ${rf.operatorDisplayName}\n'
          '• **RSRP:** ${cell.rsrpDisplay} | **SINR:** ${cell.sinrDisplay}\n'
          '• **Skor Kualitas:** ${eval.overallScore}/100 (Grade ${eval.scoreGrade})\n'
          '• **Status FWA:** ${isFwaReady ? "✅ SANGAT DIREKOMENDASIKAN UNTUK FWA" : "⚠️ Sinyal Kurang Kuat, Prioritaskan FTTH/Kabel"}\n\n'
          '💡 **Diagnosa Otomatis:**\n${eval.verdictSummary}\n\n'
          '🎯 **Saran Lapangan:**\n${eval.practicalAdvice.join("\n• ")}',
      quickReplies: [
        'Script Closing FWA',
        'Simulasi Insentif Paket Ini',
        'Cek Speed Test',
      ],
      metadata: {
        'score': eval.overallScore,
        'fwaReady': isFwaReady,
        'networkType': cell.networkType,
      },
    );
  }

  static AiCoachResponse _handleIncentiveQuery(String query) {
    return const AiCoachResponse(
      text: '💰 **Panduan Skema Insentif September 2026**\n\n'
          '**1. DSA (Direct Sales Agent):**\n'
          '• **Tier 1 (1 - 10 SA):** Rp 50.000 / SA\n'
          '• **Tier 2 (11 - 25 SA):** Rp 75.000 / SA (Akselerasi)\n'
          '• **Tier 3 (26+ SA):** Rp 100.000 / SA (Super Star Bonus)\n'
          '• *Booster*: Tambahan insentif khusus paket Ultimate/Family & FWA Prime!\n\n'
          '**2. SPV (Supervisor Area):**\n'
          '• Dihitung dari total Achievement Tim vs Target Area (Bracket 80%, 100%, 120%+).\n'
          '• Dapatkan Override bonus per active selling agent.\n\n'
          '💡 *Tip Juara*: Fokus closing 1 SA per hari (25-30 SA/bulan) untuk mencapai Tier 3 dengan total insentif > Rp 2.500.000+!',
      quickReplies: [
        'Cara Capai 30 SA Sebulan',
        'Hitung Insentif 15 SA',
        'Hitung Insentif 30 SA',
      ],
    );
  }

  static AiCoachResponse _handleScriptQuery(String query) {
    if (query.contains('kos') || query.contains('kost')) {
      return const AiCoachResponse(
        text: '🗣️ **Script Closing: Anak Kos / Pemilik Kos**\n\n'
            '*"Permisi Kak/Ibu, mau tanya untuk internetan di sini sering lemot pas jam malam gak? Kebetulan XL Satu lagi ada promo kuota bersama tanpa tarik kabel ribet (FWA Plug & Play).*\n\n'
            '*Tinggal colok listrik, seisi kosan langsung dapet WiFi kenceng plus kuota HP keluarga/teman sampai 4 nomor! Nggak perlu nunggu teknisi bor dinding kak. Mau saya bantu pasangkan hari ini?"*',
        quickReplies: ['Script Rumah Tangga', 'Script Usaha/Warkop', 'Handling: Kemahalan'],
      );
    }

    if (query.contains('kemahalan') || query.contains('mahal')) {
      return const AiCoachResponse(
        text: '🛡️ **Handling Objection: "Harganya kemahalan mas/mbak"**\n\n'
            '*"Saya paham banget Pak/Bu. Tapi kalau dihitung-hitung, bapak/ibu sekeluarga beli pulsa & kuota HP per orang habis 50-75rb dikali 4 orang udah 250-300rb sebulan, belum lagi WiFi rumahnya.*\n\n'
            '*Paket XL Satu ini sistemnya FMC (satu tagihan untuk WiFi rumah UNLIMITED + Kuota Bersama 4 nomor HP). Jadi jatuhnya justru MENGHEMAT pengeluaran internet keluarga sampai 40%! Mau coba yang paket hemat dulu?"*',
        quickReplies: ['Daftar Paket FMC', 'Script Rumah Tangga'],
      );
    }

    // Default Rumah Tangga
    return const AiCoachResponse(
      text: '🗣️ **Script Closing: Calon Pelanggan Rumah Tangga**\n\n'
          '*"Selamat pagi/siang Bapak/Ibu, salam kenal saya dari XL Satu. Izin numpang info promo spesial warga komplek sini.*\n\n'
          '*Di rumah putra-putrinya sering streaming YouTube/sekolah online gak Bu? Bulan ini ada program Gratis Biaya Pasang + Gratis Upgrade Kecepatan + Bonus Kuota HP Sekeluarga.*\n\n'
          '*Boleh saya cekkan titik jaringan rumah bapak/ibu sebentar? Cuma butuh 1 menit kok Pak/Bu."*',
      quickReplies: ['Handling: Sudah Ada WiFi Lain', 'Handling: Kemahalan', 'Script Anak Kos'],
    );
  }

  static AiCoachResponse _handleProductQuery(String query) {
    return const AiCoachResponse(
      text: '📦 **Katalog Lengkap Paket XL Satu (FTTH & FWA):**\n\n'
          '**A. XL Satu Fiber (FTTH - Kabel Optik):**\n'
          '1. **Smart (30 Mbps):** Rp 200rb-an/bln + Kuota HP 15GB (2 nomor)\n'
          '2. **Family (50 Mbps):** Rp 270rb-an/bln + Kuota HP 25GB (2 nomor) *(Best Seller!)*\n'
          '3. **Super User (100 Mbps):** Rp 380rb-an/bln + Kuota HP 50GB (3 nomor)\n'
          '4. **Ultimate (300 Mbps):** Rp 600rb-an/bln + Kuota HP 100GB (4 nomor)\n\n'
          '**B. XL Satu FWA (Wireless 4G/5G Home Router):**\n'
          '• **FWA Lite (Up to 30 Mbps):** Solusi cepat tanpa nunggu ODP kabel.\n'
          '• **FWA Prime (Up to 100 Mbps):** Khusus area 5G / 4G Carrier Aggregation kencang.\n\n'
          '**C. Add-on PXGY (Paket Extra Kuota HP):**\n'
          '• Ekstra kuota bersama mulai 10GB s/d 50GB untuk anggota keluarga tambahan.',
      quickReplies: [
        'Rekomendasi Paket Sinyal',
        'Script Closing Pelanggan Rumah',
        'Simulasi Insentif',
      ],
    );
  }
}

class AiCoachResponse {
  final String text;
  final List<String>? quickReplies;
  final Map<String, dynamic>? metadata;

  const AiCoachResponse({
    required this.text,
    this.quickReplies,
    this.metadata,
  });
}
