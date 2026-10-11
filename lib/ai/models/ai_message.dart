import 'quick_action.dart';

enum AiSender { user, assistant, system }

class AiMessage {
  final String id;
  final AiSender sender;
  final String text;
  final DateTime timestamp;
  final List<QuickAction>? actions;
  final List<String>? quickReplies; // Legacy backward compatibility
  final Map<String, dynamic>? metadata;

  const AiMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.actions,
    this.quickReplies,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender.name,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      if (actions != null) 'actions': actions!.map((a) => a.toMap()).toList(),
      if (quickReplies != null) 'quickReplies': quickReplies,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory AiMessage.fromMap(Map<String, dynamic> map) {
    List<QuickAction>? parsedActions;
    if (map['actions'] != null) {
      parsedActions = (map['actions'] as List<dynamic>)
          .map((a) => QuickAction.fromMap(a as Map<String, dynamic>))
          .toList();
    }

    return AiMessage(
      id: map['id'] as String,
      sender: AiSender.values.firstWhere(
        (e) => e.name == map['sender'],
        orElse: () => AiSender.assistant,
      ),
      text: map['text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      actions: parsedActions,
      quickReplies: (map['quickReplies'] as List<dynamic>?)?.cast<String>(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
