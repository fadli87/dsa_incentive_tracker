enum AiSender { user, assistant, system }

class AiMessage {
  final String id;
  final AiSender sender;
  final String text;
  final DateTime timestamp;
  final List<String>? quickReplies;
  final Map<String, dynamic>? metadata;

  const AiMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.quickReplies,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender.name,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'quickReplies': quickReplies,
      'metadata': metadata,
    };
  }

  factory AiMessage.fromMap(Map<String, dynamic> map) {
    return AiMessage(
      id: map['id'] as String,
      sender: AiSender.values.firstWhere(
        (e) => e.name == map['sender'],
        orElse: () => AiSender.assistant,
      ),
      text: map['text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      quickReplies: (map['quickReplies'] as List<dynamic>?)?.cast<String>(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
