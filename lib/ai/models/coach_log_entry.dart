/// Model representasi data log evaluasi interaksi AI Coach offline untuk continuous learning.
class CoachLogEntry {
  final int? id;
  final int ts;
  final String queryNorm;
  final String intent;
  final double score;
  final bool matched;
  final int? feedback; // 1 = 👍 Suka, -1 = 👎 Tidak Suka, null = Belum ada feedback

  const CoachLogEntry({
    this.id,
    required this.ts,
    required this.queryNorm,
    required this.intent,
    required this.score,
    required this.matched,
    this.feedback,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'ts': ts,
    'query_norm': queryNorm,
    'intent': intent,
    'score': score,
    'matched': matched ? 1 : 0,
    'feedback': feedback,
  };

  factory CoachLogEntry.fromMap(Map<String, dynamic> map) => CoachLogEntry(
    id: map['id'] as int?,
    ts: map['ts'] as int? ?? 0,
    queryNorm: map['query_norm'] as String? ?? '',
    intent: map['intent'] as String? ?? '',
    score: (map['score'] as num?)?.toDouble() ?? 0.0,
    matched: (map['matched'] as int? ?? 0) == 1,
    feedback: map['feedback'] as int?,
  );

  CoachLogEntry copyWith({
    int? id,
    int? ts,
    String? queryNorm,
    String? intent,
    double? score,
    bool? matched,
    int? feedback,
  }) {
    return CoachLogEntry(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      queryNorm: queryNorm ?? this.queryNorm,
      intent: intent ?? this.intent,
      score: score ?? this.score,
      matched: matched ?? this.matched,
      feedback: feedback ?? this.feedback,
    );
  }
}
