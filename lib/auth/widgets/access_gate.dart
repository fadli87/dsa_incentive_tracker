import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../screens/login_screen.dart';
import '../screens/access_code_screen.dart';
import '../screens/access_revoked_screen.dart';
import '../screens/offline_verification_required_screen.dart';
import '../../auth/supabase_client.dart';

/// Widget gerbang akses root — membungkus [child] (MainNavigation)
/// dan menerapkan state machine autentikasi Supabase + kode akses tim.
class AccessGate extends ConsumerStatefulWidget {
  final Widget child;

  const AccessGate({super.key, required this.child});

  @override
  ConsumerState<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends ConsumerState<AccessGate> {
  @override
  void initState() {
    super.initState();
    _initAuthListener();
  }

  void _initAuthListener() {
    if (!AppSupabase.isInitialized) {
      // Supabase belum dikonfigurasi (dev mode), ubah ke approved jika masih default loading
      if (ref.read(accessGateProvider) == GateState.loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(accessGateProvider) == GateState.loading) {
            ref.read(accessGateProvider.notifier).setState(GateState.approved);
          }
        });
      }
      return;
    }

    // Dengarkan perubahan sesi auth dan update gate state
    AppSupabase.client.auth.onAuthStateChange.listen((authState) {
      if (mounted) {
        ref
            .read(accessGateProvider.notifier)
            .onAuthStateChanged(authState);
      }
    });

    // Cek sesi yang ada saat ini (jika sudah login sebelumnya)
    final currentSession = AppSupabase.client.auth.currentSession;
    if (currentSession != null) {
      ref
          .read(accessGateProvider.notifier)
          .checkAccess(currentSession.user.id);
    } else {
      ref.read(accessGateProvider.notifier).setState(GateState.noSession);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateState = ref.watch(accessGateProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _buildForState(gateState),
    );
  }

  Widget _buildForState(GateState state) {
    switch (state) {
      case GateState.loading:
      case GateState.checkingAccess:
        return const _LoadingGate();

      case GateState.noSession:
        return const LoginScreen();

      case GateState.approved:
        return widget.child;

      case GateState.needsAccessCode:
        return const AccessCodeScreen();

      case GateState.revoked:
        return const AccessRevokedScreen();

      case GateState.needsOnlineVerification:
        return const OfflineVerificationRequiredScreen();
    }
  }
}

/// Layar loading saat gate sedang memeriksa status akses
class _LoadingGate extends StatelessWidget {
  const _LoadingGate();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF002B66),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'Memverifikasi akses...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
