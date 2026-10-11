import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/ai/core/script_repository.dart';
import 'package:dsa_incentive_tracker/core/catalog/package_catalog.dart';

void main() {
  group('Scripts Data Library & Safe Formatting Tests', () {
    test('File assets/coach/scripts.json ada dan dapat diparsing dengan skema valid', () {
      final file = File('assets/coach/scripts.json');
      expect(file.existsSync(), isTrue, reason: 'assets/coach/scripts.json harus terdaftar');

      final content = file.readAsStringSync();
      final scripts = ScriptRepository.getAllScripts(jsonSource: content);
      expect(scripts, isNotEmpty);

      for (final s in scripts) {
        expect(s.id, isNotEmpty);
        expect(s.type, isNotEmpty);
        expect(s.segment, isNotEmpty);
        expect(s.text, isNotEmpty);
      }
    });

    test('Script formatting mengganti placeholder dengan benar dan tidak menyisakan kurung kurawal mentah', () {
      final samplePkg = PackageCatalog.findById('ftth-hero-250-mbps')!;
      const raw = 'Paket {paket} seharga {harga} dengan kecepatan {speed}.';

      final formatted = ScriptRepository.formatScript(raw, package: samplePkg);

      expect(formatted, contains(samplePkg.title));
      expect(formatted, contains('250 Mbps'));
      expect(formatted, isNot(contains('{paket}')));
      expect(formatted, isNot(contains('{harga}')));
      expect(formatted, isNot(contains('{speed}')));
    });

    test('Kalimat dengan placeholder yang tidak dapat diisi akan dibuang (tidak menampilkan kurung kurawal mentah)', () {
      const textWithUnfulfilled = 'Kalimat pertama valid. Kalimat kedua butuh {placeholder_tidak_ada}. Kalimat ketiga juga valid.';
      final formatted = ScriptRepository.formatScript(textWithUnfulfilled);

      expect(formatted, contains('Kalimat pertama valid.'));
      expect(formatted, contains('Kalimat ketiga juga valid.'));
      expect(formatted, isNot(contains('placeholder_tidak_ada')));
      expect(formatted, isNot(contains('{')));
    });

    test('Script yang sudah kedaluwarsa (validUntil lewat) tidak akan digunakan', () {
      final expiredScript = SalesScript(
        id: 'expired_01',
        type: 'closing',
        segment: ['rumah'],
        text: 'Promo sudah lewat',
        validUntil: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(expiredScript.isExpired, isTrue);
    });
  });
}
