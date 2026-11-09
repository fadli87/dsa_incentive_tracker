import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dsa_incentive_tracker/auth/models/access_cache.dart';
import 'package:dsa_incentive_tracker/auth/models/member_status.dart';
import 'package:dsa_incentive_tracker/auth/models/team_member_item.dart';
import 'package:dsa_incentive_tracker/auth/providers/auth_providers.dart';
import 'package:dsa_incentive_tracker/auth/screens/super_admin_panel_screen.dart';
import 'package:dsa_incentive_tracker/data/models/master_customer.dart';
import 'package:dsa_incentive_tracker/data/models/user_profile.dart';
import 'package:dsa_incentive_tracker/data/models/visit_activity.dart';
import 'package:dsa_incentive_tracker/data/models/visit_form_response.dart';
import 'package:dsa_incentive_tracker/data/services/customer_master_service.dart';
import 'package:dsa_incentive_tracker/data/services/visit_team_summary_service.dart';
import 'package:dsa_incentive_tracker/providers/customer_master_provider.dart';
import 'package:dsa_incentive_tracker/providers/user_info_provider.dart';
import 'package:dsa_incentive_tracker/ui/screens/dashboard_screen.dart';
import 'package:dsa_incentive_tracker/ui/screens/visit_team_summary_screen.dart';

class _FakeUserInfoNotifier extends UserInfoNotifier {
  @override
  Future<UserProfile> build() async {
    return UserProfile(
      name: 'Sales Fiktif',
      salesCode: 'DSA-TEST',
      branch: 'XL SATU CILACAP',
      tsc: 'TSC PIPIN',
    );
  }
}

class _FakeVisitSummaryGateway implements VisitSummaryRemoteGateway {
  final List<Map<String, dynamic>> rpcRows;
  final List<Map<String, dynamic>> memberVisitRows;
  final bool shouldThrowUnauthorized;

  _FakeVisitSummaryGateway({
    this.rpcRows = const [],
    this.memberVisitRows = const [],
    this.shouldThrowUnauthorized = false,
  });

