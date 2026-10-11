import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/member_status.dart';
import '../models/team_member_item.dart';
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
  TeamRole _currentRole = TeamRole.member;

  AccessGateNotifier(this._accessService) : super(GateState.loading);

  TeamRole get currentRole => _currentRole;
  bool get isSuperadmin => _currentRole.isSuperadmin;

  /// Dipanggil saat ada perubahan sesi auth (login, logout, token refresh)
  Future<void> onAuthStateChanged(AuthState? authState) async {
    if (authState == null || authState.session == null) {
      _currentRole = TeamRole.member;
      state = GateState.noSession;
      return;
    }

    final isAlreadyApproved = state == GateState.approved;
    final isTokenRefresh = authState.event == AuthChangeEvent.tokenRefreshed;
    final userId = authState.session!.user.id;
    await _checkAccess(userId, silent: isAlreadyApproved || isTokenRefresh);
  }

  /// Periksa status akses dari Supabase (atau fallback ke cache)
  Future<void> checkAccess(String userId, {bool silent = false}) async {
    await _checkAccess(userId, silent: silent);
  }

  Future<void> _checkAccess(String userId, {bool silent = false}) async {
    if (!silent) {
      state = GateState.checkingAccess;
    }

    final cache = await _accessService.resolveAccess(userId);
    _currentRole = cache.role;

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
  void setState(GateState s) {
    if (s == GateState.noSession) {
      _currentRole = TeamRole.member;
    }
    state = s;
  }
}

// ---------------------------------------------------------------------------
// Provider untuk AccessGateNotifier
// ---------------------------------------------------------------------------
final accessGateProvider =
    StateNotifierProvider<AccessGateNotifier, GateState>((ref) {
  final service = ref.watch(teamAccessServiceProvider);
  return AccessGateNotifier(service);
});

// ---------------------------------------------------------------------------
// Provider untuk mengecek apakah user aktif adalah Superadmin
// ---------------------------------------------------------------------------
final isSuperadminProvider = Provider<bool>((ref) {
  final gateState = ref.watch(accessGateProvider);
  if (gateState != GateState.approved) return false;
  return ref.watch(accessGateProvider.notifier).isSuperadmin;
});

// ---------------------------------------------------------------------------
// Notifier & Provider untuk daftar anggota tim di panel Superadmin
// ---------------------------------------------------------------------------
class TeamMembersNotifier extends AsyncNotifier<List<TeamMemberItem>> {
  @override
  Future<List<TeamMemberItem>> build() async {
    final service = ref.watch(teamAccessServiceProvider);
    return await service.fetchAllTeamMembers();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(teamAccessServiceProvider);
      return await service.fetchAllTeamMembers();
    });
  }

  Future<String> updateStatus(String targetUserId, MemberStatus newStatus) async {
    final service = ref.read(teamAccessServiceProvider);
    final result = await service.updateMemberStatus(
      targetUserId: targetUserId,
      newStatus: newStatus,
    );
    if (result == 'success' || result == 'approved') {
      await refresh();
    }
    return result;
  }
}

final teamMembersProvider =
    AsyncNotifierProvider<TeamMembersNotifier, List<TeamMemberItem>>(
  () => TeamMembersNotifier(),
);
