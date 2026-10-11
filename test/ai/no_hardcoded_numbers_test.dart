import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('No Hardcoded Numbers in AI Intent Handlers', () {
    test('File-file di lib/ai/intents/ tidak boleh berisi literal angka harga atau insentif (Rp 123.456)', () {
      final intentsDir = Directory('lib/ai/intents');
      expect(intentsDir.existsSync(), isTrue, reason: 'Directory lib/ai/intents harus ada');

      final files = intentsDir.listSync().whereType<File>().toList();
      expect(files.isNotEmpty, isTrue);

      final hardcodedRpRegex = RegExp(r'''['"][^'"]*Rp\s?\d+[^'"]*['"]''');

      for (final file in files) {
        final content = file.readAsStringSync();
        final lines = content.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Abaikan komentar
          if (line.trim().startsWith('//') || line.trim().startsWith('/*') || line.trim().startsWith('*')) {
            continue;
          }

          // Cek apakah ada literal string yang menuliskan "Rp 50.000" atau "Rp 100.000" secara hardcoded
          final match = hardcodedRpRegex.firstMatch(line);
          expect(
            match,
            isNull,
            reason: 'Ditemukan angka literal hardcoded di ${file.path}:${i + 1} -> "$line". Semua angka harus diambil dari CalculatorEngine/PackageCatalog/IncentiveBucket.',
          );
        }
      }
    });
  });
}
