import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/auth/models/member_status.dart';
import 'package:dsa_incentive_tracker/auth/models/team_member_item.dart';
import 'package:dsa_incentive_tracker/auth/providers/auth_providers.dart';
import 'package:dsa_incentive_tracker/auth/services/team_access_service.dart';
import 'package:dsa_incentive_tracker/auth/widgets/access_gate.dart';
import 'package:dsa_incentive_tracker/auth/screens/login_screen.dart';
import 'package:dsa_incentive_tracker/auth/screens/access_code_screen.dart';
import 'package:dsa_incentive_tracker/auth/screens/access_revoked_screen.dart';
import 'package:dsa_incentive_tracker/auth/screens/offline_verification_required_screen.dart';
import 'package:dsa_incentive_tracker/auth/screens/super_admin_panel_screen.dart';

class MockAccessGateNotifier extends AccessGateNotifier {
  final TeamRole mockRole;
  MockAccessGateNotifier(
    super.service, [
    GateState initialState = GateState.loading,
    this.mockRole = TeamRole.member,
  ]) {
    state = initialState;
  }

  @override
  TeamRole get currentRole => mockRole;

  @override
  bool get isSuperadmin => mockRole.isSuperadmin;

  @override
  bool get canViewAll => mockRole.canViewAll;

  @override
  bool get canEditRoles => mockRole.canEditRoles;
}

class FakeTeamAccessService extends TeamAccessService {
  List<TeamMemberItem> members;
  String nextRoleUpdateResult;

  FakeTeamAccessService({
    List<TeamMemberItem>? initialMembers,
    this.nextRoleUpdateResult = 'success',
  }) : members = initialMembers ??
            [
              const TeamMemberItem(
                userId: 'user-sales-1',
                email: 'budi@xl.co.id',
                name: 'Budi Sales',
                status: MemberStatus.approved,
                role: TeamRole.member,
              ),
              const TeamMemberItem(
                userId: 'user-spv-1',
                email: 'andi@xl.co.id',
                name: 'Andi SPV',
                status: MemberStatus.approved,
                role: TeamRole.spv,
              ),
            ];

  @override
  Future<List<TeamMemberItem>> fetchAllTeamMembers() async {
    return List<TeamMemberItem>.from(members);
  }

