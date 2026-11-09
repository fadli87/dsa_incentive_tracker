import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/auth/models/member_status.dart';
import 'package:dsa_incentive_tracker/auth/providers/auth_providers.dart';
import 'package:dsa_incentive_tracker/data/services/sa_team_service.dart';
import 'package:dsa_incentive_tracker/ui/screens/dashboard_screen.dart';
import 'package:dsa_incentive_tracker/ui/screens/sa_team_list_screen.dart';

class _FakeSaTeamRemoteGateway implements SaTeamRemoteGateway {
  final List<Map<String, dynamic>> recordedCalls = [];
  List<Map<String, dynamic>> rowsToReturn;
  bool shouldThrowUnauthorized = false;

  _FakeSaTeamRemoteGateway({this.rowsToReturn = const []});

  @override
  Future<List<Map<String, dynamic>>> listSaCustomers({
    required String search,
    String? userId,
    required int limit,
    required int offset,
  }) async {
    recordedCalls.add({
      'p_search': search,
      'p_user': userId,
      'p_limit': limit,
      'p_offset': offset,
    });
    if (shouldThrowUnauthorized) {
      throw Exception('unauthorized');
    }
    return rowsToReturn;
  }
}

void main() {
  group('Phase 11D — Dashboard Data SA Tim & SaTeamListScreen Read-Only Tests', () {
    testWidgets('Kartu Data SA Tim di Dashboard tersembunyi untuk member dan tampil untuk spv/tsc/admin/superadmin', (tester) async {
      // 1. Role member -> Data SA Tim tersembunyi
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoleProvider.overrideWithValue(TeamRole.member),
            canViewAllProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Data SA Tim'), findsNothing);

      // 2. Role spv/tsc/admin/superadmin -> Data SA Tim tampil
      for (final role in [
        TeamRole.spv,
        TeamRole.tsc,
        TeamRole.admin,
        TeamRole.superadmin,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentRoleProvider.overrideWithValue(role),
              canViewAllProvider.overrideWithValue(true),
            ],
            child: const MaterialApp(home: DashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Data SA Tim'), findsOneWidget);
      }
    });

    testWidgets('SaTeamListScreen menampilkan daftar read-only, menyembunyikan tombol WA/telepon bila nomor tidak valid, dan meneruskan parameter pencarian ke RPC', (tester) async {
      final fakeGateway = _FakeSaTeamRemoteGateway(
        rowsToReturn: [
          {
            'id': 'sa-uuid-1',
            'user_id': 'user-sales-1',
            'member_name': 'Budi Sales',
            'id_pelanggan': '80001111',
            'nama': 'Pelanggan Fiktif Valid',
            'no_hp_utama': '08000000011',
            'no_hp_alternatif': '',
            'alamat': 'Jl. Fiktif Cilacap No. 1',
            'latitude': -7.71,
            'longitude': 109.01,
            'paket': 'FTTH 100 Mbps',
            'tanggal_pasang': '2026-11-01',
          },
          {
            'id': 'sa-uuid-2',
            'user_id': 'user-sales-2',
            'member_name': 'Siti Sales',
            'id_pelanggan': '80002222',
            'nama': 'Pelanggan Fiktif Tanpa HP',
            'no_hp_utama': '123', // tidak valid (< 8 digit)
            'no_hp_alternatif': '',
            'alamat': 'Jl. Fiktif Cilacap No. 2',
            'latitude': null,
            'longitude': null,
            'paket': 'FWA 100 Mbps',
            'tanggal_pasang': '2026-11-02',
          },
        ],
      );

      final fakeService = SaTeamService(
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saTeamServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(home: SaTeamListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Panggilan awal RPC: p_search = '', p_limit = 50, p_offset = 0
      expect(fakeGateway.recordedCalls.length, 1);
      expect(fakeGateway.recordedCalls.first['p_search'], '');
      expect(fakeGateway.recordedCalls.first['p_limit'], 50);
      expect(fakeGateway.recordedCalls.first['p_offset'], 0);

      // 2. Kartu tampil tanpa tombol Edit / Hapus
      expect(find.text('Pelanggan Fiktif Valid'), findsOneWidget);
      expect(find.text('Pelanggan Fiktif Tanpa HP'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);

      // 3. Tombol Telepon, WhatsApp, dan Navigasi tampil untuk sa-uuid-1 (HP valid & koordinat ada)
      expect(find.byKey(const Key('btn_call_sa-uuid-1')), findsOneWidget);
      expect(find.byKey(const Key('btn_wa_sa-uuid-1')), findsOneWidget);
      expect(find.byKey(const Key('btn_nav_sa-uuid-1')), findsOneWidget);

      // 4. Tombol Telepon, WhatsApp, dan Navigasi tersembunyi untuk sa-uuid-2 (HP tidak valid & tanpa koordinat)
      expect(find.byKey(const Key('btn_call_sa-uuid-2')), findsNothing);
      expect(find.byKey(const Key('btn_wa_sa-uuid-2')), findsNothing);
      expect(find.byKey(const Key('btn_nav_sa-uuid-2')), findsNothing);

      // 5. Ketik pencarian -> tunggu debounce 300ms -> memanggil RPC dengan p_search yang benar
      await tester.enterText(
        find.byKey(const Key('sa_team_search_field')),
        '80001111',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(fakeGateway.recordedCalls.length, 2);
      expect(fakeGateway.recordedCalls.last['p_search'], '80001111');
    });
  });
}
