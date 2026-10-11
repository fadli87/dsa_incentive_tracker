import 'dart:math';
import 'coach_session.dart';
import 'entity_extractor.dart';
import 'text_normalizer.dart';

class IntentMatchResult {
  final String intentId;
  final double score;
  final List<String> suggestions; // 3 tebakan jika skor rendah/ambigu
  final bool isConfident;
  final ExtractedEntities entities;

  const IntentMatchResult({
    required this.intentId,
    required this.score,
    this.suggestions = const [],
    required this.isConfident,
    required this.entities,
  });
}

class _IntentRule {
  final String id;
  final List<String> keywords; // Bobot 1.0
  final List<String> phrases; // Bobot 3.0
  final List<String> negatives; // Bobot -2.5

  const _IntentRule({
    required this.id,
    this.keywords = const [],
    this.phrases = const [],
    this.negatives = const [],
  });
}

/// Router intent deterministik berbasis pembobotan token & Damerau-Levenshtein fuzzy matching.
class IntentRouter {
  IntentRouter._();

  static const double confidenceThreshold = 2.5;
  static const double ambiguityMargin = 0.5;

  static const double weightKeyword = 1.0;
  static const double weightPhrase = 3.0;
  static const double weightNegative = -3.0;

  static const List<_IntentRule> _rules = [
    // 1. Greet
    _IntentRule(
      id: 'greet',
      keywords: ['halo', 'hai', 'pagi', 'siang', 'malam', 'sore', 'assalamualaikum', 'semangat', 'hei'],
      phrases: ['pagi kak', 'halo coach', 'selamat pagi', 'selamat siang', 'selamat malam', 'hai coach'],
      negatives: ['haiya', 'kosongin', 'hapus', 'reset'],
    ),

    // 2. Help
    _IntentRule(
      id: 'help',
      keywords: ['bantuan', 'menu', 'tolong', 'panduan', 'fitur'],
      phrases: ['apa yang bisa kamu lakukan', 'bisa apa', 'cara pakai', 'menu bantuan', 'bisa bantu apa'],
    ),

    // 3. FWA vs FTTH (Perbedaan teknologi)
    _IntentRule(
      id: 'fwa_vs_ftth',
      keywords: ['perbedaan', 'bandingkan'],
      phrases: [
        'perbedaan fwa vs ftth',
        'perbedaan fwa dan ftth',
        'bedanya fwa sama fiber apa',
        'bedanya fwa dan ftth',
        'fwa vs ftth',
        'ftth vs fwa',
        'fwa atau ftth',
        'pilih fwa atau fiber',
        'perbedaan fiber vs fwa',
      ],
    ),

    // 4. Script Closing & Objection Handling
    _IntentRule(
      id: 'script_get',
      keywords: ['script', 'skrip', 'tawar', 'omongan', 'kata', 'handling', 'keberatan', 'penolakan', 'closing'],
      phrases: [
        'script closing',
        'script closing fwa',
        'script closing ftth',
        'script closing pelanggan rumah',
        'script rumah tangga',
        'script anak kos',
        'script kos',
        'script usaha/warkop',
        'script warkop',
        'script umkm',
        'handling kemahalan',
        'handling sudah ada wifi lain',
        'handling sudah ada wifi',
        'pelanggan bilang mikir dulu',
        'takut ribet pasang',
        'takut kontrak',
        'cara closing',
      ],
      negatives: ['hitung', 'kalkulator', 'insentif', 'sinyal', 'speed test'],
    ),

    // 5. Target Gap / Cara Kejar Target
    _IntentRule(
      id: 'target_gap',
      keywords: ['target', 'kejar', 'gap', 'tier'],
      phrases: [
        'cara capai 30 sa sebulan',
        'cara capai target',
        'cara kejar target',
        'butuh berapa lagi biar naik tier',
        'kejar target insentif',
        'tambah berapa sa lagi',
        'kejar tier',
      ],
    ),

    // 6. Best Product Mix
    _IntentRule(
      id: 'best_product_mix',
      keywords: ['optimal', 'terbanyak', 'rekomendasi', 'untung', 'cuan', 'paling'],
      phrases: [
        'produk apa yang paling gede insentifnya',
        'produk insentif tertinggi',
        'jual apa yang paling untung',
        'produk paling untung',
        'produk paling cuan',
        'jual apa yang paling cuan',
        'paket insentif terbesar',
      ],
    ),

    // 7. Pace
    _IntentRule(
      id: 'pace',
      keywords: ['hari', 'sisa', 'laju', 'pace', 'kecepatan'],
      phrases: [
        'sisa berapa hari target',
        'sisa hari bulan ini',
        'kejar target berapa hari lagi',
        'pace penjualan',
      ],
    ),

    // 8. RF / Signal Analyze
    _IntentRule(
      id: 'rf_analyze',
      keywords: ['sinyal', 'rsrp', 'sinr', '5g', '4g', 'cpe', 'dbm', 'kualitas', 'jaringan'],
      phrases: [
        'rekomendasi paket sinyal',
        'sinyal di sini bagus ga',
        'sinyal di sini',
        'sinyal fwa',
        'cek sinyal',
        'kualitas sinyal',
        'apakah sinyal bagus',
        'cocok fwa ga',
        'cek kelayakan fwa',
      ],
      negatives: ['script', 'daftar paket', 'speed test'],
    ),

    // 9. Navigation: Speed Test
    _IntentRule(
      id: 'nav_speedtest',
      keywords: ['speedtest', 'speed'],
      phrases: [
        'cek speed test',
        'speed test',
        'uji kecepatan',
        'buka speed test',
        'tes speed',
      ],
    ),

    // 10. Navigation: Coverage Map / ODP
    _IntentRule(
      id: 'nav_coverage_map',
      keywords: ['odp', 'peta', 'map', 'tiang', 'homepass'],
      phrases: [
        'cara cek odp fiber',
        'cek odp fiber',
        'buka peta cakupan',
        'peta odp',
        'cek odp',
        'lokasi odp terdekat',
      ],
    ),

    // 11. Coverage Check (District / Location)
    _IntentRule(
      id: 'coverage_check',
      keywords: ['cakupan', 'tercover', 'coverage', 'wilayah', 'daerah', 'area'],
      phrases: [
        'cek cakupan kroya',
        'cek cakupan',
        'di sini kena fiber ga',
        'area tercover fiber',
        'apakah masuk jangkauan',
      ],
    ),

    // 12. Navigation: Catalog
    _IntentRule(
      id: 'nav_catalog',
      keywords: ['katalog'],
      phrases: [
        'buka katalog',
        'buka katalog paket',
        'layar katalog',
        'lihat katalog',
      ],
    ),

    // 13. Navigation: Calculator
    _IntentRule(
      id: 'nav_calculator',
      keywords: ['kalkulator'],
      phrases: [
        'buka kalkulator',
        'buka kalkulator insentif',
        'layar kalkulator',
      ],
    ),

    // 14. Package Compare
    _IntentRule(
      id: 'package_compare',
      keywords: ['bandingkan', 'komparasi'],
      phrases: [
        'bandingkan fwa hero sama tactical ftth',
        'bandingkan paket',
        'perbandingan paket',
      ],
    ),

    // 15. Package Search (Budget / Filter)
    _IntentRule(
      id: 'package_search',
      keywords: ['murah', 'termurah', 'budget', 'harga', 'terjangkau'],
      phrases: [
        'ada paket 250rb ga',
        'ada paket 250 ribu tidak',
        'paket paling murah',
        'paket paling hemat',
        'cari paket murah',
        'paket budget',
        'paket 200 ribuan',
      ],
    ),

    // 16. Package Detail
    _IntentRule(
      id: 'package_detail',
      keywords: ['detail', 'rincian', 'spesifikasi'],
      phrases: [
        'paket fwa yang 100 mbps',
        'paket ftth 250 mbps',
        'detail paket',
        'rincian paket',
      ],
    ),

    // 17. Package List
    _IntentRule(
      id: 'package_list',
      keywords: ['daftar', 'paket', 'list', 'pilihan'],
      phrases: [
        'daftar paket fwa',
        'daftar paket ftth',
        'daftar paket fmc',
        'daftar paket pxgy',
        'daftar paket combo',
        'daftar paket xl satu',
        'daftar paket',
        'pilihan paket',
      ],
      negatives: ['hitung', 'insentif', 'script'],
    ),

    // 18. Incentive Scheme Info
    _IntentRule(
      id: 'incentive_scheme_info',
      keywords: ['skema', 'aturan', 'tabel', 'tiering', 'kebijakan'],
      phrases: [
        'gimana skema insentif',
        'bagaimana skema insentif',
        'skema insentif',
        'skema komisi',
        'aturan insentif',
        'tabel insentif',
        'info skema',
      ],
      negatives: ['hitung'],
    ),

    // 19. Incentive Calc
    _IntentRule(
      id: 'incentive_calc',
      keywords: ['hitung', 'kalkulasi', 'simulasi', 'insentif', 'bonus', 'komisi'],
      phrases: [
        'hitung insentif 15 sa',
        'hitung insentif 30 sa',
        'hitung insentif',
        'simulasi insentif',
        'berapa bonus saya bulan ini',
        'berapa bonus saya',
        'insentif elite',
        'insentif ojt',
        'insentif pro',
        'simulasi insentif paket ini',
      ],
      negatives: ['skema', 'script', 'daftar paket'],
    ),

    // 20. WA Draft
    _IntentRule(
      id: 'wa_draft',
      keywords: ['draf', 'draft', 'template', 'wa', 'whatsapp', 'chat'],
      phrases: [
        'draf wa buat penawaran fwa',
        'draf wa',
        'draft wa',
        'template wa',
        'pesan whatsapp',
      ],
    ),
  ];

