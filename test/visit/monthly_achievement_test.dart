import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/auth/models/member_status.dart';
import 'package:dsa_incentive_tracker/auth/providers/auth_providers.dart';
import 'package:dsa_incentive_tracker/core/utils/monthly_target_helper.dart';
import 'package:dsa_incentive_tracker/data/models/incentive_record.dart';
import 'package:dsa_incentive_tracker/data/models/visit_activity.dart';
import 'package:dsa_incentive_tracker/data/services/customer_master_service.dart';
import 'package:dsa_incentive_tracker/data/services/visit_team_summary_service.dart';
import 'package:dsa_incentive_tracker/providers/customer_master_provider.dart';
import 'package:dsa_incentive_tracker/providers/history_provider.dart';
import 'package:dsa_incentive_tracker/ui/screens/dashboard_screen.dart';
import 'package:dsa_incentive_tracker/ui/screens/visit_team_summary_screen.dart';

class _StubHistoryNotifier extends HistoryNotifier {
  final List<IncentiveRecord> initialRecords;
  _StubHistoryNotifier(this.initialRecords);

  @override
  Future<List<IncentiveRecord>> build() async => initialRecords;
}

class _FakeVisitSummaryGateway implements VisitSummaryRemoteGateway {
  final List<Map<String, dynamic>> incentiveRows;
  final Map<String, dynamic>? superadminNominalRow;

  _FakeVisitSummaryGateway({
    this.incentiveRows = const [],
    this.superadminNominalRow,
  });

  @override
  Future<List<Map<String, dynamic>>> callGetVisitSummary({
    required String fromDate,
    required String toDate,
  }) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> fetchMemberVisitsPage({
    required String memberId,
    required String fromDate,
    required String toDate,
    VisitCategory? category,
    VisitStatus? status,
    required int fromIndex,
    required int toIndex,
  }) async =>
      const [];

  @override
  Future<Map<String, int>> fetchFormSubmittedCountsByMember({
    required String fromDate,
    required String toDate,
  }) async =>
      const {};

  @override
  Future<Map<String, dynamic>?> fetchFormResponseForMemberVisit({
    required String memberId,
    required String clientId,
  }) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> callGetIncentiveTeamSummary({
    required String monthDate,
  }) async =>
      incentiveRows;

  @override
  Future<Map<String, dynamic>?> fetchSuperadminMemberIncentiveNominal({
    required String memberId,
    required String monthDate,
  }) async =>
      superadminNominalRow;
}

class _NoopCustomerMasterGateway implements CustomerMasterRemoteGateway {
  @override
  String? get currentUserId => 'user-1';

  @override
  Future<List<Map<String, dynamic>>> fetchSalesNamesRpc() async => const [];

  @override
  Future<String> claimSalesNameRpc(String salesName) async => 'success';

  @override
  Future<List<Map<String, dynamic>>> fetchCustomerMasterPage({
    required int fromIndex,
    required int toIndex,
  }) async =>
      const [];

  @override
  Future<Map<String, dynamic>?> fetchMasterStatusRpc() async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchRvaiComplianceRpc({
    required String fromDate,
    required String toDate,
  }) async =>
      const [];
}

