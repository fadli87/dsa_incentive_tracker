import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../supabase_client.dart';

/// Layar peringatan masa tenggang offline habis — perlu koneksi internet
class OfflineVerificationRequiredScreen extends ConsumerStatefulWidget {
  const OfflineVerificationRequiredScreen({super.key});

  @override
  ConsumerState<OfflineVerificationRequiredScreen> createState() =>
      _OfflineVerificationRequiredScreenState();
}

class _OfflineVerificationRequiredScreenState
    extends ConsumerState<OfflineVerificationRequiredScreen> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    try {
      final session = AppSupabase.client.auth.currentSession;
      if (session != null) {
        await ref.read(accessGateProvider.notifier).checkAccess(session.user.id);
      } else {
        ref.read(accessGateProvider.notifier).setState(GateState.noSession);
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _signOut() async {
    if (mounted) {
      ref.read(accessGateProvider.notifier).setState(GateState.noSession);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 64),
              ),
              const SizedBox(height: 28),
              const Text(
                'Verifikasi Online Diperlukan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Masa akses offline Anda telah berakhir (melebihi 7 hari tanpa koneksi).\n\nHubungkan ke internet lalu tekan "Coba Lagi" untuk memperbarui status akses Anda.',
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isRetrying ? null : _retry,
                  icon: _isRetrying
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_isRetrying ? 'Menghubungkan...' : 'Coba Lagi',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0079C1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isRetrying ? null : _signOut,
                child: const Text('Keluar', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
