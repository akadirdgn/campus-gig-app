import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

class CreateGigScreen extends ConsumerStatefulWidget {
  const CreateGigScreen({super.key});

  @override
  ConsumerState<CreateGigScreen> createState() => _CreateGigScreenState();
}

class _CreateGigScreenState extends ConsumerState<CreateGigScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  String _type = 'services'; // services or bounties
  String _priceType = 'token'; // token or swap

  bool get _isMarketplace => _type == 'services';
  Color get _accent =>
      _isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
  Color get _accentSecondary =>
      _isMarketplace ? const Color(0xFF1E9D4B) : const Color(0xFF8B5CF6);
  Color get _bgStart =>
      _isMarketplace ? const Color(0xFF0A0F12) : const Color(0xFF070B1A);
  Color get _bgEnd =>
      _isMarketplace ? const Color(0xFF0F1714) : const Color(0xFF141231);

  @override
  void initState() {
    super.initState();
    if (AppTheme.homeTabNotifier.value == 'bounties') {
      _type = 'bounties';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _accent;

    return Scaffold(
      backgroundColor: _bgStart,
      appBar: AppBar(
        title: const Text('Yeni İlan',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Color(0xFFF3F4F6))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFE5E7EB)),
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_bgStart, _bgEnd],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -70,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentSecondary.withOpacity(0.2),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: const SizedBox(),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('İlan Türü',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey[300])),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _TypeButton(
                      label: 'HİZMET VER',
                      isActive: _type == 'services',
                      activeColor: const Color(0xFF7CFF6B),
                      activeSecondary: const Color(0xFF1E9D4B),
                      onTap: () => setState(() {
                        _type = 'services';
                        AppTheme.homeTabNotifier.value = 'marketplace';
                      }),
                    ),
                    const SizedBox(width: 12),
                    _TypeButton(
                      label: 'GÖREV AÇ',
                      isActive: _type == 'bounties',
                      activeColor: const Color(0xFF4CC9FF),
                      activeSecondary: const Color(0xFF8B5CF6),
                      onTap: () => setState(() {
                        _type = 'bounties';
                        AppTheme.homeTabNotifier.value = 'bounties';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _buildTextField('İlan Başlığı',
                    'Örn: Ödev Yardımı,Ders Anlatımı', _titleController),
                const SizedBox(height: 20),
                _buildTextField(
                    'Açıklama', 'Detayları buraya yazın...', _descController,
                    maxLines: 5),
                const SizedBox(height: 28),
                Text('Ödeme Türü',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey[300])),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _PriceTypeButton(
                      label: 'CGT Token',
                      isActive: _priceType == 'token',
                      activeColor: _accent,
                      onTap: () => setState(() => _priceType = 'token'),
                    ),
                    const SizedBox(width: 12),
                    _PriceTypeButton(
                      label: 'ZK (Zaman Takası)',
                      isActive: _priceType == 'swap',
                      activeColor: _accentSecondary,
                      onTap: () => setState(() => _priceType = 'swap'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_priceType == 'token')
                  _buildTextField('Fiyat (CGT)', '0.00', _priceController,
                      keyboardType: TextInputType.number),
                const SizedBox(height: 44),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: color.withOpacity(0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient:
                            LinearGradient(colors: [_accent, _accentSecondary]),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.42),
                              blurRadius: 14,
                              spreadRadius: 1),
                        ],
                      ),
                      child: const Center(
                        child: Text('YAYINLA',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 2)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, String hint, TextEditingController controller,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey[300])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFFE5E7EB)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.grey[500], fontWeight: FontWeight.normal),
            filled: true,
            fillColor: const Color(0x1FFFFFFF),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _accent.withOpacity(0.7)),
            ),
          ),
        ),
      ],
    );
  }

  void _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_titleController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tüm alanları doldurun')));
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final university = userData?['university']?.toString().toUpperCase() ??
          'KAMPÜS ÖĞRENCİSİ';

      await FirebaseFirestore.instance.collection(_type).add({
        'title': _titleController.text,
        'description': _descController.text,
        'price': _priceType == 'swap'
            ? 1
            : double.tryParse(_priceController.text) ?? 0,
        'price_type': _priceType,
        'type': _type,
        'creator_id': user.uid,
        'creator_name': user.displayName ?? 'Öğrenci',
        'university': university,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color activeSecondary;
  final VoidCallback onTap;

  const _TypeButton(
      {required this.label,
      required this.isActive,
      required this.activeColor,
      required this.activeSecondary,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(colors: [activeColor, activeSecondary])
                : null,
            color: isActive ? null : const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isActive
                    ? activeColor.withOpacity(0.55)
                    : Colors.white.withOpacity(0.12)),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: activeColor.withOpacity(0.35),
                        blurRadius: 14,
                        spreadRadius: 1),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[300],
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceTypeButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _PriceTypeButton(
      {required this.label,
      required this.isActive,
      required this.activeColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.16)
                : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isActive
                    ? activeColor.withOpacity(0.6)
                    : Colors.white.withOpacity(0.14)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? activeColor : Colors.grey[300],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
