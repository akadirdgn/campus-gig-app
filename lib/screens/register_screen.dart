import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static final RegExp _nameRegExp = RegExp(r"^[a-zA-ZçÇğĞıİöÖşŞüÜ\s'-]+$");
  static final RegExp _departmentRegExp =
      RegExp(r"^[a-zA-Z0-9çÇğĞıİöÖşŞüÜ\s&().,'/-]+$");

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _department = TextEditingController();
  final _studentNumber = TextEditingController();
  final _verificationCode = TextEditingController();

  static const List<String> _universities = [
    'Turgut Özal Üniversitesi',
    'İnönü Üniversitesi',
  ];

  static const List<String> _grades = [
    'Hazırlık',
    '1. Sınıf',
    '2. Sınıf',
    '3. Sınıf',
    '4. Sınıf',
    '5. Sınıf',
    '6. Sınıf',
  ];

  String? _selectedUniversity;
  String? _selectedGrade;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isAwaitingVerification = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _department.dispose();
    _studentNumber.dispose();
    _verificationCode.dispose();
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
        duration: const Duration(seconds: 5),
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
        case 'email-already-in-use':
          return 'Bu e-posta ile zaten bir hesap mevcut. Giriş yapmayı deneyin.';
        case 'invalid-email':
          return 'Geçersiz e-posta formatı.';
        case 'weak-password':
          return 'Şifre çok zayıf. En az 6 karakter, harf ve rakam içermeli.';
        case 'operation-not-allowed':
          return 'Kayıt şu an geçici olarak devre dışı.';
        case 'network-request-failed':
          return 'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.';
        case 'too-many-requests':
          return 'Çok fazla deneme yapıldı. Lütfen birkaç dakika bekleyin.';
        default:
          return 'Kayıt başarısız: ${e.message ?? e.code}';
      }
    }
    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  Future<bool> _preCheckDuplicate() async {
    final email = _email.text.trim();
    final studentNo = _studentNumber.text.trim();

    try {
      // Check for existing email
      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('studentEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        _showError('Bu e-posta adresi ile zaten bir hesap mevcut. Giriş yapmayı deneyin.');
        return false;
      }

      // Check for existing student number
      final studentNoQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('studentNumber', isEqualTo: studentNo)
          .limit(1)
          .get();

      if (studentNoQuery.docs.isNotEmpty) {
        _showError('Bu öğrenci numarası ile zaten bir hesap mevcut.');
        return false;
      }

      return true;
    } catch (e) {
      _showError('Kontrol sırasında hata oluştu. İnternet bağlantınızı kontrol edin.');
      return false;
    }
  }

  Future<void> _startVerificationStep() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final isSafe = await _preCheckDuplicate();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!isSafe) return;

    setState(() {
      _verificationCode.clear();
      _isAwaitingVerification = true;
    });
  }

  Future<void> _verifyAndRegister() async {
    final code = _verificationCode.text.trim();
    if (code.isEmpty) {
      _showError('Doğrulama kodunu girmeniz zorunludur.');
      return;
    }
    if (code.length != 4) {
      _showError('Doğrulama kodu 4 haneli olmalıdır.');
      return;
    }
    if (code != '1234') {
      _showError('Doğrulama kodu yanlış. E-postanızı kontrol edin.');
      return;
    }

    await _register();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      
      await credential.user!.updateDisplayName(fullName);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'id': credential.user!.uid,
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'displayName': fullName, // Firestore'da da kolaylık olsun
        'studentEmail': _email.text.trim(),
        'studentNumber': _studentNumber.text.trim(),
        'university': _selectedUniversity,
        'department': _department.text.trim(),
        'grade': _selectedGrade,
        'profile_locked': true,
        'wallet_cgt': 50, // Hoşgeldin bonusu
        'wallet_time_credit': 0,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSuccess('Hesabınız oluşturuldu! Hoş geldiniz 🎉');
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      context.go('/');
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
                child: _BackgroundBlob(
                  size: 240,
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -50,
                child: _BackgroundBlob(
                  size: 220,
                  color: AppTheme.secondaryColor.withValues(alpha: 0.30),
                ),
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
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x42000000),
                            blurRadius: 32,
                            offset: Offset(0, 20),
                          )
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0EA5E9),
                                        Color(0xFF8B5CF6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(LucideIcons.userPlus,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'CampusGig Pro Kayıt',
                                    style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Öğrenci profilini tamamla, doğrulama ile güvenli şekilde katıl.',
                              style: TextStyle(
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildField(
                                    label: 'Ad',
                                    hint: 'Ali',
                                    controller: _firstName,
                                    icon: LucideIcons.user,
                                    validator: (value) => (value == null ||
                                            value.trim().isEmpty)
                                        ? 'Zorunlu alan'
                                        : (!_nameRegExp.hasMatch(value.trim())
                                            ? 'Ad alanında Türkçe karakterler kullanılabilir, sayı kullanılamaz'
                                            : null),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildField(
                                    label: 'Soyad',
                                    hint: 'Kaya',
                                    controller: _lastName,
                                    icon: LucideIcons.user,
                                    validator: (value) => (value == null ||
                                            value.trim().isEmpty)
                                        ? 'Zorunlu alan'
                                        : (!_nameRegExp.hasMatch(value.trim())
                                            ? 'Soyad alanında Türkçe karakterler kullanılabilir, sayı kullanılamaz'
                                            : null),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
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
                                  return 'Sadece .edu veya .edu.tr uzantılı öğrenci maili';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              label: 'Öğrenci Numarası',
                              hint: '2023101050',
                              controller: _studentNumber,
                              icon: LucideIcons.hash,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Öğrenci numarası zorunludur';
                                }
                                if (text.length < 8) {
                                  return 'Geçersiz öğrenci numarası';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              label: 'Okul',
                              icon: LucideIcons.school,
                              value: _selectedUniversity,
                              hint: 'Üniversite seçin',
                              items: _universities,
                              onChanged: (value) {
                                setState(() => _selectedUniversity = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Okul seçimi zorunludur';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              label: 'Bölüm',
                              hint: 'Bilgisayar Mühendisliği',
                              controller: _department,
                              icon: LucideIcons.bookOpen,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Bölüm bilgisi zorunludur';
                                }
                                if (!_departmentRegExp.hasMatch(text)) {
                                  return 'Bölüm alanında geçersiz karakter var';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              label: 'Sınıf',
                              icon: LucideIcons.layers,
                              value: _selectedGrade,
                              hint: 'Sınıf seçin',
                              items: _grades,
                              onChanged: (value) {
                                setState(() => _selectedGrade = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Sınıf seçimi zorunludur';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : (_isAwaitingVerification
                                        ? _verifyAndRegister
                                        : _startVerificationStep),
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
                                            strokeWidth: 2.2,
                                            color: Colors.white),
                                      )
                                    : const Text(
                                        'KAYIT OL',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Zaten hesabın var mı? ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                GestureDetector(
                                  onTap: () => context.go('/login'),
                                  child: const Text(
                                    'Giriş yap',
                                    style: TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w900),
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
              if (_isAwaitingVerification) _buildVerificationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0F172A).withValues(alpha: 0.62),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(28),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.8)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 36,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0EA5E9),
                                Color(0xFF8B5CF6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            LucideIcons.mailCheck,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Mail Doğrulama',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Girdiğiniz öğrenci mailine doğrulama kodu gönderildi. Lütfen kodu girin ve spam kutusunu kontrol edin.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _verificationCode,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 14,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '- - - -',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7FAFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isAwaitingVerification = false;
                                      _verificationCode.clear();
                                    });
                                  },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Vazgeç',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyAndRegister,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Doğrula',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w900),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Test için kod: 1234',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey.shade400),
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.blueGrey.shade300),
            filled: true,
            fillColor: const Color(0xFFF7FAFF),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
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

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
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
        DropdownButtonFormField<String>(
          value: value,
          validator: validator,
          onChanged: onChanged,
          icon: const Icon(LucideIcons.chevronDown, size: 18),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey.shade400),
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
          hint: Text(
            hint,
            style: TextStyle(color: Colors.blueGrey.shade300),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _BackgroundBlob extends StatelessWidget {
  const _BackgroundBlob({required this.size, required this.color});

  final double size;
  final Color color;

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