  /// Route query ternormalisasi ke IntentMatchResult
  static IntentMatchResult route(String normalizedQuery, {CoachSession? session}) {
    final cleanQuery = normalizedQuery.trim();
    if (cleanQuery.isEmpty) {
      return IntentMatchResult(
        intentId: 'unknown',
        score: 0.0,
        isConfident: false,
        entities: const ExtractedEntities(),
      );
    }

    // Ekstraksi entitas dari teks
    final entities = EntityExtractor.extract(cleanQuery, previous: session?.lastEntities);
    final tokens = TextNormalizer.tokenize(cleanQuery);

    // Hitung skor untuk tiap intent rule
    final Map<String, double> scores = {};

    for (final rule in _rules) {
      double score = 0.0;

      // 1. Phrase match (exact whole phrase match)
      for (final p in rule.phrases) {
        final normP = TextNormalizer.normalize(p);
        if (cleanQuery == normP) {
          score += weightPhrase * 2.0; // Perfect exact match
        } else if (cleanQuery.contains(normP)) {
          score += weightPhrase;
        }
      }

      // 2. Keyword exact / fuzzy token match
      for (final kw in rule.keywords) {
        final normKw = TextNormalizer.normalize(kw);
        for (final t in tokens) {
          if (t == normKw) {
            score += weightKeyword;
          } else if (_isFuzzyMatch(t, normKw)) {
            score += weightKeyword * 0.75;
          }
        }
      }

      // 3. Negative keyword penalty
      for (final neg in rule.negatives) {
        final normNeg = TextNormalizer.normalize(neg);
        for (final t in tokens) {
          if (t == normNeg) {
            score += weightNegative;
          }
        }
      }

      // 4. Entity-based Contextual Boosts
      if (rule.id == 'incentive_calc') {
        if (entities.totalSa != null || entities.hasProductCounts) {
          score += 3.0;
        }
        if (entities.position != null) {
          score += 1.5;
        }
      } else if (rule.id == 'package_list' || rule.id == 'package_detail' || rule.id == 'package_search') {
        if (entities.speedMbps != null) {
          if (rule.id == 'package_detail') score += 2.0;
        }
        if (entities.budgetRupiah != null) {
          if (rule.id == 'package_search') score += 3.0;
        }
        if (entities.packageType != null) {
          if (rule.id == 'package_list') score += 1.5;
        }
      } else if (rule.id == 'coverage_check') {
        if (entities.district != null) {
          score += 3.5;
        }
      } else if (rule.id == 'script_get') {
        if (entities.segment != null || entities.objection != null) {
          score += 2.5;
        }
      } else if (rule.id == 'rf_analyze') {
        if (cleanQuery.contains('rsrp') || cleanQuery.contains('sinr') || cleanQuery.contains('5g')) {
          score += 3.0;
        }
      }

      // 5. Follow-up Contextual Boost (jika query pendek dan ada lastIntent)
      if (session?.lastIntent != null && tokens.length <= 4) {
        if (rule.id == session!.lastIntent) {
          score += 1.5;
        }
      }

      scores[rule.id] = score;
    }

    // Urutkan skor tertinggi
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topMatch = sortedEntries.first;
    final runnerUp = sortedEntries.length > 1 ? sortedEntries[1] : null;

    final isConfident = topMatch.value >= confidenceThreshold &&
        (runnerUp == null || (topMatch.value - runnerUp.value) >= ambiguityMargin);

    // Kumpulkan 3 saran teratas jika ambigu atau unknown
    final suggestions = sortedEntries
        .where((e) => e.value > 0.5)
        .take(3)
        .map((e) => _getIntentSuggestionLabel(e.key))
        .where((label) => label.isNotEmpty)
        .toList();

    if (!isConfident && topMatch.value < 1.0) {
      return IntentMatchResult(
        intentId: 'unknown',
        score: topMatch.value,
        suggestions: const [
          'Daftar Paket XL Satu',
          'Hitung Insentif',
          'Rekomendasi Paket Sinyal',
        ],
        isConfident: false,
        entities: entities,
      );
    }

    return IntentMatchResult(
      intentId: topMatch.key,
      score: topMatch.value,
      suggestions: suggestions,
      isConfident: isConfident,
      entities: entities,
    );
  }

