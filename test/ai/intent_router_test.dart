import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/ai/core/intent_router.dart';
import 'package:dsa_incentive_tracker/ai/core/text_normalizer.dart';
import 'package:dsa_incentive_tracker/core/models/calculator_models.dart';

void main() {
  group('IntentRouter & TextNormalizer Tests (Seed & Regression Suite)', () {
    test('TextNormalizer: normalisasi slang dan kata bilangan Indonesia', () {
      expect(TextNormalizer.normalize('brp insentif 15 sa'), equals('berapa insentif 15 sa'));
      expect(TextNormalizer.normalize('lima belas sa'), equals('15 sa'));
      expect(TextNormalizer.normalize('dua puluh lima sa'), equals('25 sa'));
      expect(TextNormalizer.normalize('ada paket 250rb ga'), equals('ada paket 250 ribu tidak'));
      expect(TextNormalizer.normalize('1,2jt'), equals('1.2 juta'));
      expect(TextNormalizer.normalize('gimana skema insentif'), equals('bagaimana skema insentif'));
    });

    final testCases = <Map<String, dynamic>>[
      // --- 11 KASUS REGRESI DARI TABEL BAGIAN 2 ---
      {'query': 'Daftar Paket FWA', 'expectedIntent': 'package_list', 'expectedType': 'fwa'},
      {'query': 'Script Closing FWA', 'expectedIntent': 'script_get'},
      {'query': 'Perbedaan FWA vs FTTH', 'expectedIntent': 'fwa_vs_ftth'},
      {'query': 'Hitung Insentif 15 SA', 'expectedIntent': 'incentive_calc', 'expectedSa': 15},
      {'query': 'Hitung Insentif 30 SA', 'expectedIntent': 'incentive_calc', 'expectedSa': 30},
      {'query': 'Cara Capai 30 SA Sebulan', 'expectedIntent': 'target_gap'},
      {'query': 'Cara Cek ODP Fiber', 'expectedIntent': 'nav_coverage_map'},
      {'query': 'Cek Speed Test', 'expectedIntent': 'nav_speedtest'},
      {'query': 'Handling: Sudah Ada WiFi Lain', 'expectedIntent': 'script_get', 'expectedObjection': 'sudah_ada_wifi'},
      {'query': 'Script Usaha/Warkop', 'expectedIntent': 'script_get', 'expectedSegment': 'warkop'},
      {'query': 'Simulasi Insentif Paket Ini', 'expectedIntent': 'incentive_calc'},

      // --- SEED TABLE BAGIAN 6 ---
      {'query': 'daftar paket fwa', 'expectedIntent': 'package_list', 'expectedType': 'fwa'},
      {'query': 'Daftar Paket FTTH', 'expectedIntent': 'package_list', 'expectedType': 'ftth'},
      {'query': 'paket fwa yang 100 mbps', 'expectedIntent': 'package_detail', 'expectedSpeed': 100},
      {'query': 'ada paket 250rb ga', 'expectedIntent': 'package_search', 'expectedBudget': 250000},
      {'query': 'paket paling murah', 'expectedIntent': 'package_search'},
      {'query': 'bandingin fwa hero sama tactical ftth', 'expectedIntent': 'package_compare'},
      {'query': 'bedanya fwa sama fiber apa', 'expectedIntent': 'fwa_vs_ftth'},
      {'query': 'hitung insentif 5 fwa 2 f100', 'expectedIntent': 'incentive_calc', 'expectedFwa': 5, 'expectedF100': 2},
      {'query': 'insentif elite kalo 12 sa berapa', 'expectedIntent': 'incentive_calc', 'expectedPosition': PositionType.elite, 'expectedSa': 12},
      {'query': 'insentif ojt 8 sa', 'expectedIntent': 'incentive_calc', 'expectedPosition': PositionType.ojt, 'expectedSa': 8},
      {'query': 'berapa bonus saya bulan ini', 'expectedIntent': 'incentive_calc'},
      {'query': 'gimana skema insentif', 'expectedIntent': 'incentive_scheme_info'},
      {'query': 'butuh berapa lagi biar naik tier', 'expectedIntent': 'target_gap'},
      {'query': 'produk apa yang paling gede insentifnya', 'expectedIntent': 'best_product_mix'},
      {'query': 'sisa berapa hari target', 'expectedIntent': 'pace'},
      {'query': 'rekomendasi paket sinyal', 'expectedIntent': 'rf_analyze'},
      {'query': 'sinyal di sini bagus ga', 'expectedIntent': 'rf_analyze'},
      {'query': 'rsrp -95 sinr 8 cocok fwa ga', 'expectedIntent': 'rf_analyze'},
      {'query': 'cek speed test', 'expectedIntent': 'nav_speedtest'},
      {'query': 'cara cek odp fiber', 'expectedIntent': 'nav_coverage_map'},
      {'query': 'cek cakupan kroya', 'expectedIntent': 'coverage_check', 'expectedDistrict': 'kroya'},
      {'query': 'di sini kena fiber ga', 'expectedIntent': 'coverage_check'},
      {'query': 'script closing fwa', 'expectedIntent': 'script_get'},
      {'query': 'script closing pelanggan rumah', 'expectedIntent': 'script_get', 'expectedSegment': 'rumah'},
      {'query': 'script anak kos', 'expectedIntent': 'script_get', 'expectedSegment': 'kos'},
      {'query': 'Script Usaha/Warkop', 'expectedIntent': 'script_get', 'expectedSegment': 'warkop'},
      {'query': 'handling kemahalan', 'expectedIntent': 'script_get', 'expectedObjection': 'mahal'},
      {'query': 'pelanggan bilang mikir dulu', 'expectedIntent': 'script_get', 'expectedObjection': 'mikir'},
      {'query': 'takut ribet pasang', 'expectedIntent': 'script_get', 'expectedObjection': 'ribet'},
      {'query': 'draf wa buat penawaran fwa', 'expectedIntent': 'wa_draft'},
      {'query': 'halo', 'expectedIntent': 'greet'},
      {'query': 'pagi kak', 'expectedIntent': 'greet'},
      {'query': 'apa yang bisa kamu lakukan', 'expectedIntent': 'help'},
      {'query': 'asdfgh', 'expectedIntent': 'unknown'},

      // --- KASUS SUBSTRING TRICKY (Rule 4.4 & 4.5) ---
      {'query': 'kosongin chat', 'forbiddenIntent': 'script_get'}, // kata kosongin tidak boleh cocok script kos
      {'query': 'haiya', 'forbiddenIntent': 'greet'}, // kata haiya tidak boleh cocok greet

      // --- TAMBAHAN SKENARIO LAPANGAN HINGGA 60+ ---
      {'query': 'daftar paket fmc', 'expectedIntent': 'package_list', 'expectedType': 'fmc'},
      {'query': 'daftar paket pxgy', 'expectedIntent': 'package_list', 'expectedType': 'pxgy'},
      {'query': 'daftar paket combo tv', 'expectedIntent': 'package_list', 'expectedType': 'combo'},
      {'query': 'hitung bonus 20 sa', 'expectedIntent': 'incentive_calc', 'expectedSa': 20},
      {'query': 'insentif pro 15 sa', 'expectedIntent': 'incentive_calc', 'expectedPosition': PositionType.pro, 'expectedSa': 15},
      {'query': 'insentif spv 200 sa', 'expectedIntent': 'incentive_calc', 'expectedPosition': PositionType.spv},
      {'query': 'tabel tiering insentif', 'expectedIntent': 'incentive_scheme_info'},
      {'query': 'aturan komisi dsa', 'expectedIntent': 'incentive_scheme_info'},
      {'query': 'buka speed test', 'expectedIntent': 'nav_speedtest'},
      {'query': 'buka peta cakupan', 'expectedIntent': 'nav_coverage_map'},
      {'query': 'buka kalkulator', 'expectedIntent': 'nav_calculator'},
      {'query': 'buka katalog paket', 'expectedIntent': 'nav_catalog'},
      {'query': 'cek sinyal fwa', 'expectedIntent': 'rf_analyze'},
      {'query': 'kualitas sinyal di sini', 'expectedIntent': 'rf_analyze'},
      {'query': 'keberatan harga kemahalan', 'expectedIntent': 'script_get', 'expectedObjection': 'mahal'},
      {'query': 'cara tawar ke pemilik kost', 'expectedIntent': 'script_get', 'expectedSegment': 'kos'},
      {'query': 'script jualan warung kopi', 'expectedIntent': 'script_get', 'expectedSegment': 'warkop'},
      {'query': 'script penawaran toko kelontong', 'expectedIntent': 'script_get', 'expectedSegment': 'umkm'},
      {'query': 'draft wa penawaran', 'expectedIntent': 'wa_draft'},
      {'query': 'template wa follow up', 'expectedIntent': 'wa_draft'},
      {'query': 'produk paling untung', 'expectedIntent': 'best_product_mix'},
      {'query': 'jual apa yang paling cuan', 'expectedIntent': 'best_product_mix'},
      {'query': 'tambah berapa sa lagi biar naik tier', 'expectedIntent': 'target_gap'},
      {'query': 'kejar tier berikutnya', 'expectedIntent': 'target_gap'},
      {'query': 'sisa hari bulan ini', 'expectedIntent': 'pace'},
      {'query': 'selamat siang coach', 'expectedIntent': 'greet'},
      {'query': 'menu bantuan apa saja', 'expectedIntent': 'help'},
    ];

    for (int i = 0; i < testCases.length; i++) {
      final tc = testCases[i];
      final query = tc['query'] as String;

      test('[${i + 1}] Query: "$query"', () {
        final normalized = TextNormalizer.normalize(query);
        final match = IntentRouter.route(normalized);

        if (tc.containsKey('expectedIntent')) {
          expect(
            match.intentId,
            equals(tc['expectedIntent']),
            reason: 'Query "$query" (normalized: "$normalized") diharapkan intent ${tc['expectedIntent']} tapi mendapat ${match.intentId} (score: ${match.score})',
          );
        }

        if (tc.containsKey('forbiddenIntent')) {
          expect(
            match.intentId,
            isNot(equals(tc['forbiddenIntent'])),
            reason: 'Query "$query" tidak boleh cocok dengan ${tc['forbiddenIntent']}',
          );
        }

        if (tc.containsKey('expectedSa')) {
          expect(match.entities.totalSa, equals(tc['expectedSa']));
        }
        if (tc.containsKey('expectedPosition')) {
          expect(match.entities.position, equals(tc['expectedPosition']));
        }
        if (tc.containsKey('expectedType')) {
          expect(match.entities.packageType, equals(tc['expectedType']));
        }
        if (tc.containsKey('expectedSegment')) {
          expect(match.entities.segment, equals(tc['expectedSegment']));
        }
        if (tc.containsKey('expectedObjection')) {
          expect(match.entities.objection, equals(tc['expectedObjection']));
        }
        if (tc.containsKey('expectedDistrict')) {
          expect(match.entities.district, equals(tc['expectedDistrict']));
        }
      });
    }
  });
}
