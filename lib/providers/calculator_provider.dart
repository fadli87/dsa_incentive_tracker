import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/engine/calculator_engine.dart';
import '../core/models/calculator_models.dart';

class CalculatorState {
  final PositionType position;
  final String city;

  // DSA Inputs
  final int f0, f50, f100, f125, f200, fwa, p35, p6;
  final int dsaM3Baseline;
  final int dsaM3Surviving;
  final int dsaM5Baseline;
  final int dsaM5Surviving;
  final int dsaQuarterlySa;
  final double dsaQuarterlyM3Rate;
  final int dsaBaselineActiveSubs;
  final int dsaCurrentActiveSubs;
  final CalculationResult calculationResult;
  final Map<String, dynamic> results;

  // SPV Inputs (Skema September 2026)
  final int spvQtyRegular;
  final int spvQtyPxgy;
  final int spvActiveAgents;
  final int spvAgentEarnAf;
  final int spvMob;
  final int spvOjtCount;
  final int spvM3Baseline;
  final int spvM3Surviving;
  final int spvM5Baseline;
  final int spvM5Surviving;
  final int spvOjtToProNormal;
  final int spvOjtToProAccel;
  final int spvProToEliteNormal;
  final int spvProToEliteAccel;
  final int spvQuarterlyTeamSa;
  final double spvQuarterlyM3Rate;
  final SpvCalculationResult spvCalculationResult;

  CalculatorState({
    this.position = PositionType.elite,
    this.city = CalculatorEngine.defaultCity,
    this.f0 = 0,
    this.f50 = 0,
    this.f100 = 0,
    this.f125 = 0,
    this.f200 = 0,
    this.fwa = 0,
    this.p35 = 0,
    this.p6 = 0,
    this.dsaM3Baseline = 0,
    this.dsaM3Surviving = 0,
    this.dsaM5Baseline = 0,
    this.dsaM5Surviving = 0,
    this.dsaQuarterlySa = 0,
    this.dsaQuarterlyM3Rate = 0.0,
    this.dsaBaselineActiveSubs = 0,
    this.dsaCurrentActiveSubs = 0,
    required this.calculationResult,
    required this.results,
    this.spvQtyRegular = 0,
    this.spvQtyPxgy = 0,
    this.spvActiveAgents = 0,
    this.spvAgentEarnAf = 0,
    this.spvMob = 4,
    this.spvOjtCount = 0,
    this.spvM3Baseline = 0,
    this.spvM3Surviving = 0,
    this.spvM5Baseline = 0,
    this.spvM5Surviving = 0,
    this.spvOjtToProNormal = 0,
    this.spvOjtToProAccel = 0,
    this.spvProToEliteNormal = 0,
    this.spvProToEliteAccel = 0,
    this.spvQuarterlyTeamSa = 0,
    this.spvQuarterlyM3Rate = 0.0,
    required this.spvCalculationResult,
  });