IncentiveRecord _buildRecord({
  int? id,
  required String periode,
  String? periodMonth,
  String position = 'Elite',
  int totalSa = 5,
  int f100 = 5,
  double grandTotal = 3673184,
  String? updatedAt,
  bool deleted = false,
}) {
  return IncentiveRecord(
    id: id,
    clientId: 'client-${id ?? 1}',
    periode: periode,
    periodMonth: periodMonth,
    position: position,
    city: 'KAB. CILACAP',
    basicFee: 2773184,
    totalSa: totalSa,
    pmBase: f100 * 100000.0,
    multRate: 0,
    multBonus: 0,
    progInc: totalSa * 80000.0,
    specialInc: 0,
    monthlySubtotal: grandTotal,
    grandTotal: grandTotal,
    f0: 0,
    f50: 0,
    f100: f100,
    f125: 0,
    f200: 0,
    fwa: 0,
    p35: 0,
    p6: 0,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

void main() {
  group('Phase 11E — Monthly Achievement & Team Incentive Summary Tests', () {
    test('selectCurrentMonthIncentiveRecord memilih record bulan berjalan terbaru dan mengabaikan deleted', () {
      final now = DateTime(2026, 11, 15);
      final olderNov = _buildRecord(
        id: 1,
        periode: 'Nov 2026',
        periodMonth: '2026-11-01',
        totalSa: 4,
        updatedAt: '2026-11-10T08:00:00.000Z',
      );
      final newerNov = _buildRecord(
        id: 2,
        periode: 'Nov 2026',
        periodMonth: '2026-11-01',
        totalSa: 8,
        updatedAt: '2026-11-12T10:00:00.000Z',
      );
      final deletedNewestNov = _buildRecord(
        id: 3,
        periode: 'Nov 2026',
        periodMonth: '2026-11-01',
        totalSa: 15,
        updatedAt: '2026-11-14T12:00:00.000Z',
        deleted: true,
      );
      final octRecord = _buildRecord(
        id: 4,
        periode: 'Okt 2026',
        periodMonth: '2026-10-01',
        totalSa: 20,
        updatedAt: '2026-11-15T12:00:00.000Z',
      );

      final selected = selectCurrentMonthIncentiveRecord(
        [olderNov, newerNov, deletedNewestNov, octRecord],
        now: now,
      );
      expect(selected, isNotNull);
      expect(selected!.id, 2);
      expect(selected.totalSa, 8);

      final empty = selectCurrentMonthIncentiveRecord([octRecord], now: now);
      expect(empty, isNull);
    });

    test('simulateNextTierGap menghitung selisih SA ke tier berikutnya menggunakan CalculatorEngine', () {
      // Elite dengan 5 SA (tier 1-6 akt) -> butuh 2 SA lagi untuk naik ke tier 7-9 akt (mult 1.5x)
      final record5Sa = _buildRecord(
        periode: 'Nov 2026',
        periodMonth: '2026-11-01',
        position: 'Elite',
        totalSa: 5,
        f100: 5,
      );
      final sim = simulateNextTierGap(record5Sa);
      expect(sim, isNotNull);
      expect(sim!.missingSa, 2);
      expect(sim.nextTierLabel, contains('7'));
      expect(sim.estimatedDeltaRupiah, greaterThan(0));
    });

    testWidgets('Dashboard menampilkan ajakan bila belum ada record bulan berjalan, dan menampilkan kartu Pencapaian + Simulasi bila ada', (tester) async {
      // 1. Kosong -> tampilkan ajakan
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyProvider.overrideWith(() => _StubHistoryNotifier(const [])),
            currentRoleProvider.overrideWithValue(TeamRole.member),
            canViewAllProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('monthly_achievement_empty_card')),
        findsOneWidget,
      );
      expect(
        find.text('Simpan perhitungan bulan ini di Kalkulator'),
        findsOneWidget,
      );

      // 2. Ada record bulan berjalan -> tampilkan kartu Pencapaian Bulan Ini + Simulasi
      final currentMonthIso = IncentiveRecord.currentMonthIso();
      final activeRecord = _buildRecord(
        id: 10,
        periode: 'Bulan Ini',
        periodMonth: currentMonthIso,
        position: 'Elite',
        totalSa: 5,
        f100: 5,
        grandTotal: 3673184,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            historyProvider.overrideWith(
              () => _StubHistoryNotifier([activeRecord]),
            ),
            currentRoleProvider.overrideWithValue(TeamRole.member),
            canViewAllProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('monthly_achievement_card')), findsOneWidget);
      expect(
        find.byKey(const Key('monthly_achievement_simulation_box')),
        findsOneWidget,
      );
      expect(find.text('Simulasi'), findsOneWidget);
      expect(find.textContaining('Kurang 2 SA'), findsOneWidget);
    });

    testWidgets('Pencapaian Tim Bulan Ini membaca member_position tanpa nominal rupiah, dan tombol Nominal hanya untuk Superadmin', (tester) async {
      final rawRpcRow = <String, dynamic>{
        'member_id': 'sales-uuid-1',
        'member_name': 'Andi Sales',
        'member_position': 'Elite',
        'total_sa': 12,
        'f0': 0,
        'f50': 2,
        'f100': 8,
        'f125': 2,
        'f200': 0,
        'fwa': 0,
        'p35': 0,
        'p6': 0,
        'updated_at': '2026-11-09T08:00:00Z',
      };

      // Pastikan bentuk hasil RPC tidak memiliki kolom nominal
      expect(rawRpcRow.containsKey('grand_total'), isFalse);
      expect(rawRpcRow.containsKey('basic_fee'), isFalse);
      expect(rawRpcRow.containsKey('monthly_subtotal'), isFalse);

      final parsed = TeamIncentiveSummaryRow.fromJson(rawRpcRow);
      expect(parsed.memberPosition, 'Elite');
      expect(parsed.totalSa, 12);

      final fakeGateway = _FakeVisitSummaryGateway(
        incentiveRows: [rawRpcRow],
        superadminNominalRow: {
          'client_id': 'inc-client-1',
          'periode': 'Nov 2026',
          'period_month': '2026-11-01',
          'position': 'Elite',
          'city': 'KAB. CILACAP',
          'basic_fee': 2773184,
          'total_sa': 12,
          'pm_base': 1150000,
          'mult_rate': 2.0,
          'mult_bonus': 2300000,
          'prog_inc': 1455000,
          'special_inc': 0,
          'monthly_subtotal': 7678184,
          'grand_total': 7678184,
          'f0': 0,
          'f50': 2,
          'f100': 8,
          'f125': 2,
          'f200': 0,
          'fwa': 0,
          'p35': 0,
          'p6': 0,
        },
      );

      final fakeSummaryService = VisitTeamSummaryService(
        remoteGateway: fakeGateway,
      );
      final fakeMasterService = CustomerMasterService(
        remoteGateway: _NoopCustomerMasterGateway(),
      );

      // 1. Role SPV / TSC / Admin -> tombol Nominal TIDAK tampil
      for (final nonSuperRole in [
        TeamRole.spv,
        TeamRole.tsc,
        TeamRole.admin,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentRoleProvider.overrideWithValue(nonSuperRole),
              visitTeamSummaryServiceProvider
                  .overrideWithValue(fakeSummaryService),
              customerMasterServiceProvider
                  .overrideWithValue(fakeMasterService),
            ],
            child: const MaterialApp(
              home: VisitTeamSummaryScreen(isOnlineOverride: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('team_incentive_summary_card')),
          findsOneWidget,
        );
        expect(find.text('Andi Sales'), findsOneWidget);
        expect(
          find.byKey(const Key('btn_view_nominal_sales-uuid-1')),
          findsNothing,
        );
      }

      // 2. Role Superadmin -> tombol Nominal tampil & membuka dialog nominal
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoleProvider.overrideWithValue(TeamRole.superadmin),
            visitTeamSummaryServiceProvider
                .overrideWithValue(fakeSummaryService),
            customerMasterServiceProvider.overrideWithValue(fakeMasterService),
          ],
          child: const MaterialApp(
            home: VisitTeamSummaryScreen(isOnlineOverride: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nominalBtn = find.byKey(const Key('btn_view_nominal_sales-uuid-1'));
      expect(nominalBtn, findsOneWidget);

      await tester.tap(nominalBtn);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('superadmin_nominal_dialog')),
        findsOneWidget,
      );
      expect(find.textContaining('Grand Total:'), findsOneWidget);
    });
  });
}