  @override
  Future<String> updateMemberRole({
    required String targetUserId,
    required TeamRole newRole,
  }) async {
    if (nextRoleUpdateResult == 'success') {
      members = members.map((m) {
        if (m.userId == targetUserId) {
          return TeamMemberItem(
            userId: m.userId,
            email: m.email,
            name: m.name,
            status: m.status,
            role: newRole,
            createdAt: m.createdAt,
            approvedAt: m.approvedAt,
          );
        }
        return m;
      }).toList();
    }
    return nextRoleUpdateResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget({required GateState state, required Widget child}) {
    return ProviderScope(
      overrides: [
        accessGateProvider.overrideWith((ref) {
          final service = ref.watch(teamAccessServiceProvider);
          return MockAccessGateNotifier(service, state);
        }),
      ],
      child: MaterialApp(
        home: AccessGate(child: child),
      ),
    );
  }

  group('AccessGate Widget Tests', () {
    const dummyChild = Text('DASHBOARD_CHILD_READY');

    testWidgets('Renders child widget saat state approved', (tester) async {
      await tester.pumpWidget(createTestWidget(
        state: GateState.approved,
        child: dummyChild,
      ));
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD_CHILD_READY'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Renders LoginScreen saat state noSession', (tester) async {
      await tester.pumpWidget(createTestWidget(
        state: GateState.noSession,
        child: dummyChild,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('DASHBOARD_CHILD_READY'), findsNothing);
      expect(find.text('DSA XL Satu Handbook'), findsOneWidget);
    });

    testWidgets('Renders AccessCodeScreen saat state needsAccessCode', (tester) async {
      await tester.pumpWidget(createTestWidget(
        state: GateState.needsAccessCode,
        child: dummyChild,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AccessCodeScreen), findsOneWidget);
      expect(find.text('Masukkan Kode Akses Tim'), findsOneWidget);
      expect(find.text('DASHBOARD_CHILD_READY'), findsNothing);
    });

    testWidgets('Renders AccessRevokedScreen saat state revoked', (tester) async {
      await tester.pumpWidget(createTestWidget(
        state: GateState.revoked,
        child: dummyChild,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AccessRevokedScreen), findsOneWidget);
      expect(find.text('Akses Dicabut'), findsOneWidget);
      expect(find.text('DASHBOARD_CHILD_READY'), findsNothing);
    });

    testWidgets('Renders OfflineVerificationRequiredScreen saat state needsOnlineVerification', (tester) async {
      await tester.pumpWidget(createTestWidget(
        state: GateState.needsOnlineVerification,
        child: dummyChild,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineVerificationRequiredScreen), findsOneWidget);
      expect(find.text('Verifikasi Online Diperlukan'), findsOneWidget);
      expect(find.text('DASHBOARD_CHILD_READY'), findsNothing);
    });

    testWidgets('Renders loading progress saat state checkingAccess', (tester) async {
      await tester.pumpWidget(createTestWidget(
        state: GateState.checkingAccess,
        child: dummyChild,
      ));
      await tester.pump(); // don't settle because loading animation is infinite

      expect(find.text('Memverifikasi akses...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('DASHBOARD_CHILD_READY'), findsNothing);
    });
  });

  group('Role Providers & SuperAdminPanelScreen Role Management Tests', () {
    test('canViewAllProvider, isSuperadminProvider, and canEditRolesProvider reflect role accurately', () {
      for (final role in TeamRole.values) {
        final container = ProviderContainer(
          overrides: [
            accessGateProvider.overrideWith((ref) {
              final service = ref.watch(teamAccessServiceProvider);
              return MockAccessGateNotifier(service, GateState.approved, role);
            }),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(isSuperadminProvider),
          role == TeamRole.admin || role == TeamRole.superadmin,
          reason: 'isSuperadminProvider failed for $role',
        );
        expect(
          container.read(canViewAllProvider),
          role != TeamRole.member,
          reason: 'canViewAllProvider failed for $role',
        );
        expect(
          container.read(canEditRolesProvider),
          role == TeamRole.superadmin,
          reason: 'canEditRolesProvider failed for $role',
        );
      }
    });

    testWidgets('SuperAdminPanelScreen menampilkan badge role dan dapat mengubah role anggota (superadmin)', (tester) async {
      final fakeService = FakeTeamAccessService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teamAccessServiceProvider.overrideWithValue(fakeService),
            accessGateProvider.overrideWith((ref) {
              return MockAccessGateNotifier(
                fakeService,
                GateState.approved,
                TeamRole.superadmin,
              );
            }),
          ],
          child: const MaterialApp(
            home: SuperAdminPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge role tampil untuk SALES dan SPV
      expect(find.text('Budi Sales'), findsOneWidget);
      expect(find.text('SALES'), findsOneWidget);
      expect(find.text('Andi SPV'), findsOneWidget);
      expect(find.text('SPV'), findsOneWidget);

      // Tombol Ubah Role tampil karena canEditRoles == true
      expect(find.text('Ubah Role'), findsNWidgets(2));

      // Klik Ubah Role pada Budi Sales -> ubah menjadi TSC
      await tester.tap(find.text('Ubah Role').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('TSC').last);
      await tester.pumpAndSettle();

      expect(find.text('TSC'), findsOneWidget);
      expect(
        find.text('Role Budi Sales berhasil diubah menjadi TSC!'),
        findsOneWidget,
      );
    });

    testWidgets('SuperAdminPanelScreen menyembunyikan tombol Ubah Role untuk role admin biasa', (tester) async {
      final fakeService = FakeTeamAccessService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teamAccessServiceProvider.overrideWithValue(fakeService),
            accessGateProvider.overrideWith((ref) {
              return MockAccessGateNotifier(
                fakeService,
                GateState.approved,
                TeamRole.admin,
              );
            }),
          ],
          child: const MaterialApp(
            home: SuperAdminPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budi Sales'), findsOneWidget);
      expect(find.text('Ubah Role'), findsNothing);
    });
  });
}