  CalculatorState copyWith({
    PositionType? position,
    String? city,
    int? f0,
    int? f50,
    int? f100,
    int? f125,
    int? f200,
    int? fwa,
    int? p35,
    int? p6,
    int? dsaM3Baseline,
    int? dsaM3Surviving,
    int? dsaM5Baseline,
    int? dsaM5Surviving,
    int? dsaQuarterlySa,
    double? dsaQuarterlyM3Rate,
    int? dsaBaselineActiveSubs,
    int? dsaCurrentActiveSubs,
    int? spvQtyRegular,
    int? spvQtyPxgy,
    int? spvActiveAgents,
    int? spvAgentEarnAf,
    int? spvMob,
    int? spvOjtCount,
    int? spvM3Baseline,
    int? spvM3Surviving,
    int? spvM5Baseline,
    int? spvM5Surviving,
    int? spvOjtToProNormal,
    int? spvOjtToProAccel,
    int? spvProToEliteNormal,
    int? spvProToEliteAccel,
    int? spvQuarterlyTeamSa,
    double? spvQuarterlyM3Rate,
  }) {
    final newPosition = position ?? this.position;
    final newCity = city ?? this.city;

    // DSA
    final newF0 = f0 ?? this.f0;
    final newF50 = f50 ?? this.f50;
    final newF100 = f100 ?? this.f100;
    final newF125 = f125 ?? this.f125;
    final newF200 = f200 ?? this.f200;
    final newFwa = fwa ?? this.fwa;
    final newP35 = p35 ?? this.p35;
    final newP6 = p6 ?? this.p6;
    final newDsaM3Base = dsaM3Baseline ?? this.dsaM3Baseline;
    final newDsaM3Surv = dsaM3Surviving ?? this.dsaM3Surviving;
    final newDsaM5Base = dsaM5Baseline ?? this.dsaM5Baseline;
    final newDsaM5Surv = dsaM5Surviving ?? this.dsaM5Surviving;
    final newDsaQSa = dsaQuarterlySa ?? this.dsaQuarterlySa;
    final newDsaQM3Rate = dsaQuarterlyM3Rate ?? this.dsaQuarterlyM3Rate;
    final newDsaBaseActive = dsaBaselineActiveSubs ?? this.dsaBaselineActiveSubs;
    final newDsaCurrActive = dsaCurrentActiveSubs ?? this.dsaCurrentActiveSubs;

    final detailedResult = CalculatorEngine.calculateDetailed(
      position: newPosition,
      city: newCity,
      f0: newF0,
      f50: newF50,
      f100: newF100,
      f125: newF125,
      f200: newF200,
      fwa: newFwa,
      p35: newP35,
      p6: newP6,
      m3Base: newDsaM3Base,
      m3Surv: newDsaM3Surv,
      m5Base: newDsaM5Base,
      m5Surv: newDsaM5Surv,
      quarterlySa: newDsaQSa,
      quarterlyM3SurvivalRate: newDsaQM3Rate,
      baselineActiveSubs: newDsaBaseActive,
      currentActiveSubs: newDsaCurrActive,
    );

    final legacyMap = detailedResult.toLegacyMap();

    // SPV
    final newSpvQtyRegular = spvQtyRegular ?? this.spvQtyRegular;
    final newSpvQtyPxgy = spvQtyPxgy ?? this.spvQtyPxgy;
    final newSpvActiveAgents = spvActiveAgents ?? this.spvActiveAgents;
    final newSpvAgentEarnAf = spvAgentEarnAf ?? this.spvAgentEarnAf;
    final newSpvMob = spvMob ?? this.spvMob;
    final newSpvOjtCount = spvOjtCount ?? this.spvOjtCount;
    final newSpvM3Baseline = spvM3Baseline ?? this.spvM3Baseline;
    final newSpvM3Surviving = spvM3Surviving ?? this.spvM3Surviving;
    final newSpvM5Baseline = spvM5Baseline ?? this.spvM5Baseline;
    final newSpvM5Surviving = spvM5Surviving ?? this.spvM5Surviving;
    final newSpvOjtToProNormal = spvOjtToProNormal ?? this.spvOjtToProNormal;
    final newSpvOjtToProAccel = spvOjtToProAccel ?? this.spvOjtToProAccel;
    final newSpvProToEliteNormal =
        spvProToEliteNormal ?? this.spvProToEliteNormal;
    final newSpvProToEliteAccel = spvProToEliteAccel ?? this.spvProToEliteAccel;
    final newSpvQuarterlyTeamSa = spvQuarterlyTeamSa ?? this.spvQuarterlyTeamSa;
    final newSpvQuarterlyM3Rate = spvQuarterlyM3Rate ?? this.spvQuarterlyM3Rate;

    final spvResult = CalculatorEngine.calculateSpvDetailed(
      city: newCity,
      qtyRegular: newSpvQtyRegular,
      qtyPxgy: newSpvQtyPxgy,
      totalActiveAgents: newSpvActiveAgents,
      agentEarnAf: newSpvAgentEarnAf,
      mobSpv: newSpvMob,
      ojtCount: newSpvOjtCount,
      m3Baseline: newSpvM3Baseline,
      m3Surviving: newSpvM3Surviving,
      m5Baseline: newSpvM5Baseline,
      m5Surviving: newSpvM5Surviving,
      ojtToProNormal: newSpvOjtToProNormal,
      ojtToProAccel: newSpvOjtToProAccel,
      proToEliteNormal: newSpvProToEliteNormal,
      proToEliteAccel: newSpvProToEliteAccel,
      quarterlyTeamSa: newSpvQuarterlyTeamSa,
      quarterlyM3SurvivalRate: newSpvQuarterlyM3Rate,
    );

    return CalculatorState(
      position: newPosition,
      city: newCity,
      f0: newF0,
      f50: newF50,
      f100: newF100,
      f125: newF125,
      f200: newF200,
      fwa: newFwa,
      p35: newP35,
      p6: newP6,
      dsaM3Baseline: newDsaM3Base,
      dsaM3Surviving: newDsaM3Surv,
      dsaM5Baseline: newDsaM5Base,
      dsaM5Surviving: newDsaM5Surv,
      dsaQuarterlySa: newDsaQSa,
      dsaQuarterlyM3Rate: newDsaQM3Rate,
      dsaBaselineActiveSubs: newDsaBaseActive,
      dsaCurrentActiveSubs: newDsaCurrActive,
      calculationResult: detailedResult,
      results: legacyMap,
      spvQtyRegular: newSpvQtyRegular,
      spvQtyPxgy: newSpvQtyPxgy,
      spvActiveAgents: newSpvActiveAgents,
      spvAgentEarnAf: newSpvAgentEarnAf,
      spvMob: newSpvMob,
      spvOjtCount: newSpvOjtCount,
      spvM3Baseline: newSpvM3Baseline,
      spvM3Surviving: newSpvM3Surviving,
      spvM5Baseline: newSpvM5Baseline,
      spvM5Surviving: newSpvM5Surviving,
      spvOjtToProNormal: newSpvOjtToProNormal,
      spvOjtToProAccel: newSpvOjtToProAccel,
      spvProToEliteNormal: newSpvProToEliteNormal,
      spvProToEliteAccel: newSpvProToEliteAccel,
      spvQuarterlyTeamSa: newSpvQuarterlyTeamSa,
      spvQuarterlyM3Rate: newSpvQuarterlyM3Rate,
      spvCalculationResult: spvResult,
    );
  }
}

