import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/auth/providers/auth_providers.dart';
import 'package:dsa_incentive_tracker/auth/widgets/access_gate.dart';
import 'package:dsa_incentive_tracker/auth/screens/login_screen.dart';
import 'package:dsa_incentive_tracker/auth/screens/access_code_screen.dart';
import 'package:dsa_incentive_tracker/auth/screens/access_revoked_screen.dart';
import 'package:dsa_incentive_tracker/auth/screens/offline_verification_required_screen.dart';

class MockAccessGateNotifier extends AccessGateNotifier {
  MockAccessGateNotifier(super.service, [GateState initialState = GateState.loading]) {
    state = initialState;
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
}
