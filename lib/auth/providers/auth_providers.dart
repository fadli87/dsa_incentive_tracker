import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/member_status.dart';
import '../services/team_access_service.dart';
import '../supabase_client.dart';

// ---------------------------------------------------------------------------
// Provider: TeamAccessService singleton
// ---------------------------------------------------------------------------
final teamAccessServiceProvider = Provider<TeamAccessService>((ref) {
  return TeamAccessService();
});

// ---------------------------------------------------------------------------
// Provider: Stream sesi auth Supabase (login/logout events)
// ---------------------------------------------------------------------------
final authStateProvider = StreamProvider<AuthState>((ref) {
  if (!AppSupabase.isInitialized) {
    return const Stream.empty();
  }
  return AppSupabase.client.auth.onAuthStateChange;
});

// ---------------------------------------------------------------------------
// Enum state machine gerbang akses (AccessGate states)
// ---------------------------------------------------------------------------
enum GateState {
  loading,
  noSession,
  checkingAccess,
  approved,
  needsAccessCode,
  revoked,
  needsOnlineVerification,
}

// ---------------------------------------------------------------------------
// StateNotifier yang mengelola state machine AccessGate
// ---------------------------------------------------------------------------
class AccessGateNotifier extends StateNotifier<GateState> {
  final TeamAccessService _accessService;

  AccessGateNotifier(this._accessService) : super(GateState.loading);

  /// Dipanggil saat ada perubahan sesi auth (login, logout, token refresh)
  Future<void> onAuthStateChanged(AuthState? authState) async {
    if (authState == null || authState.session == null) {
      state = GateState.noSession;
      return;
    }

    final userId = authState.session!.user.id;
    await _checkAccess(userId);
  }

  /// Periksa status akses dari Supabase (atau fallback ke cache)
  Future<void> checkAccess(String userId) async {
    await _checkAccess(userId);
  }

  Future<void> _checkAccess(String userId) async {
    state = GateState.checkingAccess;

    final cache = await _accessService.resolveAccess(userId);

    state = switch (cache.status) {
      MemberStatus.approved when !cache.isExpired => GateState.approved,
      MemberStatus.pending => GateState.needsAccessCode,
      MemberStatus.revoked => GateState.revoked,
      _ => GateState.needsOnlineVerification,
    };
  }

  /// Dipanggil setelah user berhasil redeem kode akses
  Future<void> onAccessCodeRedeemed(String userId) async {
    await _checkAccess(userId);
  }

  /// Reset ke loading state (untuk retry)
  void reset() => state = GateState.loading;

  /// Set state secara eksplisit dari luar (untuk logout, dsb)
  void setState(GateState s) => state = s;
}

// ---------------------------------------------------------------------------
// Provider untuk AccessGateNotifier
// ---------------------------------------------------------------------------
final accessGateProvider =
    StateNotifierProvider<AccessGateNotifier, GateState>((ref) {
  final service = ref.watch(teamAccessServiceProvider);
  return AccessGateNotifier(service);
});