class CalculatorNotifier extends Notifier<CalculatorState> {
  @override
  CalculatorState build() {
    const initialPos = PositionType.elite;
    const initialCity = CalculatorEngine.defaultCity;

    final detailedResult = CalculatorEngine.calculateDetailed(
      position: initialPos,
      city: initialCity,
      f0: 0,
      f50: 0,
      f100: 0,
      f125: 0,
      f200: 0,
      fwa: 0,
      p35: 0,
      p6: 0,
    );

    final spvResult = CalculatorEngine.calculateSpvDetailed(
      city: initialCity,
      qtyRegular: 0,
      qtyPxgy: 0,
      totalActiveAgents: 0,
      agentEarnAf: 0,
      mobSpv: 4,
      ojtCount: 0,
      m3Baseline: 0,
      m3Surviving: 0,
      m5Baseline: 0,
      m5Surviving: 0,
      ojtToProNormal: 0,
      ojtToProAccel: 0,
      proToEliteNormal: 0,
      proToEliteAccel: 0,
      quarterlyTeamSa: 0,
      quarterlyM3SurvivalRate: 0.0,
    );

    return CalculatorState(
      position: initialPos,
      city: initialCity,
      calculationResult: detailedResult,
      results: detailedResult.toLegacyMap(),
      spvCalculationResult: spvResult,
    );
  }

  void setPosition(PositionType position) {
    state = state.copyWith(position: position);
  }

  void updateField(String field, int value) {
    switch (field) {
      case 'f0':
        state = state.copyWith(f0: value);
        break;
      case 'f50':
        state = state.copyWith(f50: value);
        break;
      case 'f100':
        state = state.copyWith(f100: value);
        break;
      case 'f125':
        state = state.copyWith(f125: value);
        break;
      case 'f200':
        state = state.copyWith(f200: value);
        break;
      case 'fwa':
        state = state.copyWith(fwa: value);
        break;
      case 'p35':
        state = state.copyWith(p35: value);
        break;
      case 'p6':
        state = state.copyWith(p6: value);
        break;
      case 'dsaM3Baseline':
        state = state.copyWith(dsaM3Baseline: value);
        break;
      case 'dsaM3Surviving':
        state = state.copyWith(dsaM3Surviving: value);
        break;
      case 'dsaM5Baseline':
        state = state.copyWith(dsaM5Baseline: value);
        break;
      case 'dsaM5Surviving':
        state = state.copyWith(dsaM5Surviving: value);
        break;
      case 'dsaQuarterlySa':
        state = state.copyWith(dsaQuarterlySa: value);
        break;
      case 'dsaBaselineActiveSubs':
        state = state.copyWith(dsaBaselineActiveSubs: value);
        break;
      case 'dsaCurrentActiveSubs':
        state = state.copyWith(dsaCurrentActiveSubs: value);
        break;
    }
  }

  void updateDsaQuarterlyM3Rate(double rate) {
    state = state.copyWith(dsaQuarterlyM3Rate: rate);
  }

  void setDsaM3Survival(int baseline, int surviving) {
    state = state.copyWith(
      dsaM3Baseline: baseline,
      dsaM3Surviving: surviving,
    );
  }

  void setDsaM5Survival(int baseline, int surviving) {
    state = state.copyWith(
      dsaM5Baseline: baseline,
      dsaM5Surviving: surviving,
    );
  }

  void setDsaQuarterly(int quarterlySa, double m3Rate) {
    state = state.copyWith(
      dsaQuarterlySa: quarterlySa,
      dsaQuarterlyM3Rate: m3Rate,
    );
  }

