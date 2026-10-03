import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../supabase_client.dart';

/// Layar input kode akses tim — dipakai saat status pending
/// (belum pernah redeem kode, atau retry setelah salah)
class AccessCodeScreen extends ConsumerStatefulWidget {
  const AccessCodeScreen({super.key});

  @override
  ConsumerState<AccessCodeScreen> createState() => _AccessCodeScreenState();
}

class _AccessCodeScreenState extends ConsumerState<AccessCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureCode = true;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Kode akses tidak boleh kosong.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(teamAccessServiceProvider);
      final result = await service.redeemAccessCode(code);

      if (!mounted) return;

      switch (result) {
        case 'approved':
          final userId = AppSupabase.client.auth.currentUser?.id;
          if (userId != null) {
            await ref.read(accessGateProvider.notifier).onAccessCodeRedeemed(userId);
          }
        case 'invalid_code':
          setState(() => _errorMessage =
              'Kode akses salah. Coba lagi atau hubungi admin tim.');
        case 'already_revoked':
          setState(() => _errorMessage =
              'Akun ini telah dicabut aksesnya oleh admin. Hubungi admin tim.');
        case 'config_missing':
          setState(() => _errorMessage = 'Konfigurasi server belum siap. Coba beberapa saat lagi.');
        default:
          setState(() => _errorMessage = 'Terjadi kesalahan. Periksa koneksi dan coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      backgroundColor: const Color(0xFF001A40),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.key_rounded, color: Color(0xFF0079C1), size: 64),
              const SizedBox(height: 20),
              const Text(
                'Masukkan Kode Akses Tim',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Akun Anda terdaftar namun belum aktif.\nMasukkan kode akses yang diberikan oleh admin tim Anda.',
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withAlpha(180),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              TextField(
                controller: _codeCtrl,
                obscureText: _obscureCode,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF002B66),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF0079C1), width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCode ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _obscureCode = !_obscureCode),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _redeem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0079C1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Aktifkan Akses', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : _signOut,
                child: const Text('Keluar dari akun ini', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
