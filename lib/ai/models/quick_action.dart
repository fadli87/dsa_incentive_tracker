enum CoachDestination {
  speedTest,
  coverageMap,
  catalog,
  calculator,
  signalTab,
}

/// Representasi aksi cepat (chip interaktif) pengganti string quick replies sederhana.
/// Memungkinkan eksekusi intent deterministik dengan parameter terstruktur atau navigasi layar.
class QuickAction {
  final String label; // Teks yang ditampilkan pada chip UI
  final String intent; // ID intent target (misal: 'package_list', 'incentive_calc')
  final Map<String, dynamic> args; // Parameter terstruktur (misal: {'type': 'fwa'})
  final CoachDestination? destination; // Navigasi tujuan

  const QuickAction({
    required this.label,
    required this.intent,
    this.args = const {},
    this.destination,
  });

  bool get isNavAction => destination != null;

  factory QuickAction.nav({
    required String label,
    required CoachDestination destination,
    Map<String, dynamic> args = const {},
  }) {
    return QuickAction(
      label: label,
      intent: 'nav_${destination.name}',
      args: args,
      destination: destination,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'intent': intent,
      'args': args,
      if (destination != null) 'destination': destination!.name,
    };
  }

  factory QuickAction.fromMap(Map<String, dynamic> map) {
    CoachDestination? dest;
    if (map['destination'] != null) {
      dest = CoachDestination.values.firstWhere(
        (e) => e.name == map['destination'],
        orElse: () => CoachDestination.catalog,
      );
    }
    return QuickAction(
      label: map['label'] as String,
      intent: map['intent'] as String,
      args: (map['args'] as Map<String, dynamic>?) ?? const {},
      destination: dest,
    );
  }

  @override
  String toString() => 'QuickAction($label -> $intent, dest: $destination, args: $args)';
}
