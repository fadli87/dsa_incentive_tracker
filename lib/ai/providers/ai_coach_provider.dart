import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/sales_ai_coach.dart';
import '../models/ai_message.dart';
import '../../network/models/cell_signal_info.dart';

class AiCoachState {
  final List<AiMessage> messages;
  final bool isThinking;

  const AiCoachState({
    this.messages = const [],
    this.isThinking = false,
  });

  AiCoachState copyWith({
    List<AiMessage>? messages,
    bool? isThinking,
  }) =>
      AiCoachState(
        messages: messages ?? this.messages,
        isThinking: isThinking ?? this.isThinking,
      );
}

class AiCoachNotifier extends Notifier<AiCoachState> {
  @override
  AiCoachState build() {
    return AiCoachState(
      messages: [
        AiMessage(
          id: 'welcome',
          sender: AiSender.assistant,
          text: SalesAiCoach.welcomeMessage,
          timestamp: DateTime.now(),
          quickReplies: SalesAiCoach.defaultQuickReplies,
        ),
      ],
      isThinking: false,
    );
  }

  Future<void> sendMessage(String text, {TelephonySnapshot? currentRfSignal}) async {
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

    // Micro delay for natural interaction (< 150ms)
    await Future.delayed(const Duration(milliseconds: 120));

    final response = SalesAiCoach.reply(query, currentRfSignal: currentRfSignal);

    final aiMsg = AiMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_ai',
      sender: AiSender.assistant,
      text: response.text,
      timestamp: DateTime.now(),
      quickReplies: response.quickReplies,
      metadata: response.metadata,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMsg],
      isThinking: false,
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
