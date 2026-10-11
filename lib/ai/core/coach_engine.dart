import '../../network/models/cell_signal_info.dart';
import '../intents/incentive_handlers.dart';
import '../intents/navigation_handlers.dart';
import '../intents/package_handlers.dart';
import '../intents/script_handlers.dart';
import '../intents/signal_coverage_handlers.dart';
import '../models/quick_action.dart';
import 'coach_session.dart';
import 'entity_extractor.dart';
import 'intent_router.dart';
import 'text_normalizer.dart';

class AiCoachEngineResponse {
  final String text;
  final List<QuickAction> actions;
  final Map<String, dynamic> metadata;
  final CoachSession session;

  const AiCoachEngineResponse({
    required this.text,
    required this.actions,
    this.metadata = const {},
    required this.session,
  });
}

/// Orkestrator utama Coach v2 (Offline, Deterministik).
/// Alur: normalize -> route -> extract -> handler -> update session.
class CoachEngine {
  CoachEngine._();

  /// Memproses query teks bebas dari pengguna
  static AiCoachEngineResponse processQuery({
    required String query,
    required CoachSession session,
    TelephonySnapshot? currentRfSignal,
    Map<String, int>? currentCalcState,
  }) {
    final normalized = TextNormalizer.normalize(query);
    final match = IntentRouter.route(normalized, session: session);

    final response = _dispatch(
      intentId: match.intentId,
      entities: match.entities,
      session: session,
      currentRfSignal: currentRfSignal,
      currentCalcState: currentCalcState,
      suggestions: match.suggestions,
    );

    final updatedSession = session.copyWith(
      lastIntent: match.intentId,
      lastEntities: match.entities,
      lastActive: DateTime.now(),
    );

    return AiCoachEngineResponse(
      text: response.text,
      actions: response.actions,
      metadata: response.metadata,
      session: updatedSession,
    );
  }

  /// Mengeksekusi QuickAction secara langsung (tanpa melalui intent router berbasis teks)
  static AiCoachEngineResponse executeAction({
    required QuickAction action,
    required CoachSession session,
    TelephonySnapshot? currentRfSignal,
    Map<String, int>? currentCalcState,
  }) {
    // Bangun entitas dari args action
    final actionEntities = ExtractedEntities(
      packageType: action.args['type'] as String?,
      totalSa: action.args['totalSa'] as int?,
      segment: action.args['segment'] as String?,
      objection: action.args['objection'] as String?,
      district: action.args['district'] as String?,
    );

    final mergedEntities = actionEntities.mergeWithPrevious(session.lastEntities);

    final response = _dispatch(
      intentId: action.intent,
      entities: mergedEntities,
      session: session,
      currentRfSignal: currentRfSignal,
      currentCalcState: currentCalcState,
      explicitPackageId: action.args['packageId'] as String?,
      explicitType: action.args['type'] as String?,
    );

    final updatedSession = session.copyWith(
      lastIntent: action.intent,
      lastEntities: mergedEntities,
      lastActive: DateTime.now(),
    );

    return AiCoachEngineResponse(
      text: response.text,
      actions: response.actions,
      metadata: response.metadata,
      session: updatedSession,
    );
  }

  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) _dispatch({
    required String intentId,
    required ExtractedEntities entities,
    required CoachSession session,
    TelephonySnapshot? currentRfSignal,
    Map<String, int>? currentCalcState,
    List<String> suggestions = const [],
    String? explicitPackageId,
    String? explicitType,
  }) {
    switch (intentId) {
      case 'greet':
        return NavigationHandlers.handleGreet();

      case 'help':
        return NavigationHandlers.handleHelp();

      case 'incentive_calc':
        return IncentiveHandlers.handleCalc(
          entities: entities,
          currentStateCounts: currentCalcState,
        );

      case 'incentive_scheme_info':
        return IncentiveHandlers.handleSchemeInfo();

      case 'package_list':
        return PackageHandlers.handleList(
          entities: entities,
          explicitType: explicitType,
        );

      case 'package_detail':
        return PackageHandlers.handleDetail(
          entities: entities,
          explicitPackageId: explicitPackageId,
        );

      case 'package_search':
        return PackageHandlers.handleSearch(
          entities: entities,
        );

      case 'package_compare':
        return PackageHandlers.handleCompare(
          entities: entities,
        );

      case 'fwa_vs_ftth':
        return PackageHandlers.handleFwaVsFtth();

      case 'rf_analyze':
        return SignalCoverageHandlers.handleRf(
          rf: currentRfSignal,
          entities: entities,
        );

      case 'coverage_check':
        return SignalCoverageHandlers.handleCoverageCheck(
          entities: entities,
        );

      case 'script_get':
        return ScriptHandlers.handleScript(
          entities: entities,
          explicitType: explicitType,
        );

      case 'target_gap':
        return NavigationHandlers.handleTargetGap(
          currentCalcState: currentCalcState,
        );

      case 'best_product_mix':
        return NavigationHandlers.handleBestProductMix(
          currentCalcState: currentCalcState,
        );

      case 'pace':
        return NavigationHandlers.handlePace(
          currentSa: currentCalcState?.values.fold<int>(0, (int a, int b) => a + b) ?? entities.totalSa ?? 0,
        );

      case 'wa_draft':
        return NavigationHandlers.handleWaDraft();

      case 'nav_speedtest':
        return NavigationHandlers.handleNavSpeedtest();

      case 'nav_coverage_map':
        return NavigationHandlers.handleNavCoverageMap();

      case 'nav_catalog':
        return NavigationHandlers.handleNavCatalog();

      case 'nav_calculator':
        return NavigationHandlers.handleNavCalculator();

      case 'unknown':
      default:
        return NavigationHandlers.handleUnknown(
          suggestions: suggestions,
        );
    }
  }
}
