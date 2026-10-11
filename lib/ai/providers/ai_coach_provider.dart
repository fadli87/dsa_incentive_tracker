import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/coach_engine.dart';
import '../core/coach_session.dart';
import '../models/ai_message.dart';
import '../models/quick_action.dart';
import '../../network/models/cell_signal_info.dart';

class AiCoachState {
  final List<AiMessage> messages;
  final bool isThinking;
  final CoachSession session;

  const AiCoachState({
    this.messages = const [],
    this.isThinking = false,
    required this.session,
  });

  AiCoachState copyWith({
    List<AiMessage>? messages,
    bool? isThinking,
    CoachSession? session,
  }) =>
      AiCoachState(
        messages: messages ?? this.messages,
        isThinking: isThinking ?? this.isThinking,
        session: session ?? this.session,
      );
}

class AiCoachNotifier extends Notifier<AiCoachState> {
  static const String welcomeMessage =
      'Halo! Saya **AURA Sales & Network Coach** 🤖⚡\n\n'
      'Saya siap membantu Anda:\n'
      '• 📶 Rekomendasi paket berdasarkan sinyal (FWA vs FTTH)\n'
      '• 💰 Simulasi target & hitung potensi insentif\n'
      '• 🎯 Strategi & script closing ke calon pelanggan\n'
      '• 📋 Info lengkap paket XL Satu, FWA, FMC, & PXGY\n\n'
      'Ketik pertanyaan Anda atau pilih topik cepat di bawah ini!';

  static const List<QuickAction> initialActions = [
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

  @override
  AiCoachState build() {
    return AiCoachState(
      messages: [
        AiMessage(
          id: 'welcome',
          sender: AiSender.assistant,
          text: welcomeMessage,
          timestamp: DateTime.now(),
          actions: initialActions,
          quickReplies: initialActions.map((a) => a.label).toList(),
        ),
      ],
      isThinking: false,
      session: CoachSession.initial(),
    );
  }

  Future<void> sendMessage(
    String text, {
    TelephonySnapshot? currentRfSignal,
    Map<String, int>? currentCalcState,
  }) async {
    final query = text.trim();
    if (query.isEmpty) return;

    final userMsg = AiMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: AiSender.user,
      text: query,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
    );

    // Micro delay untuk interaksi alami (< 100ms)
    await Future.delayed(const Duration(milliseconds: 80));

    final engineRes = CoachEngine.processQuery(
      query: query,
      session: state.session,
      currentRfSignal: currentRfSignal,
      currentCalcState: currentCalcState,
    );

    final aiMsg = AiMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_ai',
      sender: AiSender.assistant,
      text: engineRes.text,
      timestamp: DateTime.now(),
      actions: engineRes.actions,
      quickReplies: engineRes.actions.map((a) => a.label).toList(),
      metadata: engineRes.metadata,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMsg],
      isThinking: false,
      session: engineRes.session,
    );
  }

  Future<void> runAction(
    QuickAction action, {
    TelephonySnapshot? currentRfSignal,
    Map<String, int>? currentCalcState,
  }) async {
    final userMsg = AiMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: AiSender.user,
      text: action.label,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
    );

    await Future.delayed(const Duration(milliseconds: 60));

    final engineRes = CoachEngine.executeAction(
      action: action,
      session: state.session,
      currentRfSignal: currentRfSignal,
      currentCalcState: currentCalcState,
    );

    final aiMsg = AiMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_ai',
      sender: AiSender.assistant,
      text: engineRes.text,
      timestamp: DateTime.now(),
      actions: engineRes.actions,
      quickReplies: engineRes.actions.map((a) => a.label).toList(),
      metadata: engineRes.metadata,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMsg],
      isThinking: false,
      session: engineRes.session,
    );
  }

  void clearHistory() {
    state = build();
  }
}

final aiCoachNotifierProvider =
    NotifierProvider<AiCoachNotifier, AiCoachState>(
  AiCoachNotifier.new,
);