  @override
  Future<List<Map<String, dynamic>>> callGetVisitSummary({
    required String fromDate,
    required String toDate,
  }) async {
    if (shouldThrowUnauthorized) {
      throw const PostgrestException(message: 'unauthorized', code: 'P0001');
    }
    return rpcRows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMemberVisitsPage({
    required String memberId,
    required String fromDate,
    required String toDate,
    VisitCategory? category,
    VisitStatus? status,
    required int fromIndex,
    required int toIndex,
  }) async {
    return memberVisitRows.where((r) => r['user_id'] == memberId).toList();
  }

  @override
  Future<Map<String, int>> fetchFormSubmittedCountsByMember({
    required String fromDate,
    required String toDate,
  }) async => const {};

  @override
  Future<Map<String, dynamic>?> fetchFormResponseForMemberVisit({
    required String memberId,
    required String clientId,
  }) async => null;
}

void main() {
  group('VisitTeamSummaryService & RPC Parsing (Fase 6)', () {
    test('aggregateRpcRows mengelompokkan per sales, kategori, dan status secara akurat', () async {
      final gateway = _FakeVisitSummaryGateway(
        rpcRows: [
          {
            'member_id': 'sales-1',
            'member_name': 'Budi Sales',
            'member_email': 'budi@example.test',
            'category': 'rvai',
            'status': 'sudah_visit',
            'total': 5,
          },
          {
            'member_id': 'sales-1',
            'member_name': 'Budi Sales',
            'member_email': 'budi@example.test',
            'category': 'dismantle',
            'status': 'belum',
            'total': 3,
          },
          {
            'member_id': 'sales-2',
            'member_name': 'Siti Sales',
            'member_email': 'siti@example.test',
            'category': 'unpaid',
            'status': 'follow_up',
            'total': 10,
          },
        ],
      );

      final service = VisitTeamSummaryService(remoteGateway: gateway);
      final summaries = await service.fetchTeamSummary(
        fromDate: '2026-11-01',
        toDate: '2026-11-30',
      );

      expect(summaries.length, 2);
      // Diurutkan berdasarkan total terbanyak (sales-2: 10, sales-1: 8)
      expect(summaries.first.memberId, 'sales-2');
      expect(summaries.first.total, 10);
      expect(summaries.first.byCategory[VisitCategory.unpaid], 10);
      expect(summaries.first.byStatus[VisitStatus.followUp], 10);

      final budi = summaries.last;
      expect(budi.memberId, 'sales-1');
      expect(budi.total, 8);
      expect(budi.byCategory[VisitCategory.rvai], 5);
      expect(budi.byCategory[VisitCategory.dismantle], 3);
      expect(budi.byCategory[VisitCategory.unpaid], 0);
      expect(budi.byStatus[VisitStatus.sudahVisit], 5);
      expect(budi.byStatus[VisitStatus.belum], 3);
    });
  });

  group('DashboardScreen — Visibilitas Kartu Rekap Tim berdasarkan Role', () {
    testWidgets('Kartu Rekap Tim tersembunyi untuk role member', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userInfoProvider.overrideWith(() => _FakeUserInfoNotifier()),
            canViewAllProvider.overrideWithValue(TeamRole.member.canViewAll),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aktivitas Harian'), findsOneWidget);
      expect(find.text('Rekap Tim'), findsNothing);
    });

    for (final role in [TeamRole.spv, TeamRole.tsc, TeamRole.superadmin]) {
      testWidgets('Kartu Rekap Tim tampil untuk role ${role.name}', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userInfoProvider.overrideWith(() => _FakeUserInfoNotifier()),
              canViewAllProvider.overrideWithValue(role.canViewAll),
            ],
            child: const MaterialApp(
              home: DashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Aktivitas Harian'), findsOneWidget);
        expect(find.text('Rekap Tim'), findsOneWidget);
      });
    }
  });

  group('VisitTeamSummaryScreen — Read-Only & Error Handling', () {
    testWidgets('Menampilkan daftar rekap tim dan halaman detail read-only tanpa tombol ubah/hapus',
        (tester) async {
      final gateway = _FakeVisitSummaryGateway(
        rpcRows: [
          {
            'member_id': 'sales-1',
            'member_name': 'Andi Sales',
            'member_email': 'andi@example.test',
            'category': 'rvai',
            'status': 'sudah_visit',
            'total': 4,
          },
        ],
        memberVisitRows: [
          {
            'client_id': 'cid-read-1',
            'user_id': 'sales-1',
            'customer_id': '32009999',
            'customer_name': 'Pelanggan Fiktif ReadOnly',
            'category': 'rvai',
            'package_name': 'XL SATU Value',
            'address': 'Jl. Fiktif No. 1',
            'planned_date': '2026-11-06',
            'status': 'sudah_visit',
            'note': 'Lancar',
            'form_submitted': true,
            'created_at': '2026-11-06T08:00:00Z',
            'updated_at': '2026-11-06T09:00:00Z',
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitTeamSummaryServiceProvider.overrideWithValue(
              VisitTeamSummaryService(remoteGateway: gateway),
            ),
          ],
          child: const MaterialApp(
            home: VisitTeamSummaryScreen(isOnlineOverride: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Andi Sales'), findsOneWidget);
      expect(find.text('4 Visit'), findsOneWidget);
      expect(find.text('RVAI: 4'), findsOneWidget);

      // Tap kartu sales untuk membuka detail read-only
      await tester.tap(find.text('Andi Sales'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Aktivitas Sales (Read-Only)'), findsOneWidget);
      expect(find.textContaining('32009999'), findsOneWidget);
      // Pastikan tidak ada tombol hapus/ubah
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('Menampilkan pesan ramah saat error unauthorized atau offline', (tester) async {
      final unauthGateway = _FakeVisitSummaryGateway(shouldThrowUnauthorized: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitTeamSummaryServiceProvider.overrideWithValue(
              VisitTeamSummaryService(remoteGateway: unauthGateway),
            ),
          ],
          child: const MaterialApp(
            home: VisitTeamSummaryScreen(isOnlineOverride: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Akses Rekap Tim Tidak Diizinkan'), findsOneWidget);
    });
  });

  group('Phase 10E — SuperAdmin Master Status & Team Summary RVAI Compliance', () {
    testWidgets(
      'Kartu Data Master Pelanggan tampil di SuperAdmin Panel beserta peringatan kuning bila impor > 35 hari',
      (tester) async {
        final staleDate = DateTime.now().subtract(const Duration(days: 40));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              teamMembersProvider.overrideWith(
                () => _FakeTeamMembersNotifier(),
              ),
              masterStatusSummaryProvider.overrideWith(
                (ref) async => MasterStatusSummary(
                  total: 1250,
                  lastImport: staleDate,
                  lastBatch: '2026-09-25',
                  withSales: 1200,
                ),
              ),
            ],
            child: const MaterialApp(home: SuperAdminPanelScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_status_card')), findsOneWidget);
        expect(find.text('Data Master Pelanggan'), findsOneWidget);
        expect(find.text('1250'), findsOneWidget);
        expect(find.text('50'), findsOneWidget); // withoutSales = 1250 - 1200
        expect(find.text('Batch: 2026-09-25'), findsOneWidget);
        expect(find.byKey(const Key('master_stale_warning')), findsOneWidget);
      },
    );

    testWidgets(
      'VisitTeamSummaryScreen menampilkan Ringkasan Kepatuhan RVAI per Sales secara read-only',
      (tester) async {
        final visitGateway = _FakeVisitSummaryGateway(
          rpcRows: [
            {
              'member_id': 'sales-1',
              'member_name': 'Budi Sales',
              'member_email': 'budi@example.test',
              'category': 'rvai',
              'status': 'sudah_visit',
              'total': 3,
            },
          ],
        );
        final masterGateway = _FakeMasterComplianceGateway(
          complianceRows: [
            {
              'sales_name': 'BUDI SANTOSO',
              'spv_name': 'SPV HERI',
              'tsc_name': 'TSC PIPIN',
              'due_total': 10,
              'visited_total': 7,
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              visitTeamSummaryServiceProvider.overrideWithValue(
                VisitTeamSummaryService(remoteGateway: visitGateway),
              ),
              customerMasterServiceProvider.overrideWithValue(
                CustomerMasterService(
                  remoteGateway: masterGateway,
                  isConfiguredOverride: true,
                ),
              ),
            ],
            child: const MaterialApp(
              home: VisitTeamSummaryScreen(isOnlineOverride: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('rvai_compliance_card')), findsOneWidget);
        expect(find.text('Ringkasan Kepatuhan RVAI per Sales'), findsOneWidget);
        expect(find.text('BUDI SANTOSO'), findsOneWidget);
        expect(find.text('Sudah: 7 / 10'), findsOneWidget);
      },
    );
  });

  group('Phase 9E — SuperAdmin Form Email & Unmatched Form Responses', () {
    test('TeamMemberItem dan AccessCache kompatibel mundur terhadap JSON lama tanpa form_email', () {
      final legacyMember = TeamMemberItem.fromJson({
        'user_id': 'u-legacy',
        'email': 'legacy@example.test',
        'name': 'Sales Lama',
        'status': 'approved',
        'role': 'member',
      });
      expect(legacyMember.formEmail, isNull);

      final withFormEmail = TeamMemberItem.fromJson({
        'user_id': 'u-alias',
        'email': 'utama@example.test',
        'name': 'Sales Alias',
        'status': 'approved',
        'role': 'member',
        'form_email': 'alias.form@gmail.com',
      });
      expect(withFormEmail.formEmail, 'alias.form@gmail.com');

      final legacyCache = AccessCache.fromJson({
        'status': 'approved',
        'checked_at': '2026-11-09T01:00:00Z',
        'valid_until': '2026-11-16T01:00:00Z',
        'role': 'member',
      });
      expect(legacyCache.formEmail, isNull);
    });

    testWidgets(
      'Kartu Jawaban Form Tanpa Pasangan dan tombol Atur Email Form tampil serta menangani status RPC',
      (tester) async {
        final fakeNotifier = _FakeTeamMembersNotifier(
          initialMembers: [
            const TeamMemberItem(
              userId: 'member-1',
              email: 'budi.app@example.test',
              name: 'Budi Sales',
              status: MemberStatus.approved,
              role: TeamRole.member,
              salesName: 'BUDI SANTOSO',
              formEmail: 'budi.form@gmail.com',
            ),
          ],
          nextFormEmailResponse: 'already_used',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canEditRolesProvider.overrideWithValue(true),
              teamMembersProvider.overrideWith(() => fakeNotifier),
              masterStatusSummaryProvider.overrideWith((ref) async => null),
              unmatchedFormResponsesProvider.overrideWith(
                (ref) async => const [
                  UnmatchedFormResponseItem(
                    id: 'unmatched-1',
                    responderEmail: 'akun.asing@gmail.com',
                    customerId: '32017788',
                    category: 'rvai',
                    visitDate: '2026-11-09',
                    reason: 'email_tidak_cocok',
                  ),
                ],
              ),
            ],
            child: const MaterialApp(home: SuperAdminPanelScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Kartu Jawaban Form Tanpa Pasangan tampil
        expect(find.byKey(const Key('unmatched_form_responses_card')), findsOneWidget);
        expect(find.text('Jawaban Form Tanpa Pasangan (1)'), findsOneWidget);
        expect(find.text('Jika email berbeda, atur Email Form anggota terkait.'), findsOneWidget);
        expect(find.text('Email Form: akun.asing@gmail.com'), findsOneWidget);
        expect(find.text('Alasan: Email tidak cocok dengan akun sales'), findsOneWidget);

        // 2. Kartu anggota menampilkan form_email yang sudah ada dan tombol Atur Email Form
        expect(find.text('Email Form: budi.form@gmail.com'), findsOneWidget);
        final setEmailBtn = find.byKey(const Key('btn_set_form_email_member-1'));
        expect(setEmailBtn, findsOneWidget);

        // 3. Klik Atur Email Form -> buka dialog -> uji penanganan status already_used
        await tester.ensureVisible(setEmailBtn);
        await tester.pumpAndSettle();
        await tester.tap(setEmailBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('dialog_form_email_input')),
          'duplikat@gmail.com',
        );
        await tester.tap(find.byKey(const Key('dialog_form_email_save_btn')));
        await tester.pumpAndSettle();

        expect(
          find.text('Email tersebut sudah dipakai oleh akun anggota lain.'),
          findsOneWidget,
        );
      },
    );
  });
}

class _FakeTeamMembersNotifier extends TeamMembersNotifier {
  final List<TeamMemberItem> initialMembers;
  String nextFormEmailResponse;

  _FakeTeamMembersNotifier({
    this.initialMembers = const <TeamMemberItem>[],
    this.nextFormEmailResponse = 'success',
  });

  @override
  Future<List<TeamMemberItem>> build() async {
    return initialMembers;
  }

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(initialMembers);
  }

  @override
  Future<String> setFormEmail(String targetUserId, String formEmail) async {
    return nextFormEmailResponse;
  }
}

class _FakeMasterComplianceGateway implements CustomerMasterRemoteGateway {
  final List<Map<String, dynamic>> complianceRows;

  _FakeMasterComplianceGateway({this.complianceRows = const []});

  @override
  String? get currentUserId => 'spv-1';

  @override
  Future<String> claimSalesNameRpc(String salesName) async => 'success';

  @override
  Future<List<Map<String, dynamic>>> fetchCustomerMasterPage({
    required int fromIndex,
    required int toIndex,
  }) async => const [];

  @override
  Future<Map<String, dynamic>?> fetchMasterStatusRpc() async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchRvaiComplianceRpc({
    required String fromDate,
    required String toDate,
  }) async => complianceRows;

  @override
  Future<List<Map<String, dynamic>>> fetchSalesNamesRpc() async => const [];
}
