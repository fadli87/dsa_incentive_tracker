import 'entity_extractor.dart';

/// Konteks sesi percakapan offline multi-turn.
/// Menyimpan intent terakhir dan entitas yang diekstrak untuk menangani pertanyaan lanjutan.
class CoachSession {
  final String? lastIntent;
  final ExtractedEntities? lastEntities;
  final DateTime lastActive;

  const CoachSession({
    this.lastIntent,
    this.lastEntities,
    required this.lastActive,
  });

  factory CoachSession.initial() => CoachSession(
        lastActive: DateTime.now(),
      );

  CoachSession copyWith({
    String? lastIntent,
    ExtractedEntities? lastEntities,
    DateTime? lastActive,
  }) {
    return CoachSession(
      lastIntent: lastIntent ?? this.lastIntent,
      lastEntities: lastEntities ?? this.lastEntities,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
