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

    test('Perhitungan 20 SA AE Elite: Progresif SA dihitung utuh & Multiplier = PM Base * 4.0x', () {
      // 5 x f100, 5 x f125, 5 x f200, 5 x fwa = 20 SA
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

      // progInc utuh dari tier 1 s/d 4 (480k + 450k + 700k + 1.400k = 3.030.000)
      expect(res.progInc, 3030000.0);

      // Multiplier = pmBase * multRate (2.375.000 * 4.0 = 9.500.000)
      expect(res.multBonus, 9500000.0);
      expect(res.lumpSumBonus, 0.0);

      // Grand Total = Basic Fee (2.773.184) + pmBase (2.375.000) + progInc (3.030.000) + multBonus (9.500.000)
      expect(res.grandTotal, 2773184.0 + 2375000.0 + 3030000.0 + 9500000.0);
      expect(res.grandTotal, 17678184.0);
      expect(res.tierRows.length, 7);
      expect(res.tierRows[3].isCurrentTier, isTrue);
    });

    test('Perhitungan 35 SA AE Elite: Progresif SA Rp 6.180.000 tetap didapat + Multiplier 4.25x * PM Base', () {
      // 35 SA dengan 35 x f100 -> pmBase = 3.500.000
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
      expect(res.pmBase, 3500000.0);
      expect(res.multRate, 4.25);

      // Nilai Progresif SA dihitung utuh (480k + 450k + 700k + 3.200k + 1.350k = 6.180.000)
      expect(res.progInc, 6180000.0);

      // Multiplier = pmBase * multRate = 3.500.000 * 4.25 = 14.875.000
      expect(res.multBonus, 14875000.0);

      // Subtotal progresif di tiap baris tier
      expect(res.tierRows[0].subtotalProgressive, 480000.0);
      expect(res.tierRows[1].subtotalProgressive, 450000.0);
      expect(res.tierRows[2].subtotalProgressive, 700000.0);
      expect(res.tierRows[3].subtotalProgressive, 3200000.0);
      expect(res.tierRows[4].subtotalProgressive, 1350000.0);
      expect(res.tierRows[4].isCurrentTier, isTrue); // tier 30-39 akt aktif

      // Grand Total = Basic Fee (2.773.184) + pmBase (3.500.000) + progInc (6.180.000) + multBonus (14.875.000)
      expect(res.grandTotal, 2773184.0 + 3500000.0 + 6180000.0 + 14875000.0);
      expect(res.grandTotal, 27328184.0);
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

    test('Simulasi SPV Quarterly Bonus 510 SA Tim (Slide Halaman 8 & 9)', () {
      // Sesuai contoh Slide SPV Hal 8: SPV mendapatkan 510 SA Tim dengan M3 Survival >= 80%
      // Quarterly Bonus = 12.000.000 + [(510 - 500) x 30.000] = 12.300.000
      final qResult = CalculatorEngine.calculateSpvQuarterly(
        quarterlyTeamSa: 510,
        m3SurvivalRate: 0.85,
      );

      expect(qResult.isGatePassed, isTrue);
      expect(qResult.baseBonus, 12000000.0);
      expect(qResult.incrementalSa, 10);
      expect(qResult.incrementalBonus, 300000.0);
      expect(qResult.totalQuarterlyBonus, 12300000.0);

      // Jika M3 Survival < 80%, bonus = 0
      final qFail = CalculatorEngine.calculateSpvQuarterly(
        quarterlyTeamSa: 510,
        m3SurvivalRate: 0.75,
      );
      expect(qFail.isGatePassed, isFalse);
      expect(qFail.totalQuarterlyBonus, 0.0);
    });
  });

  group('CalculatorEngine Tests - DSA Survival Rate, Quarterly & Net Add (September 2026)', () {
    test('DSA Survival Rate M3 (@100k Gate >=90%) dan M5 (@80k Gate >=80%)', () {
      // 10 SA baseline, 9 surviving M3 (90% - Lolos)
      // 10 SA baseline, 8 surviving M5 (80% - Lolos)
      final surv = CalculatorEngine.calculateDsaSurvival(
        m3Base: 10,
        m3Surv: 9,
        m5Base: 10,
        m5Surv: 8,
      );

      expect(surv.m3GatePassed, isTrue);
      expect(surv.m3Total, 900000.0); // 9 * 100k
      expect(surv.m5GatePassed, isTrue);
      expect(surv.m5Total, 640000.0); // 8 * 80k
      expect(surv.totalSurvivalBonus, 1540000.0);

      // Kasus Gate M3 gagal (< 90%)
      final survFail = CalculatorEngine.calculateDsaSurvival(
        m3Base: 10,
        m3Surv: 8, // 80% < 90%
        m5Base: 10,
        m5Surv: 7, // 70% < 80%
      );
      expect(survFail.m3GatePassed, isFalse);
      expect(survFail.m3Total, 0.0);
      expect(survFail.m5GatePassed, isFalse);
      expect(survFail.m5Total, 0.0);
      expect(survFail.totalSurvivalBonus, 0.0);
    });

    test('DSA Quarterly Bonus (Slide Hal 6 & 10): 30-44 SA (2jt), 45-59 SA (15jt), >=60 SA (20jt + 10k/inc)', () {
      // AE Pro/Elite 65 SA Kuartal + M3 >= 90%:
      // 20.000.000 + (5 * 10.000) = 20.050.000
      final q65 = CalculatorEngine.calculateDsaQuarterly(
        position: PositionType.elite,
        quarterlySa: 65,
        m3SurvivalRate: 0.92,
      );
      expect(q65.isGatePassed, isTrue);
      expect(q65.baseBonus, 20000000.0);
      expect(q65.incrementalSa, 5);
      expect(q65.incrementalBonus, 50000.0);
      expect(q65.totalQuarterlyBonus, 20050000.0);

      // AE Pro 50 SA Kuartal + M3 >= 90%: 15.000.000
      final q50 = CalculatorEngine.calculateDsaQuarterly(
        position: PositionType.pro,
        quarterlySa: 50,
        m3SurvivalRate: 0.90,
      );
      expect(q50.isGatePassed, isTrue);
      expect(q50.totalQuarterlyBonus, 15000000.0);

      // AE Pro 35 SA Kuartal + M3 >= 90%: 2.000.000
      final q35 = CalculatorEngine.calculateDsaQuarterly(
        position: PositionType.pro,
        quarterlySa: 35,
        m3SurvivalRate: 0.91,
      );
      expect(q35.isGatePassed, isTrue);
      expect(q35.totalQuarterlyBonus, 2000000.0);

      // OJT level tidak berhak atas Quarterly Bonus
      final qOjt = CalculatorEngine.calculateDsaQuarterly(
        position: PositionType.ojt,
        quarterlySa: 60,
        m3SurvivalRate: 0.95,
      );
      expect(qOjt.totalQuarterlyBonus, 0.0);

      // Jika Gate M3 < 90%, bonus = 0
      final qFail = CalculatorEngine.calculateDsaQuarterly(
        position: PositionType.elite,
        quarterlySa: 70,
        m3SurvivalRate: 0.88,
      );
      expect(qFail.isGatePassed, isFalse);
      expect(qFail.totalQuarterlyBonus, 0.0);
    });

    test('DSA Net Add Incentive (Slide Hal 6, 8, 10): Capping Max 10 Incremental SA', () {
      // Baseline 150 active subs (Tier 100-199 @ 100k), naik 15 subs -> capped 10 subs = 1.000.000
      final netAdd = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.elite,
        baselineActiveSubs: 150,
        currentActiveSubs: 165,
      );
      expect(netAdd.incrementalSa, 10);
      expect(netAdd.ratePerSa, 100000.0);
      expect(netAdd.totalNetAddBonus, 1000000.0);

      // Baseline 200+ (@ 150k), naik 4 subs = 4 * 150k = 600.000
      final netAdd200 = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.pro,
        baselineActiveSubs: 210,
        currentActiveSubs: 214,
      );
      expect(netAdd200.incrementalSa, 4);
      expect(netAdd200.ratePerSa, 150000.0);
      expect(netAdd200.totalNetAddBonus, 600000.0);
    });

    test('Special Incentive PXGY: Hanya aktif jika leadsFromDtd == true', () {
      // 2 x p35 + 1 x p6 = 3 SA PXGY
      // pmBase = 2*125k + 1*150k = 400.000
      // specialInc (DTD) = 2*125k + 1*150k = 400.000
      final resDtd = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 0,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 2,
        p6: 1,
        leadsFromDtd: true,
      );
      expect(resDtd.pmBase, 400000.0);
      expect(resDtd.specialInc, 400000.0);
      expect(resDtd.leadsFromDtd, isTrue);

      // Non-DTD leads: pmBase TETAP 400.000, tapi specialInc = 0.0
      final resNonDtd = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 0,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 2,
        p6: 1,
        leadsFromDtd: false,
      );
      expect(resNonDtd.pmBase, 400000.0);
      expect(resNonDtd.specialInc, 0.0);
      expect(resNonDtd.leadsFromDtd, isFalse);
    });

    test('Skenario OJT 3 SA (Slide 4)', () {
      // 3 SA f100 -> prog: 2*80k + 1*100k = 260.000, pmBase: 300.000, lumpSum: 325.000
      final res = CalculatorEngine.calculateDetailed(
        position: PositionType.ojt,
        f0: 0,
        f50: 0,
        f100: 3,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );
      expect(res.totalSa, 3);
      expect(res.progInc, 260000.0);
      expect(res.pmBase, 300000.0);
      expect(res.multBonus, 0.0);
      expect(res.lumpSumBonus, 325000.0);
      expect(res.grandTotal, 1900000.0 + 260000.0 + 300000.0 + 325000.0);
    });

    test('Skenario Pro/Elite 5, 7, 10, 14, 20, 50 SA (Slide 6 & 8)', () {
      // 5 SA (f100=5): prog 5*80k = 400k, pmBase 500k, mult 0 -> 900k
      final res5 = CalculatorEngine.calculateDetailed(
        position: PositionType.pro,
        f0: 0,
        f50: 0,
        f100: 5,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );
      expect(res5.totalSa, 5);
      expect(res5.progInc, 400000.0);
      expect(res5.pmBase, 500000.0);
      expect(res5.multRate, 0.0);
      expect(res5.multBonus, 0.0);

      // 7 SA (f100=7): prog 6*80k + 1*150k = 630k, pmBase 700k, mult 1.5x * 700k = 1.050k
      final res7 = CalculatorEngine.calculateDetailed(
        position: PositionType.pro,
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
      expect(res7.progInc, 630000.0);
      expect(res7.pmBase, 700000.0);
      expect(res7.multRate, 1.50);
      expect(res7.multBonus, 1050000.0);

      // 10 SA (f100=10): prog 6*80k + 3*150k + 1*175k = 1.105k, pmBase 1.000k, mult 2.0x * 1.000k = 2.000k
      final res10 = CalculatorEngine.calculateDetailed(
        position: PositionType.pro,
        f0: 0,
        f50: 0,
        f100: 10,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );
      expect(res10.totalSa, 10);
      expect(res10.progInc, 1105000.0);
      expect(res10.pmBase, 1000000.0);
      expect(res10.multRate, 2.00);
      expect(res10.multBonus, 2000000.0);

      // 14 SA (f100=14): prog 6*80k + 3*150k + 4*175k + 1*200k = 1.830k, pmBase 1.400k, mult 4.0x * 1.400k = 5.600k
      final res14 = CalculatorEngine.calculateDetailed(
        position: PositionType.pro,
        f0: 0,
        f50: 0,
        f100: 14,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );
      expect(res14.totalSa, 14);
      expect(res14.progInc, 1830000.0);
      expect(res14.pmBase, 1400000.0);
      expect(res14.multRate, 4.00);
      expect(res14.multBonus, 5600000.0);

      // 50 SA (f100=50): prog utuh sampai tier 6 + 1 di tier 7 = 480k+450k+700k+3.200k+2.250k+2.500k+275k = 9.855k, pmBase 5.000k, mult 4.65x * 5.000k = 23.250k
      final res50 = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 50,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );
      expect(res50.totalSa, 50);
      expect(res50.progInc, 9855000.0);
      expect(res50.pmBase, 5000000.0);
      expect(res50.multRate, 4.65);
      expect(res50.multBonus, 23250000.0);
    });
  });
}