  /// Damerau-Levenshtein distance untuk pencocokan fuzzy aman
  static bool _isFuzzyMatch(String token, String keyword) {
    if (token.length < 5 || keyword.length < 5) return false;
    final dist = _damerauLevenshtein(token, keyword);
    if (token.length >= 8 && dist <= 2) return true;
    if (token.length >= 5 && dist <= 1) return true;
    return false;
  }

  static int _damerauLevenshtein(String source, String target) {
    final int m = source.length;
    final int n = target.length;
    final List<List<int>> d = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final int cost = source[i - 1] == target[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1, // deletion
          d[i][j - 1] + 1, // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce(min);

        if (i > 1 &&
            j > 1 &&
            source[i - 1] == target[j - 2] &&
            source[i - 2] == target[j - 1]) {
          d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1); // transposition
        }
      }
    }

    return d[m][n];
  }

  static String _getIntentSuggestionLabel(String intentId) {
    switch (intentId) {
      case 'greet':
        return 'Sapa AI Coach';
      case 'help':
        return 'Menu Bantuan';
      case 'fwa_vs_ftth':
        return 'Perbedaan FWA vs FTTH';
      case 'script_get':
        return 'Script Closing Sales';
      case 'target_gap':
        return 'Cara Kejar Target';
      case 'best_product_mix':
        return 'Produk Insentif Tertinggi';
      case 'pace':
        return 'Sisa Hari Target';
      case 'rf_analyze':
        return 'Rekomendasi Paket Sinyal';
      case 'nav_speedtest':
        return 'Cek Speed Test';
      case 'nav_coverage_map':
        return 'Peta ODP Fiber';
      case 'coverage_check':
        return 'Cek Cakupan Area';
      case 'package_list':
        return 'Daftar Paket XL Satu';
      case 'package_detail':
        return 'Detail Paket';
      case 'package_search':
        return 'Cari Paket Murah';
      case 'package_compare':
        return 'Bandingkan Paket';
      case 'incentive_scheme_info':
        return 'Skema Insentif 2026';
      case 'incentive_calc':
        return 'Hitung Insentif SA';
      case 'wa_draft':
        return 'Draf WhatsApp Penawaran';
      default:
        return '';
    }
  }
}
