import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:campusgig/widgets/user_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Lütfen giriş yapın')));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF080D17),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF080D17), Color(0xFF13142E)],
                ),
              ),
            ),
          ),
          // Animated Background Blobs
          Positioned(
            top: -150,
            left: -100,
            child: Pulse(
              infinite: true,
              duration: const Duration(seconds: 5),
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  color: const Color(0xFF7CFF6B).withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Pulse(
              infinite: true,
              duration: const Duration(seconds: 7),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              if (userData == null) {
                return const Center(child: Text('Kullanıcı verisi bulunamadı'));
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(context, userData, user.uid),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          _buildBalanceCards(context, userData),
                          const SizedBox(height: 32),
                          _buildLockedIdentityCard(userData),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            icon: LucideIcons.graduationCap,
                            title: 'Eğitim Bilgilerim',
                            subtitle:
                                '${userData["grade"] ?? "1. Sınıf"} / ${userData["department"] ?? "Henüz Belirtilmemiş"}',
                            showArrow: false,
                            onTap: () {},
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            icon: LucideIcons.wallet,
                            title: 'Cüzdanım & Ödüller',
                            subtitle: 'Bakiyeni kontrol et, günlük ödülünü al',
                            onTap: () => context.push('/wallet'),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            icon: LucideIcons.briefcase,
                            title: 'İlanlarım',
                            subtitle: 'İlanlarını düzenle veya sil',
                            onTap: () => context.push('/my-gigs'),
                          ),
                          if (userData['isAdmin'] == true) ...[
                            const SizedBox(height: 12),
                            _buildMenuItem(
                              icon: LucideIcons.shieldCheck,
                              title: 'Admin Paneli',
                              subtitle:
                                  'Platformu, kullanıcıları ve itirazları yönet',
                              onTap: () => context.push('/admin'),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _buildLogoutButton(context),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, Map<String, dynamic> userData, String uid) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F1419), Color(0xFF15191E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF7CFF6B).withOpacity(0.1),
              border: Border.all(
                color: const Color(0xFF7CFF6B).withOpacity(0.3),
                width: 1.5,
              ),
              shape: BoxShape.circle,
            ),
            child: UserAvatar(
              userId: uid,
              displayName:
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
              radius: 48,
            ),
          ),
          const SizedBox(height: 28),
          // Name
          Text(
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF3F4F6),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          // University & Department
          Column(
            children: [
              Text(
                userData['university']?.toString() ??
                    'Üniversite Belirtilmemiş',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userData['department']?.toString() ?? 'Bölüm Belirtilmemiş',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCards(
      BuildContext context, Map<String, dynamic> userData) {
    return Row(
      children: [
        _BalanceCard(
          label: 'CG TOKEN',
          value: '${userData['wallet_cgt'] ?? 0}',
          color: const Color(0xFF7CFF6B),
          onTap: () => context.push('/wallet'),
        ),
        const SizedBox(width: 16),
        _BalanceCard(
          label: 'ZAMAN PUANI',
          value: '${userData['wallet_time_credit'] ?? 0}',
          color: const Color(0xFF8B5CF6),
          onTap: () => context.push('/wallet'),
        ),
      ],
    );
  }

  Widget _buildLockedIdentityCard(Map<String, dynamic> userData) {
    final name =
        '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final email = (userData['studentEmail'] ?? 'Belirtilmemis').toString();
    final university = (userData['university'] ?? 'Belirtilmemis').toString();
    final department = (userData['department'] ?? 'Belirtilmemis').toString();
    final grade = (userData['grade'] ?? 'Belirtilmemis').toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: const Color(0x1EFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                )
              ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF7CFF6B).withOpacity(0.16),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(LucideIcons.lock,
                        size: 14, color: Color(0xFF7CFF6B)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ONAYLI KİMLİK',
                    style: TextStyle(
                      color: Color(0xFF7CFF6B),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _identityRow('Ad Soyad', name.isEmpty ? 'Belirtilmemis' : name),
              _identityRow('Öğrenci Maili', email),
              _identityRow('Üniversite', university),
              _identityRow('Bölüm', department),
              _identityRow('Sınıf', grade),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA78BFA),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE5E7EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      bool showArrow = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12))),
              child: Center(
                  child: Icon(icon, size: 20, color: const Color(0xFFD1D5DB))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFFF3F4F6))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            if (showArrow)
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          context.go('/login');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0x22EF4444),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x55FCA5A5)),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.logOut, size: 20, color: Color(0xFFDC2626)),
            SizedBox(width: 16),
            Text('Oturumu Kapat',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFFDC2626))),
            Spacer(),
            Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFFCA5A5)),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _BalanceCard(
      {required this.label,
      required this.value,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: Colors.white.withOpacity(0.16), width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 8),
                  Text(value,
                      style: TextStyle(
                          color: color,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
