import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../supabase_client.dart';

/// Layar Login/Daftar dengan tab toggle Masuk | Daftar
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;

  // Form controllers — Masuk
  final _signInEmailCtrl = TextEditingController();
  final _signInPasswordCtrl = TextEditingController();

  // Form controllers — Daftar
  final _signUpNameCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPasswordCtrl = TextEditingController();
  final _signUpAccessCodeCtrl = TextEditingController();

  bool _obscureSignInPassword = true;
  bool _obscureSignUpPassword = true;
  bool _obscureAccessCode = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailCtrl.dispose();
    _signInPasswordCtrl.dispose();
    _signUpNameCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _signUpAccessCodeCtrl.dispose();
    super.dispose();
  }

  void _setError(String? msg) => setState(() => _errorMessage = msg);
  void _setLoading(bool v) => setState(() => _isLoading = v);

  // ---------- Masuk ----------
  Future<void> _signIn() async {
    if (!AppSupabase.isInitialized) {
      _setError('Konfigurasi Supabase belum lengkap.');
      return;
    }
    final email = _signInEmailCtrl.text.trim();
    final password = _signInPasswordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _setError('Email dan password tidak boleh kosong.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final res = await AppSupabase.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.session != null) {
        await ref
            .read(accessGateProvider.notifier)
            .checkAccess(res.session!.user.id);
      }
    } on Exception catch (e) {
      _setError('Login gagal: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      _setLoading(false);
    }
  }

  // ---------- Daftar ----------
  Future<void> _signUp() async {
    if (!AppSupabase.isInitialized) {
      _setError('Konfigurasi Supabase belum lengkap.');
      return;
    }
    final name = _signUpNameCtrl.text.trim();
    final email = _signUpEmailCtrl.text.trim();
    final password = _signUpPasswordCtrl.text;
    final accessCode = _signUpAccessCodeCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || accessCode.isEmpty) {
      _setError('Semua kolom wajib diisi.');
      return;
    }
    if (password.length < 6) {
      _setError('Password minimal 6 karakter.');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      // 1. Daftar akun baru (trigger DB otomatis insert ke team_members dengan status pending)
      final res = await AppSupabase.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (res.user == null) {
        _setError('Pendaftaran gagal, coba lagi.');
        return;
      }

      // 2. Redeem kode akses tim
      final service = ref.read(teamAccessServiceProvider);
      final redeemResult = await service.redeemAccessCode(accessCode);

      switch (redeemResult) {
        case 'approved':
          await ref
              .read(accessGateProvider.notifier)
              .checkAccess(res.user!.id);
        case 'invalid_code':
          _setError('Kode akses salah. Hubungi admin tim untuk mendapatkan kode yang benar.');
        case 'already_revoked':
          _setError('Akun ini telah dicabut aksesnya. Hubungi admin tim.');
        case 'config_missing':
          _setError('Konfigurasi server belum siap. Hubungi admin tim.');
        default:
          _setError('Terjadi kesalahan. Coba lagi atau hubungi admin tim.');
      }
    } on Exception catch (e) {
      _setError('Pendaftaran gagal: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001A40),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Logo & Header
              Image.asset(
                'assets/images/splash_logo.png',
                height: 72,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.signal_cellular_alt,
                  size: 72,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'DSA XL Satu Handbook',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Masuk atau daftar untuk melanjutkan',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF002B66),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF0056B3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: 'Masuk'),
                    Tab(text: 'Daftar'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error banner
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withAlpha(180),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Form content
              SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSignInForm(),
                    _buildSignUpForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return Column(
      children: [
        _field(
          controller: _signInEmailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _signInPasswordCtrl,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscureSignInPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignInPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
          ),
        ),
        const SizedBox(height: 24),
        _submitButton(label: 'Masuk', onPressed: _signIn),
        const SizedBox(height: 12),
        const Text(
          'Lupa password? Hubungi admin tim untuk reset.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      children: [
        _field(
          controller: _signUpNameCtrl,
          label: 'Nama Lengkap',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 10),
        _field(
          controller: _signUpEmailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        _field(
          controller: _signUpPasswordCtrl,
          label: 'Password (min. 6 karakter)',
          icon: Icons.lock_outline,
          obscure: _obscureSignUpPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignUpPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
          ),
        ),
        const SizedBox(height: 10),
        _field(
          controller: _signUpAccessCodeCtrl,
          label: 'Kode Akses Tim',
          icon: Icons.key_outlined,
          obscure: _obscureAccessCode,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureAccessCode ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: () => setState(() => _obscureAccessCode = !_obscureAccessCode),
          ),
        ),
        const SizedBox(height: 20),
        _submitButton(label: 'Daftar & Masuk', onPressed: _signUp),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffixIcon,
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
      ),
    );
  }

  Widget _submitButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0079C1),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
