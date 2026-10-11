import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('No UI Imports in AI Core and Intent Handlers', () {
    test('lib/ai/ tidak boleh mengimpor UI screens secara langsung (selain ai_coach_chat_sheet)', () {
      final aiDir = Directory('lib/ai');
      expect(aiDir.existsSync(), isTrue);

      final files = aiDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

      for (final file in files) {
        // ai_coach_chat_sheet.dart diperbolehkan karena merupakan UI bridge
        if (file.path.contains('ai_coach_chat_sheet.dart')) continue;

        final content = file.readAsStringSync();
        final lines = content.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('import ') && line.contains('/ui/screens/')) {
            fail('Dilarang mengimpor UI screens di ${file.path}:${i + 1} -> "$line". Gunakan CoachDestination enum untuk navigasi.');
          }
        }
      }
    });
  });
}
