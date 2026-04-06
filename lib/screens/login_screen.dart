import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _isStudentEmail(String value) {
    final email = value.trim().toLowerCase();
    if (!email.contains('@')) return false;
    return email.endsWith('.edu') || email.endsWith('.edu.tr');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _authErrorMessage(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'Bu e-posta ile kayıtlı bir hesap bulunamadı.';
        case 'wrong-password':
          return 'Şifre yanlış. Lütfen tekrar deneyin.';
        case 'invalid-credential':
          return 'E-posta veya şifre hatalı. Lütfen bilgilerinizi kontrol edin.';
        case 'invalid-email':
          return 'Geçersiz e-posta formatı.';
        case 'user-disabled':
          return 'Bu hesap devre dışı bırakılmış. Destek ekibiyle iletişime geçin.';
        case 'too-many-requests':
          return 'Çok fazla başarısız deneme. Lütfen birkaç dakika bekleyin.';
        case 'network-request-failed':
          return 'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.';
        case 'email-already-in-use':
          return 'Bu e-posta zaten kullanılıyor. Giriş yapmayı deneyin.';
        case 'weak-password':
          return 'Şifre çok zayıf. En az 6 karakter ve harf+rakam kombinasyonu kullanın.';
        case 'operation-not-allowed':
          return 'Bu giriş yöntemi şu an devre dışı.';
        case 'requires-recent-login':
          return 'Bu işlem için yeniden giriş yapmanız gerekiyor.';
        case 'account-exists-with-different-credential':
          return 'Bu e-posta başka bir giriş yöntemiyle kayıtlı.';
        default:
          return 'Giriş başarısız. Lütfen tekrar deneyin. (${e.code})';
      }
    }
    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      _showError(_authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showError('Lütfen önce e-posta adresinizi girin.');
      return;
    }
    if (!_isStudentEmail(email)) {
      _showError('Sadece .edu veya .edu.tr uzantılı öğrenci maili kabul edilir.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSuccess('Şifre sıfırlama bağlantısı $email adresine gönderildi. Spam kutusunu kontrol edin.');
    } catch (e) {
      _showError(_authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF0B132B),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -40,
                child: _GlowOrb(
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    size: 240),
              ),
              Positioned(
                bottom: -60,
                left: -50,
                child: _GlowOrb(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.30),
                    size: 220),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x42000000),
                            blurRadius: 32,
                            offset: Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0EA5E9),
                                    Color(0xFF8B5CF6)
                                  ],
                                ),
                              ),
                              child: const Icon(LucideIcons.graduationCap,
                                  color: Colors.white, size: 34),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'CampusGig Pro',
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Öğrenci e-postanızla giriş yapın ve kampüs fırsatlarını yakalayın.',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _buildField(
                              label: 'Öğrenci E-posta',
                              hint: 'ogrno@universite.edu.tr',
                              controller: _email,
                              icon: LucideIcons.mail,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'E-posta zorunludur';
                                }
                                if (!_isStudentEmail(text)) {
                                  return 'Sadece öğrenci e-posta adresi kabul edilir (.edu/.edu.tr)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            _buildField(
                              label: 'Şifre',
                              hint: 'En az 6 karakter',
                              controller: _password,
                              icon: LucideIcons.lock,
                              obscureText: _obscurePassword,
                              validator: (value) {
                                final text = value ?? '';
                                if (text.isEmpty) {
                                  return 'Şifre zorunludur';
                                }
                                if (text.length < 6) {
                                  return 'Şifre en az 6 karakter olmalı';
                                }
                                return null;
                              },
                              suffix: IconButton(
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword
                                      ? LucideIcons.eye
                                      : LucideIcons.eyeOff,
                                  size: 18,
                                  color: Colors.blueGrey.shade500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: _isLoading ? null : _forgotPassword,
                                child: const Text(
                                  'Şifremi Unuttum',
                                  style: TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white),
                                      )
                                    : const Text(
                                        'GİRİŞ YAP',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Hesabın yok mu? ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                GestureDetector(
                                  onTap: () => context.push('/register'),
                                  child: const Text(
                                    'Kayıt ol',
                                    style: TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.3,
            color: Colors.blueGrey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey.shade400),
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.blueGrey.shade300),
            filled: true,
            fillColor: const Color(0xFFF7FAFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF4F46E5), width: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
