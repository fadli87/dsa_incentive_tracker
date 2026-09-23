import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/core/engine/calculator_engine.dart';
import 'package:dsa_incentive_tracker/core/models/calculator_models.dart';

void main() {
  group('CalculatorEngine Tests - DSA (OJT, Pro, Elite)', () {
    test('Nilai default Cilacap dan Basic Fee Elite adalah Rp 2.773.184', () {
      final res = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 0,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );

      expect(res.city, 'KAB. CILACAP');
      expect(res.basicFee, 2773184.0);
      expect(res.totalSa, 0);
      expect(res.grandTotal, 2773184.0);
    });

<<<<<<< HEAD
    test('Basic Fee OJT, Pro, dan Elite sesuai acuan terbaru', () {
      expect(CalculatorEngine.getBasicFee(PositionType.ojt), 1900000.0);
      expect(CalculatorEngine.getBasicFee(PositionType.pro), 2600000.0);
      expect(CalculatorEngine.getBasicFee(PositionType.elite), 2773184.0);
    });

    test('Perhitungan OJT: Progressive tier OJT, Lump Sum, dan tanpa Multiplier', () {
      // Test OJT dengan 4 SA (f100: 4)
      final res4 = CalculatorEngine.calculateDetailed(
        position: PositionType.ojt,
        f0: 0,
        f50: 0,
        f100: 4,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );

      expect(res4.totalSa, 4);
      // OJT Tier: 1-2 @ 80k (160k), 3-4 @ 100k (200k) -> progInc = 360.000
      expect(res4.progInc, 360000.0);
      // Lump Sum min 3 SA = 325.000
      expect(res4.lumpSumBonus, 325000.0);
      // OJT multRate & multBonus = 0
      expect(res4.multRate, 0.0);
      expect(res4.multBonus, 0.0);
      expect(res4.tierRows.length, 5);
      expect(res4.tierRows[1].isCurrentTier, isTrue); // tier 3-4 akt
      // Grand total: basicFee (1.900.000) + prog (360.000) + pmBase (400.000) + lumpSum (325.000)
      expect(res4.grandTotal, 1900000.0 + 360000.0 + 400000.0 + 325000.0);

      // Test OJT dengan 7 SA (f100: 7)
      final res7 = CalculatorEngine.calculateDetailed(
        position: PositionType.ojt,
        f0: 0,
        f50: 0,
        f100: 7,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );

      expect(res7.totalSa, 7);
      // OJT Tier 7 SA:
      // 1-2 (2*80k = 160k) + 3-4 (2*100k = 200k) + 5-6 (2*130k = 260k) + 7 (1*150k = 150k)
      // progInc = 160k + 200k + 260k + 150k = 770.000
      expect(res7.progInc, 770000.0);
      // Lump Sum min 7 SA = 600.000
      expect(res7.lumpSumBonus, 600000.0);
      expect(res7.multBonus, 0.0);
      expect(res7.grandTotal, 1900000.0 + 770000.0 + 700000.0 + 600000.0);
    });

    test('Perhitungan AE Elite < 7 SA (misal 4 SA): Mendapatkan Progresif SA karena belum ada Multiplier', () {
      final res = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 4,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );

      expect(res.totalSa, 4);
      expect(res.pmBase, 400000.0);
      expect(res.multRate, 0.0);
      expect(res.multBonus, 0.0);
      // Multiplier belum ada (< 7 SA), sehingga Progresif SA tetap dihitung (4 * 80.000)
      expect(res.progInc, 320000.0);
      expect(res.grandTotal, 2773184.0 + 320000.0 + 400000.0);
      expect(res.tierRows[0].subtotalProgressive, 320000.0);
    });

    test('Perhitungan 20 SA AE Elite: Progresif SA HILANG karena perhitungan Multiplier sudah ada', () {
      // 5 x f100, 5 x f125, 5 x f200, 5 x fwa = 20 SA
=======
    test('Perhitungan 20 SA dengan tiering September', () {
>>>>>>> 2e16fea (feat: implementasi skema kalkulator SPV September 2026, basic fee Rp 4.5jt, dan update v1.0.2)
      final res = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 5,
        f125: 5,
        f200: 5,
        fwa: 5,
        p35: 0,
        p6: 0,
      );

      expect(res.totalSa, 20);
      expect(res.pmBase, 2375000.0);
      expect(res.multRate, 4.0);
<<<<<<< HEAD

      // Multiplier per tier:
      // Tier 2: 450k * 1.5 = 675k
      // Tier 3: 700k * 2.0 = 1.400k
      // Tier 4: (7 * 200k) * 4.0 = 1.400k * 4.0 = 5.600k
      // Total multBonus = 675k + 1.400k + 5.600k = 7.675.000
      expect(res.multBonus, 7675000.0);

      // REVISI: Insentif progresif SA HILANG karena perhitungan multiplier sudah ada!
      expect(res.progInc, 0.0);
      expect(res.lumpSumBonus, 0.0);

      // Grand Total = Basic Fee (2.773.184) + pmBase (2.375.000) + multBonus (7.675.000)
      expect(res.grandTotal, 2773184.0 + 2375000.0 + 7675000.0);
      expect(res.grandTotal, 12823184.0);
      expect(res.tierRows.length, 7);
      expect(res.tierRows[3].isCurrentTier, isTrue);
    });

    test('Perhitungan 35 SA AE Elite (Sesuai Screenshot User): Progresif SA Rp 6.180.000 HILANG', () {
      // Misal 35 SA dengan pmBase 2.325.000 dan special PXGY 675.000
      // 35 SA terbagi ke: 1-6 (6), 7-9 (3), 10-13 (4), 14-29 (16), 30-39 (6)
      final res = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 35,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );

      expect(res.totalSa, 35);
      expect(res.multRate, 4.25);

      // Multiplier per tier persis sesuai screenshot user:
      // Tier 2 (7-9): 3 * 150k = 450k -> 450k * 1.5 = 675.000
      // Tier 3 (10-13): 4 * 175k = 700k -> 700k * 2.0 = 1.400.000
      // Tier 4 (14-29): 16 * 200k = 3.200k -> 3.200k * 4.0 = 12.800.000
      // Tier 5 (30-39): 6 * 225k = 1.350k -> 1.350k * 4.25 = 5.737.500
      // Total Booster Multiplier = 675k + 1.400k + 12.800k + 5.737.500 = 20.612.500
      expect(res.multBonus, 20612500.0);

      // Nilai Progresif SA (yang tadinya 6.180.000) HILANG (menjadi 0.0) karena multiplier sudah ada!
      expect(res.progInc, 0.0);

      // Subtotal progresif di tiap baris tier tetap tersimpan untuk transparansi hitungan multiplier
      expect(res.tierRows[0].subtotalProgressive, 480000.0);
      expect(res.tierRows[1].subtotalProgressive, 450000.0);
      expect(res.tierRows[2].subtotalProgressive, 700000.0);
      expect(res.tierRows[3].subtotalProgressive, 3200000.0);
      expect(res.tierRows[4].subtotalProgressive, 1350000.0);

      // Dan bonus multiplier per tier persis sesuai gambar:
      expect(res.tierRows[1].multiplierBonus, 675000.0);
      expect(res.tierRows[2].multiplierBonus, 1400000.0);
      expect(res.tierRows[3].multiplierBonus, 12800000.0);
      expect(res.tierRows[4].multiplierBonus, 5737500.0);
      expect(res.tierRows[4].isCurrentTier, isTrue); // tier 30-39 akt aktif
    });
  });

  group('CalculatorEngine Tests - SPV New Scheme September 2026', () {
    test('Basic Fee SPV adalah Rp 4.500.000', () {
      expect(CalculatorEngine.getBasicFee(PositionType.spv), 4500000.0);
    });

    test('Simulasi SPV A persis sesuai Slide Halaman 9', () {
      final res = CalculatorEngine.calculateSpvDetailed(
        qtyRegular: 91,
        qtyPxgy: 30,
        totalActiveAgents: 14,
        agentEarnAf: 14,
        mobSpv: 17,
        ojtCount: 2,
        m3Baseline: 64,
        m3Surviving: 51,
        m5Baseline: 28,
        m5Surviving: 27,
        ojtToProNormal: 2,
        ojtToProAccel: 0,
        proToEliteNormal: 1,
        proToEliteAccel: 0,
      );

      // Basic Fee
      expect(res.basicFee, 4500000.0);
      expect(res.totalTeamSa, 121);

      // Poin 1: KPI Bonus
      expect(res.kpiBonus.productMix.subtotalRegular, 3185000.0); // 91 * 35k
      expect(res.kpiBonus.productMix.subtotalPxgy, 900000.0); // 30 * 30k
      expect(res.kpiBonus.productMix.totalProductMix, 4085000.0);

      expect(res.kpiBonus.participation.participationRate, 1.0); // 100%
      expect(res.kpiBonus.participation.multiplier, 1.25);
      expect(res.kpiBonus.participation.participationBonus, 5106250.0); // 1.25 * 4.085.000

      expect(res.kpiBonus.ojtRatio, closeTo(0.1428, 0.001)); // 2/14 = 14% (<40%)
      expect(res.kpiBonus.kpiMultiplier, 1.20); // 8+ agents, <40% OJT
      expect(res.kpiBonus.totalKpiBonus, 11029500.0); // 1.20 * (4.085.000 + 5.106.250)

      // Poin 2: Survival Rate
      expect(res.m3Survival.isGatePassed, isFalse); // 51/64 = 79.6% < 90%
      expect(res.m3Survival.totalBonus, 0.0);

      expect(res.m5Survival.isGatePassed, isTrue); // 27/28 = 96.4% >= 80%
      expect(res.m5Survival.amountSubs, 675000.0); // 27 * 25k
      expect(res.m5Survival.lumpSumBonus, 2000000.0);
      expect(res.m5Survival.totalBonus, 2675000.0);
      expect(res.totalSurvivalIncentive, 2675000.0);

      // Poin 3: Graduation Bonus
      expect(res.graduation.totalBonus, 1600000.0); // 2 * 500k + 1 * 600k

      // Poin 4: Monthly Performance
      expect(res.monthlyPerformance.bonusAmount, 0.0); // 121 SA < 160

      // Total Poin 1 + 2 + 3 + 4
      expect(res.totalIncentive, 15304500.0);

      // Take Home Pay (Basic Fee + Total Insentif)
      expect(res.grandTotal, 4500000.0 + 15304500.0); // 19.804.500
    });

    test('Simulasi SPV B persis sesuai Slide Halaman 9', () {
      final res = CalculatorEngine.calculateSpvDetailed(
        qtyRegular: 43,
        qtyPxgy: 25,
        totalActiveAgents: 10,
        agentEarnAf: 10,
        mobSpv: 16,
        ojtCount: 3,
        m3Baseline: 32,
        m3Surviving: 28,
        m5Baseline: 32,
        m5Surviving: 31,
        ojtToProNormal: 3,
        ojtToProAccel: 0,
        proToEliteNormal: 2,
        proToEliteAccel: 0,
      );

      // Basic Fee & Team SA
      expect(res.basicFee, 4500000.0);
      expect(res.totalTeamSa, 68);

      // Poin 1: KPI Bonus
      expect(res.kpiBonus.productMix.subtotalRegular, 1075000.0); // 43 * 25k
      expect(res.kpiBonus.productMix.subtotalPxgy, 750000.0); // 25 * 30k
      expect(res.kpiBonus.productMix.totalProductMix, 1825000.0);

      expect(res.kpiBonus.participation.participationRate, 1.0); // 100%
      expect(res.kpiBonus.participation.multiplier, 1.25);
      expect(res.kpiBonus.participation.participationBonus, 2281250.0); // 1.25 * 1.825.000

      expect(res.kpiBonus.ojtRatio, 0.30); // 3/10 = 30% (<40%)
      expect(res.kpiBonus.kpiMultiplier, 1.20); // 8+ agents, <40% OJT
      expect(res.kpiBonus.totalKpiBonus, 4927500.0); // 1.20 * (1.825.000 + 2.281.250)

      // Poin 2: Survival Rate
      expect(res.m3Survival.isGatePassed, isFalse); // 28/32 = 87.5% < 90%
      expect(res.m3Survival.totalBonus, 0.0);

      expect(res.m5Survival.isGatePassed, isTrue); // 31/32 = 96.8% >= 80%
      expect(res.m5Survival.amountSubs, 775000.0); // 31 * 25k
      expect(res.m5Survival.lumpSumBonus, 2000000.0);
      expect(res.m5Survival.totalBonus, 2775000.0);
      expect(res.totalSurvivalIncentive, 2775000.0);

      // Poin 3: Graduation Bonus
      expect(res.graduation.totalBonus, 2700000.0); // 3 * 500k + 2 * 600k

      // Poin 4: Monthly Performance
      expect(res.monthlyPerformance.bonusAmount, 0.0); // 68 SA < 160

      // Total Poin 1 + 2 + 3 + 4
      expect(res.totalIncentive, 10402500.0);

      // Take Home Pay (Basic Fee + Total Insentif)
      expect(res.grandTotal, 4500000.0 + 10402500.0); // 14.902.500
    });

    test('Simulasi SPV dengan MoB <= 3 (Slide Halaman 4)', () {
      final res = CalculatorEngine.calculateSpvDetailed(
        qtyRegular: 20,
        qtyPxgy: 15,
        totalActiveAgents: 15,
        agentEarnAf: 12,
        mobSpv: 3, // MoB <= 3
        ojtCount: 10,
        m3Baseline: 0,
        m3Surviving: 0,
        m5Baseline: 0,
        m5Surviving: 0,
        ojtToProNormal: 0,
        ojtToProAccel: 0,
        proToEliteNormal: 0,
        proToEliteAccel: 0,
      );

      // Product Mix: 20 * 20k (400k) + 15 * 30k (450k) = 850.000
      expect(res.kpiBonus.productMix.totalProductMix, 850000.0);

      // Untuk MoB <= 3, Participation Bonus = 0 & KPI Multiplier = 100%
      expect(res.kpiBonus.participation.participationBonus, 0.0);
      expect(res.kpiBonus.kpiMultiplier, 1.0);
      expect(res.kpiBonus.totalKpiBonus, 850000.0);
    });
  });
}
