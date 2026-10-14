import 'dart:async';
import 'package:flutter/foundation.dart';
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
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    _initAuthListener();
    _startWatchdog();
  }

  void _startWatchdog() {
    _watchdogTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      final current = ref.read(accessGateProvider);
      if (current == GateState.loading || current == GateState.checkingAccess) {
        final session = AppSupabase.isInitialized ? AppSupabase.client.auth.currentSession : null;
        if (session != null) {
          ref.read(accessGateProvider.notifier).setState(GateState.needsOnlineVerification);
        } else {
          ref.read(accessGateProvider.notifier).setState(GateState.noSession);
        }
      }
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    super.dispose();
  }

  void _initAuthListener() {
    if (!AppSupabase.isInitialized) {
      // Supabase belum dikonfigurasi / offline saat startup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(accessGateProvider) == GateState.loading) {
          if (kDebugMode) {
            ref.read(accessGateProvider.notifier).setState(GateState.approved);
          } else {
            ref.read(accessGateProvider.notifier).setState(GateState.noSession);
          }
        }
      });
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
        return _LoadingGate(
          onForceLogin: () {
            ref.read(accessGateProvider.notifier).setState(GateState.noSession);
          },
        );

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
class _LoadingGate extends StatefulWidget {
  final VoidCallback? onForceLogin;
  const _LoadingGate({this.onForceLogin});

  @override
  State<_LoadingGate> createState() => _LoadingGateState();
}

class _LoadingGateState extends State<_LoadingGate> {
  bool _showTroubleshoot = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showTroubleshoot = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF002B66),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'Memverifikasi akses...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (_showTroubleshoot) ...[
                const SizedBox(height: 24),
                Text(
                  'Koneksi ke server lambat atau offline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.onForceLogin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text(
                    'Buka Halaman Login / Masuk',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
