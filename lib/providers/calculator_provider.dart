import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/engine/calculator_engine.dart';
import '../core/models/calculator_models.dart';

class CalculatorState {
  final PositionType position;
  final String city;
  final int f0, f50, f100, f125, f200, fwa, p35, p6;
  final CalculationResult calculationResult;
  final Map<String, dynamic> results;

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
    required this.calculationResult,
    required this.results,
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
  }) {
    final newPosition = position ?? this.position;
    final newCity = city ?? this.city;
    final newF0 = f0 ?? this.f0;
    final newF50 = f50 ?? this.f50;
    final newF100 = f100 ?? this.f100;
    final newF125 = f125 ?? this.f125;
    final newF200 = f200 ?? this.f200;
    final newFwa = fwa ?? this.fwa;
    final newP35 = p35 ?? this.p35;
    final newP6 = p6 ?? this.p6;

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
    );

    final legacyMap = CalculatorEngine.calculate(
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
      calculationResult: detailedResult,
      results: legacyMap,
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

    final legacyMap = CalculatorEngine.calculate(
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

    return CalculatorState(
      position: initialPos,
      city: initialCity,
      calculationResult: detailedResult,
      results: legacyMap,
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
    }
  }

  void reset() {
    state = CalculatorState(
      position: state.position,
      city: state.city,
      calculationResult: CalculatorEngine.calculateDetailed(
        position: state.position,
        city: state.city,
        f0: 0,
        f50: 0,
        f100: 0,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      ),
      results: CalculatorEngine.calculate(
        position: state.position,
        city: state.city,
        f0: 0,
        f50: 0,
        f100: 0,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      ),
    );
  }
}

final calculatorProvider =
    NotifierProvider<CalculatorNotifier, CalculatorState>(
        () => CalculatorNotifier());