  void setDsaNetAdd(int baselineSubs, int currentSubs) {
    state = state.copyWith(
      dsaBaselineActiveSubs: baselineSubs,
      dsaCurrentActiveSubs: currentSubs,
    );
  }

  void updateSpvField(String field, int value) {
    switch (field) {
      case 'regular':
        state = state.copyWith(spvQtyRegular: value);
        break;
      case 'pxgy':
        state = state.copyWith(spvQtyPxgy: value);
        break;
      case 'activeAgents':
        state = state.copyWith(spvActiveAgents: value);
        break;
      case 'agentEarnAf':
        state = state.copyWith(spvAgentEarnAf: value);
        break;
      case 'mob':
        state = state.copyWith(spvMob: value);
        break;
      case 'ojt':
        state = state.copyWith(spvOjtCount: value);
        break;
      case 'm3Baseline':
        state = state.copyWith(spvM3Baseline: value);
        break;
      case 'm3Surviving':
        state = state.copyWith(spvM3Surviving: value);
        break;
      case 'm5Baseline':
        state = state.copyWith(spvM5Baseline: value);
        break;
      case 'm5Surviving':
        state = state.copyWith(spvM5Surviving: value);
        break;
      case 'ojtToProNormal':
        state = state.copyWith(spvOjtToProNormal: value);
        break;
      case 'ojtToProAccel':
        state = state.copyWith(spvOjtToProAccel: value);
        break;
      case 'proToEliteNormal':
        state = state.copyWith(spvProToEliteNormal: value);
        break;
      case 'proToEliteAccel':
        state = state.copyWith(spvProToEliteAccel: value);
        break;
      case 'quarterlyTeamSa':
        state = state.copyWith(spvQuarterlyTeamSa: value);
        break;
    }
  }

  void updateSpvQuarterlyM3Rate(double rate) {
    state = state.copyWith(spvQuarterlyM3Rate: rate);
  }

  void loadSpvPresetA() {
    state = state.copyWith(
      position: PositionType.spv,
      spvQtyRegular: 91,
      spvQtyPxgy: 30,
      spvActiveAgents: 14,
      spvAgentEarnAf: 14,
      spvMob: 17,
      spvOjtCount: 2,
      spvM3Baseline: 64,
      spvM3Surviving: 51,
      spvM5Baseline: 28,
      spvM5Surviving: 27,
      spvOjtToProNormal: 2,
      spvOjtToProAccel: 0,
      spvProToEliteNormal: 1,
      spvProToEliteAccel: 0,
      spvQuarterlyTeamSa: 510,
      spvQuarterlyM3Rate: 0.85,
    );
  }

  void loadSpvPresetB() {
    state = state.copyWith(
      position: PositionType.spv,
      spvQtyRegular: 43,
      spvQtyPxgy: 25,
      spvActiveAgents: 10,
      spvAgentEarnAf: 10,
      spvMob: 16,
      spvOjtCount: 3,
      spvM3Baseline: 32,
      spvM3Surviving: 28,
      spvM5Baseline: 32,
      spvM5Surviving: 31,
      spvOjtToProNormal: 3,
      spvOjtToProAccel: 0,
      spvProToEliteNormal: 2,
      spvProToEliteAccel: 0,
      spvQuarterlyTeamSa: 320,
      spvQuarterlyM3Rate: 0.88,
    );
  }

  void reset() {
    state = state.copyWith(
      f0: 0,
      f50: 0,
      f100: 0,
      f125: 0,
      f200: 0,
      fwa: 0,
      p35: 0,
      p6: 0,
      dsaM3Baseline: 0,
      dsaM3Surviving: 0,
      dsaM5Baseline: 0,
      dsaM5Surviving: 0,
      dsaQuarterlySa: 0,
      dsaQuarterlyM3Rate: 0.0,
      dsaBaselineActiveSubs: 0,
      dsaCurrentActiveSubs: 0,
      spvQtyRegular: 0,
      spvQtyPxgy: 0,
      spvActiveAgents: 0,
      spvAgentEarnAf: 0,
      spvMob: 4,
      spvOjtCount: 0,
      spvM3Baseline: 0,
      spvM3Surviving: 0,
      spvM5Baseline: 0,
      spvM5Surviving: 0,
      spvOjtToProNormal: 0,
      spvOjtToProAccel: 0,
      spvProToEliteNormal: 0,
      spvProToEliteAccel: 0,
      spvQuarterlyTeamSa: 0,
      spvQuarterlyM3Rate: 0.0,
    );
  }
}

final calculatorProvider =
    NotifierProvider<CalculatorNotifier, CalculatorState>(
        () => CalculatorNotifier());
