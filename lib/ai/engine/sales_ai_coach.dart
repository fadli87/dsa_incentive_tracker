import '../../network/models/cell_signal_info.dart';
import '../core/coach_engine.dart';
import '../core/coach_session.dart';
import '../models/quick_action.dart';

/// Legacy response wrapper for backward compatibility
class AiCoachResponse {
  final String text;
  final List<String>? quickReplies;
  final List<QuickAction>? actions;
  final Map<String, dynamic>? metadata;

  const AiCoachResponse({
    required this.text,
    this.quickReplies,
    this.actions,
    this.metadata,
  });
}

/// Thin wrapper delegating to [CoachEngine].
/// @Deprecated('Use CoachEngine directly instead')
@Deprecated('Use CoachEngine directly instead')
class SalesAiCoach {
  static const String welcomeMessage =
      'Halo! Saya **AURA Sales & Network Coach** 🤖⚡\n\n'
      'Saya siap membantu Anda:\n'
      '• 📶 Rekomendasi paket berdasarkan sinyal (FWA vs FTTH)\n'
      '• 💰 Simulasi target & hitung potensi insentif\n'
      '• 🎯 Strategi & script closing ke calon pelanggan\n'
      '• 📋 Info lengkap paket XL Satu, FWA, FMC, & PXGY\n\n'
      'Ketik pertanyaan Anda atau pilih topik cepat di bawah ini!';

  static const List<QuickAction> defaultActions = [
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
      label: 'Perbedaan FWA vs FTTH',
      intent: 'fwa_vs_ftth',
    ),
    QuickAction(
      label: 'Daftar Paket XL Satu',
      intent: 'package_list',
    ),
  ];

  static const List<String> defaultQuickReplies = [
    'Rekomendasi Paket Sinyal',
    'Cara Kejar Target Insentif',
    'Script Closing Pelanggan Rumah',
    'Perbedaan FWA vs FTTH',
    'Daftar Paket XL Satu',
  ];

  static CoachSession _globalSession = CoachSession.initial();

  /// Process user query and return intelligent response delegating to CoachEngine
  static AiCoachResponse reply(String query, {TelephonySnapshot? currentRfSignal, Map<String, int>? currentCalcState}) {
    // Process synchronously using the deterministic engine
    // Since CoachEngine is purely synchronous inside, we can process immediately
    final engineRes = CoachEngine.processQuery(
      query: query,
      session: _globalSession,
      currentRfSignal: currentRfSignal,
      currentCalcState: currentCalcState,
    );

    _globalSession = engineRes.session;

    return AiCoachResponse(
      text: engineRes.text,
      actions: engineRes.actions,
      quickReplies: engineRes.actions.map((a) => a.label).toList(),
      metadata: engineRes.metadata,
    );
  }
}
