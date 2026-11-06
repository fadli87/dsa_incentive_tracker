import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dsa_incentive_tracker/ai/models/coach_log_entry.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/models/incentive_record.dart';
import 'package:dsa_incentive_tracker/data/models/sa_record.dart';
import 'package:dsa_incentive_tracker/data/models/user_profile.dart';
import 'package:dsa_incentive_tracker/data/models/visit_activity.dart';

void main() {
  sqfliteFfiInit();

  group('Database Migration to Version 6 & 7 & Privacy Masking Tests', () {
    final db = DatabaseHelper.instance;

    setUp(() {
      db.clearInMemoryVisits();
    });

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

    test('Migrasi SQLite 6 -> 7 mempertahankan data history, sa_history, user_profile, dan coach_log secara utuh', () async {
      final ffiDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (sqDb, _) async {
            await sqDb.execute('''
              CREATE TABLE history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                periode TEXT NOT NULL,
                position TEXT NOT NULL DEFAULT 'Elite',
                city TEXT NOT NULL DEFAULT 'KAB. CILACAP',
                basic_fee REAL NOT NULL DEFAULT 0.0,
                total_sa INTEGER NOT NULL,
                pm_base REAL NOT NULL,
                mult_rate REAL NOT NULL,
                mult_bonus REAL NOT NULL,
                prog_inc REAL NOT NULL,
                special_inc REAL NOT NULL,
                monthly_subtotal REAL NOT NULL DEFAULT 0.0,
                grand_total REAL NOT NULL,
                f0 INTEGER NOT NULL DEFAULT 0,
                f50 INTEGER NOT NULL DEFAULT 0,
                f100 INTEGER NOT NULL DEFAULT 0,
                f125 INTEGER NOT NULL DEFAULT 0,
                f200 INTEGER NOT NULL DEFAULT 0,
                fwa INTEGER NOT NULL DEFAULT 0,
                p35 INTEGER NOT NULL DEFAULT 0,
                p6 INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await sqDb.execute('''
              CREATE TABLE sa_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_pelanggan TEXT NOT NULL,
                nama TEXT NOT NULL,
                no_hp_utama TEXT NOT NULL DEFAULT '',
                no_hp_alternatif TEXT NOT NULL DEFAULT '',
                alamat TEXT NOT NULL,
                latitude REAL,
                longitude REAL,
                paket TEXT NOT NULL,
                tanggal_pasang TEXT NOT NULL
              )
            ''');
            await sqDb.execute('''
              CREATE TABLE user_profile (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                sales_code TEXT NOT NULL,
                branch TEXT NOT NULL DEFAULT 'XL SATU CILACAP',
                tsc TEXT NOT NULL DEFAULT 'TSC PIPIN'
              )
            ''');
            await sqDb.execute('''
              CREATE TABLE coach_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts INTEGER NOT NULL,
                query_norm TEXT NOT NULL,
                intent TEXT NOT NULL,
                score REAL NOT NULL,
                matched INTEGER NOT NULL,
                feedback INTEGER
              )
            ''');
          },
        ),
      );
      addTearDown(() async => await ffiDb.close());

      // Isi data pada versi 6
      await ffiDb.insert('history', {
        'periode': 'Nov 2026',
        'position': 'Elite',
        'city': 'KAB. CILACAP',
        'basic_fee': 2000000.0,
        'total_sa': 20,
        'pm_base': 2000000.0,
        'mult_rate': 4.0,
        'mult_bonus': 8000000.0,
        'prog_inc': 1500000.0,
        'special_inc': 0.0,
        'monthly_subtotal': 9500000.0,
        'grand_total': 11500000.0,
      });
      await ffiDb.insert('sa_history', {
        'id_pelanggan': '32001122',
        'nama': 'Siti Aminah',
        'alamat': 'Jl. Merdeka Cilacap',
        'paket': 'FWA Hero 100 Mbps',
        'tanggal_pasang': '2026-11-01',
      });
      await ffiDb.insert('user_profile', {
        'id': 1,
        'name': 'Rekan Sales Cilacap',
        'sales_code': 'DSA-101',
        'branch': 'XL SATU CILACAP',
        'tsc': 'TSC PIPIN',
      });
      await ffiDb.insert('coach_log', {
        'ts': 1700000000000,
        'query_norm': 'paket fwa murah',
        'intent': 'package_list',
        'score': 4.2,
        'matched': 1,
      });

      // Jalankan migrasi 6 -> 7
      await db.runUpgradeForTest(ffiDb, 6, 7);

      // Pastikan semua data lama di v6 tetap utuh
      final historyRows = await ffiDb.query('history');
      final saRows = await ffiDb.query('sa_history');
      final profileRows = await ffiDb.query('user_profile');
      final coachRows = await ffiDb.query('coach_log');

      expect(historyRows.length, 1);
      expect(historyRows.first['periode'], 'Nov 2026');
      expect(saRows.length, 1);
      expect(saRows.first['nama'], 'Siti Aminah');
      expect(profileRows.length, 1);
      expect(profileRows.first['sales_code'], 'DSA-101');
      expect(coachRows.length, 1);
      expect(coachRows.first['query_norm'], 'paket fwa murah');

      // Pastikan tabel visit_activities terbentuk dan dapat di-insert
      final visitId = await ffiDb.insert('visit_activities', {
        'client_id': 'uuid-fiktif-001',
        'customer_id': '88990011',
        'customer_name': 'Pelanggan Fiktif',
        'category': 'rvai',
        'status': 'belum',
        'planned_date': '2026-11-06',
        'updated_at': '2026-11-06T03:00:00Z',
      });
      expect(visitId, greaterThan(0));
    });

    test('VisitCategory & VisitStatus enum fromString aman terhadap nilai tak dikenal', () {
      expect(VisitCategory.fromString('rvai'), VisitCategory.rvai);
      expect(VisitCategory.fromString('RVAI'), VisitCategory.rvai);
      expect(VisitCategory.fromString('dismantle'), VisitCategory.dismantle);
      expect(VisitCategory.fromString('unpaid'), VisitCategory.unpaid);
      expect(VisitCategory.fromString('kategori_aneh'), VisitCategory.rvai);
      expect(VisitCategory.fromString(null), VisitCategory.rvai);

      expect(VisitStatus.fromString('belum'), VisitStatus.belum);
      expect(VisitStatus.fromString('sudah_visit'), VisitStatus.sudahVisit);
      expect(VisitStatus.fromString('follow_up'), VisitStatus.followUp);
      expect(VisitStatus.fromString('status_aneh'), VisitStatus.belum);
      expect(VisitStatus.fromString(null), VisitStatus.belum);
    });

    test('VisitActivity CRUD, soft delete, sync queue, dan hitungan per kategori bekerja akurat', () async {
      const dateToday = '2026-11-06';
      final v1 = VisitActivity(
        clientId: 'client-uuid-1',
        customerId: '10002001',
        customerName: 'Pelanggan Satu',
        category: VisitCategory.rvai,
        status: VisitStatus.belum,
        address: 'Jl. Diponegoro No. 1',
        packageName: 'XL Satu Fiber',
        latitude: -7.698,
        longitude: 109.023,
        plannedDate: dateToday,
        updatedAt: '2026-11-06T01:00:00Z',
      );
      final v2 = VisitActivity(
        clientId: 'client-uuid-2',
        customerId: '10002002',
        customerName: 'Pelanggan Dua',
        category: VisitCategory.dismantle,
        status: VisitStatus.followUp,
        plannedDate: dateToday,
        updatedAt: '2026-11-06T01:05:00Z',
      );
      final v3 = VisitActivity(
        clientId: 'client-uuid-3',
        customerId: '10002003',
        customerName: 'Pelanggan Tiga',
        category: VisitCategory.unpaid,
        status: VisitStatus.sudahVisit,
        plannedDate: '2026-11-07',
        updatedAt: '2026-11-06T01:10:00Z',
      );

      final id1 = await db.insertVisit(v1);
      final id2 = await db.insertVisit(v2);
      await db.insertVisit(v3);

      expect(id1, greaterThan(0));
      expect(id2, greaterThan(0));

      // Hitungan per kategori untuk 2026-11-06
      final counts = await db.visitCountsByCategory(dateToday);
      expect(counts[VisitCategory.rvai], 1);
      expect(counts[VisitCategory.dismantle], 1);
      expect(counts[VisitCategory.unpaid], 0);

      // Query per tanggal & filter kategori
      final allToday = await db.getVisitsByDate(dateToday);
      expect(allToday.length, 2);
      final onlyRvai = await db.getVisitsByDate(dateToday, category: VisitCategory.rvai);
      expect(onlyRvai.length, 1);
      expect(onlyRvai.first.customerId, '10002001');

      // Query rentang tanggal
      final inRange = await db.getVisitsByRange('2026-11-06', '2026-11-07');
      expect(inRange.length, 3);

      // Semua 3 baris awalnya pending sync (sync_state == 0)
      final pendingBefore = await db.getPendingVisits();
      expect(pendingBefore.length, 3);

      // Tandai synced
      await db.markVisitsSynced(['client-uuid-1', 'client-uuid-2', 'client-uuid-3']);
      expect((await db.getPendingVisits()), isEmpty);

      // Update visit otomatis mengembalikan sync_state = 0
      final savedV1 = (await db.getVisitsByDate(dateToday, category: VisitCategory.rvai)).first;
      await db.updateVisit(savedV1.copyWith(status: VisitStatus.sudahVisit, note: 'Sudah dikunjungi'));
      final pendingAfterUpdate = await db.getPendingVisits();
      expect(pendingAfterUpdate.length, 1);
      expect(pendingAfterUpdate.first.clientId, 'client-uuid-1');
      expect(pendingAfterUpdate.first.status, VisitStatus.sudahVisit);

      // Mark synced lagi, lalu softDeleteVisit -> masuk antrean pending sebagai deleted
      await db.markVisitsSynced(['client-uuid-1']);
      await db.softDeleteVisit(id2);

      final afterDeleteToday = await db.getVisitsByDate(dateToday);
      expect(afterDeleteToday.length, 1);
      final pendingAfterDelete = await db.getPendingVisits();
      expect(pendingAfterDelete.length, 1);
      expect(pendingAfterDelete.first.clientId, 'client-uuid-2');
      expect(pendingAfterDelete.first.deleted, isTrue);
      expect(pendingAfterDelete.first.toSupabaseJson()['deleted_at'], isNotNull);
    });

    test('Isolasi data lokal per akun: baris akun pertama tidak pernah dikirim sebagai milik akun kedua', () async {
      db.clearInMemoryVisits();

      // Akun pertama ('user-akun-1') membuat 2 baris visit
      await db.insertVisit(
        const VisitActivity(
          clientId: 'cid-user1-a',
          ownerUserId: 'user-akun-1',
          customerId: '11100011',
          customerName: 'Pelanggan Akun 1',
          category: VisitCategory.rvai,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T08:00:00Z',
        ),
      );

      // Pastikan getPendingVisits untuk 'user-akun-2' TIDAK mengembalikan baris 'user-akun-1'
      final pendingForUser2BeforeIsolate =
          await db.getPendingVisits(ownerUserId: 'user-akun-2');
      expect(pendingForUser2BeforeIsolate, isEmpty);

      // Saat 'user-akun-2' login di database yang sama, isolateVisitsForUser membersihkan baris akun lama
      await db.isolateVisitsForUser('user-akun-2');
      expect(await db.getPendingVisits(ownerUserId: 'user-akun-2'), isEmpty);
      expect(await db.getVisitsByDate('2026-11-06'), isEmpty);

      // 'user-akun-2' membuat baris baru -> diikat ke 'user-akun-2'
      await db.insertVisit(
        const VisitActivity(
          clientId: 'cid-user2-a',
          customerId: '22200022',
          customerName: 'Pelanggan Akun 2',
          category: VisitCategory.unpaid,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T09:00:00Z',
        ),
      );
      await db.isolateVisitsForUser('user-akun-2');
      final pendingUser2 = await db.getPendingVisits(ownerUserId: 'user-akun-2');
      expect(pendingUser2.length, 1);
      expect(pendingUser2.first.clientId, 'cid-user2-a');
      expect(pendingUser2.first.ownerUserId, 'user-akun-2');
    });
  });
}
