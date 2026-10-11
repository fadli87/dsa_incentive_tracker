import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/ai/models/coach_log_entry.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/models/incentive_record.dart';
import 'package:dsa_incentive_tracker/data/models/sa_record.dart';
import 'package:dsa_incentive_tracker/data/models/user_profile.dart';

void main() {
  group('Database Migration to Version 6 & Privacy Masking Tests', () {
    final db = DatabaseHelper.instance;

    test('Masking privasi: menghapus deretan angka >= 8 digit (nomor telepon / KTP)', () {
      expect(
        DatabaseHelper.maskPrivacy('Nomor hp pelanggan 081234567890 mau pasang'),
        equals('Nomor hp pelanggan *** mau pasang'),
      );

      expect(
        DatabaseHelper.maskPrivacy('KTP 3301123456780001'),
        equals('KTP ***'),
      );

      // Angka kecil (misal SA atau kecepatan) tidak boleh dimask
      expect(
        DatabaseHelper.maskPrivacy('hitung insentif 15 sa paket 100 mbps'),
        equals('hitung insentif 15 sa paket 100 mbps'),
      );
    });

    test('Database helper menyimpan dan membaca UserProfile, History, dan CoachLog dengan benar', () async {
      // 1. Simpan user profile
      const profile = UserProfile(
        name: 'Fadli Test',
        salesCode: 'DSA-007',
        branch: 'XL SATU CILACAP',
        tsc: 'TSC PIPIN',
      );
      await db.saveUserProfile(profile);
      final readProfile = await db.getUserProfile();
      expect(readProfile.name, equals('Fadli Test'));
      expect(readProfile.salesCode, equals('DSA-007'));

      // 2. Simpan SaRecord
      final saRecord = SaRecord(
        idPelanggan: 'CIL-999',
        nama: 'Budi Santoso',
        alamat: 'Jl. Gatot Subroto No. 10',
        paket: 'XL Satu Fiber 250 Mbps',
        tanggalPasang: '2026-10-11',
      );
      final saId = await db.insertSaRecord(saRecord);
      expect(saId, greaterThan(0));

      final allSa = await db.getAllSaRecords();
      expect(allSa.any((r) => r.idPelanggan == 'CIL-999'), isTrue);

      // 3. Simpan IncentiveRecord
      final incRecord = IncentiveRecord(
        periode: 'Okt 2026',
        position: 'Elite',
        city: 'KAB. CILACAP',
        basicFee: 2000000,
        totalSa: 15,
        pmBase: 1500000,
        multRate: 4.0,
        multBonus: 6000000,
        progInc: 1250000,
        specialInc: 0,
        monthlySubtotal: 8750000,
        grandTotal: 10750000,
      );
      final incId = await db.insertRecord(incRecord);
      expect(incId, greaterThan(0));

      final allInc = await db.getAllRecords();
      expect(allInc.any((r) => r.periode == 'Okt 2026'), isTrue);

      // 4. Simpan CoachLogEntry dengan masking privasi
      final logEntry = CoachLogEntry(
        ts: DateTime.now().millisecondsSinceEpoch,
        queryNorm: 'pelanggan 081298765432 tanya paket',
        intent: 'package_list',
        score: 3.5,
        matched: true,
      );

      final logId = await db.insertCoachLog(logEntry);
      expect(logId, greaterThan(0));

      final recentLogs = await db.getRecentCoachLogs();
      expect(recentLogs, isNotEmpty);
      expect(recentLogs.first.queryNorm, equals('pelanggan *** tanya paket'));

      // 5. Update feedback 👍
      await db.updateCoachFeedback(logId, 1);
      final updatedLogs = await db.getRecentCoachLogs();
      expect(updatedLogs.first.feedback, equals(1));
    });
  });
}
