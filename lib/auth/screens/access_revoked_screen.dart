import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

/// Layar informasi bahwa akses user telah dicabut (status revoked)
class AccessRevokedScreen extends ConsumerWidget {
  const AccessRevokedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded, color: Colors.red, size: 64),
              ),
              const SizedBox(height: 28),
              const Text(
                'Akses Dicabut',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Akses akun Anda ke aplikasi ini telah dicabut oleh admin tim.\n\nJika ini adalah kesalahan, hubungi admin tim Anda untuk mengaktifkan kembali.',
                style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(accessGateProvider.notifier).setState(GateState.noSession);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
