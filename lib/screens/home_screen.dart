import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campusgig/models/gig.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import 'package:campusgig/utils/profile_modal_util.dart';
import 'package:campusgig/widgets/user_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _activeTab = 'marketplace'; // marketplace or bounties

  bool get _isMarketplace => _activeTab == 'marketplace';
  Color get _accent =>
      _isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
  Color get _accentSecondary =>
      _isMarketplace ? const Color(0xFF1E9D4B) : const Color(0xFF8B5CF6);
  Color get _bgStart =>
      _isMarketplace ? const Color(0xFF0A0F12) : const Color(0xFF070B1A);
  Color get _bgEnd =>
      _isMarketplace ? const Color(0xFF0E1713) : const Color(0xFF141230);

  @override
  void initState() {
    super.initState();
    AppTheme.homeTabNotifier.value = _activeTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgStart,
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
          // Background Blobs (Mesh Gradient Effect)
          Positioned(
            top: -100,
            left: -50,
            child: Pulse(
              infinite: true,
              duration: const Duration(seconds: 4),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.18),
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withOpacity(0.24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Pulse(
              infinite: true,
              duration: const Duration(seconds: 6),
              delay: const Duration(seconds: 1),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  color: _accentSecondary.withOpacity(0.18),
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentSecondary.withOpacity(0.24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Blur Layer covering blobs to merge them
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSegmentedControl(),
                Expanded(
                  child: _buildGigList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildHeaderContent(
        displayName: 'Gezgin',
        tokenBalance: 0,
        timeCreditBalance: 0,
        avatarSeed: 'guest',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final firstName = (data?['firstName'] ?? '').toString().trim();
        final lastName = (data?['lastName'] ?? '').toString().trim();
        final displayName = _resolveDisplayName(user, firstName, lastName);
        final tokenBalance = _toInt(data?['wallet_cgt']);
        final timeCreditBalance = _toInt(data?['wallet_time_credit']);

        return _buildHeaderContent(
          displayName: displayName,
          tokenBalance: tokenBalance,
          timeCreditBalance: timeCreditBalance,
          avatarSeed: user.uid,
        );
      },
    );
  }

  Widget _buildHeaderContent({
    required String displayName,
    required int tokenBalance,
    required int timeCreditBalance,
    required String avatarSeed,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: FadeInDown(
        duration: const Duration(milliseconds: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Merhaba, $displayName!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Color(0xFFF3F4F6),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Profil Menusu',
                  color: const Color(0xFF121A2A),
                  elevation: 0,
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _accent.withOpacity(0.22)),
                  ),
                  onSelected: (value) async {
                    if (value == 'profile') {
                      context.go('/profile');
                    }
                    if (value == 'logout') {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) {
                        return;
                      }
                      context.go('/login');
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(LucideIcons.user,
                                size: 16, color: _accent),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Profili Goru',
                            style: TextStyle(
                              color: Color(0xFFE5E7EB),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 8),
                    const PopupMenuItem<String>(
                      enabled: false,
                      height: 0,
                      child: SizedBox.shrink(),
                    ),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0x22EF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.logOut,
                                size: 16, color: Color(0xFFF87171)),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Cikis Yap',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: UserAvatar(
                    userId: avatarSeed,
                    displayName: displayName,
                    radius: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _activeTab == 'marketplace'
                        ? _accent
                        : _accentSecondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.45),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'KAMPÜSÜNDE NELER OLUYOR?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _BalanceChip(
                  label: 'Token',
                  value: tokenBalance,
                  color: _isMarketplace ? _accent : const Color(0xFF4CC9FF),
                  icon: LucideIcons.coins,
                ),
                const SizedBox(width: 10),
                _BalanceChip(
                  label: 'Zaman Kredisi',
                  value: timeCreditBalance,
                  color: _isMarketplace
                      ? const Color(0xFF46CF7B)
                      : const Color(0xFFA78BFA),
                  icon: LucideIcons.timer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _resolveDisplayName(User user, String firstName, String lastName) {
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final emailPrefix = user.email?.split('@').first.trim();
    if (emailPrefix != null && emailPrefix.isNotEmpty) {
      return emailPrefix;
    }

    return 'Gezgin';
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0x24FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _SegmentButton(
                  label: 'Yetenek Pazarı',
                  isActive: _activeTab == 'marketplace',
                  activeColor: _accent,
                  onTap: () => setState(() {
                    _activeTab = 'marketplace';
                    AppTheme.homeTabNotifier.value = _activeTab;
                  }),
                ),
                _SegmentButton(
                  label: 'Görev Panosu',
                  isActive: _activeTab == 'bounties',
                  activeColor: _accentSecondary,
                  onTap: () => setState(() {
                    _activeTab = 'bounties';
                    AppTheme.homeTabNotifier.value = _activeTab;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 5),
            LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: _activeTab == 'marketplace'
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: SizedBox(
                    width: constraints.maxWidth / 2,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        width: MediaQuery.of(context).size.width * 0.35,
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: _activeTab == 'marketplace'
                                ? const [Color(0xFF8CFF7A), Color(0xFF28A95B)]
                                : const [Color(0xFF8B5CF6), Color(0xFF38BDF8)],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGigList() {
    final collection = _activeTab == 'marketplace' ? 'services' : 'bounties';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final gigs =
            snapshot.data!.docs.map((doc) => Gig.fromFirestore(doc)).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: gigs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return FadeInUp(
              delay: Duration(milliseconds: 100 * index),
              child: _GigCard(gig: gigs[index], activeTab: _activeTab),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍃', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            _activeTab == 'marketplace'
                ? 'Şu an mevcut hizmet yok'
                : 'Şu an mevcut görev yok',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isActive ? activeColor.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF9CA3AF),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _BalanceChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.24),
            const Color(0x22000000),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.34),
            blurRadius: 14,
            offset: const Offset(5, 7),
          ),
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GigCard extends StatelessWidget {
  final Gig gig;
  final String activeTab;

  const _GigCard({required this.gig, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final isMarketplace = activeTab == 'marketplace';
    final color =
        isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
    final cardMixB =
        isMarketplace ? const Color(0xFF175B32) : const Color(0xFF8B5CF6);

    return GestureDetector(
      onTap: () => context.push('/gig-detail', extra: gig),
      child: Hero(
        tag: 'gig-${gig.id}',
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.18), // Slightly increased opacity
                      cardMixB.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28), // Slightly tighter radius for precision
                  border: Border.all(
                    color: color.withOpacity(0.35), 
                    width: 1.2 // Thicker border for definition
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.12),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                ProfileModalUtil.show(context, gig.creatorId),
                            child: Row(
                              children: [
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(gig.creatorId)
                                      .get(),
                                  builder: (context, userSnapshot) {
                                    final userData = userSnapshot.data?.data()
                                        as Map<String, dynamic>?;
                                    final firstName =
                                        (userData?['firstName'] ?? '')
                                            .toString()
                                            .trim();
                                    final lastName = (userData?['lastName'] ?? '')
                                        .toString()
                                        .trim();
                                    final actualName = (firstName.isNotEmpty ||
                                            lastName.isNotEmpty)
                                        ? '$firstName $lastName'.trim()
                                        : gig.creatorName;
                                    return UserAvatar(
                                      userId: gig.creatorId,
                                      displayName: actualName,
                                      radius: 24,
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(gig.creatorId)
                                            .get(),
                                        builder: (context, userSnapshot) {
                                          if (userSnapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  gig.creatorName,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14),
                                                ),
                                                Text(
                                                  'YÜKLENİYOR...',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[400],
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }

                                          final userData = userSnapshot.data?.data()
                                              as Map<String, dynamic>?;

                                          final firstName =
                                              (userData?['firstName'] ?? '')
                                                  .toString()
                                                  .trim();
                                          final lastName =
                                              (userData?['lastName'] ?? '')
                                                  .toString()
                                                  .trim();
                                          final actualName =
                                              (firstName.isNotEmpty ||
                                                      lastName.isNotEmpty)
                                                  ? '$firstName $lastName'.trim()
                                                  : gig.creatorName;

                                          final university = userData?['university']
                                                  ?.toString()
                                                  .toUpperCase() ??
                                              'KAMPÜS ÖĞRENCİSİ';
                                          final department =
                                              userData?['department'] ?? '';
                                          final displayString = department
                                                  .isNotEmpty
                                              ? '$university • ${department.toUpperCase()}'
                                              : university;

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                actualName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16.5,
                                                    color: Color(0xFFF3F4F6),
                                                    letterSpacing: -0.2),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                displayString,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white70,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Text(
                            activeTab == 'marketplace' ? 'HİZMET' : 'GÖREV',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      gig.title,
                      style: const TextStyle(
                          fontSize: 19, // Bolder
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF9FAFB),
                          letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      gig.description,
                      maxLines: 3, // Allow a bit more context
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFD1D5DB), // Softer but clear gray
                          fontSize: 14, // Larger
                          height: 1.5,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    // Social Bar: Likes & Comments
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(activeTab == 'marketplace'
                              ? 'services'
                              : 'bounties')
                          .doc(gig.id)
                          .snapshots(),
                      builder: (context, gigSnap) {
                        final data =
                            gigSnap.data?.data() as Map<String, dynamic>?;
                        final likes = (data?['likes'] as List?)?.length ?? 0;

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('gig_comments')
                              .where('gig_id', isEqualTo: gig.id)
                              .snapshots(),
                          builder: (context, commentSnap) {
                            final comments = commentSnap.data?.docs.length ?? 0;
                            final currentUid =
                                FirebaseAuth.instance.currentUser?.uid;
                            final likesList = (data?['likes'] as List?) ?? [];
                            final isLiked = currentUid != null &&
                                likesList.contains(currentUid);

                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (currentUid == null) return;
                                    final ref = FirebaseFirestore.instance
                                        .collection(activeTab == 'marketplace'
                                            ? 'services'
                                            : 'bounties')
                                        .doc(gig.id);
                                    if (isLiked) {
                                      await ref.update({
                                        'likes':
                                            FieldValue.arrayRemove([currentUid])
                                      });
                                    } else {
                                      await ref.update({
                                        'likes':
                                            FieldValue.arrayUnion([currentUid])
                                      });
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.heart,
                                        size: 15,
                                        color: isLiked
                                            ? AppTheme.accentColor
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$likes',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isLiked
                                              ? AppTheme.accentColor
                                              : Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    Icon(LucideIcons.messageCircle,
                                        size: 15, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$comments yorum',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ÖDÜL BÜTÇESİ',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    cardMixB.withOpacity(0.28),
                                    color.withOpacity(0.18),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${gig.price}',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: color),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    gig.priceType == 'swap' ? 'ZK' : 'CGT',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Sohbet başlatabilmek için giriş yapmalısınız.')),
                              );
                              return;
                            }

                            if (currentUser.uid == gig.creatorId) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Kendi ilanınıza teklif veremezsiniz.')),
                              );
                              return;
                            }

                            try {
                              // Check if room already exists
                              final existingRooms = await FirebaseFirestore
                                  .instance
                                  .collection('chat_rooms')
                                  .where('gig_id', isEqualTo: gig.id)
                                  .where('participants',
                                      arrayContains: currentUser.uid)
                                  .get();

                              String roomId;
                              if (existingRooms.docs.isNotEmpty) {
                                roomId = existingRooms.docs.first.id;
                              } else {
                                // Create new room
                                final currentUserName =
                                    currentUser.displayName ?? 'Öğrenci';
                                final isMarketplace =
                                    activeTab == 'marketplace';

                                // Marketplace: ilan sahibi kazanır, başlatan kullanıcı öder.
                                // Bounties: ilan sahibi öder, görevi üstlenen kullanıcı kazanır.
                                final sellerId = isMarketplace
                                    ? gig.creatorId
                                    : currentUser.uid;
                                final sellerName = isMarketplace
                                    ? gig.creatorName
                                    : currentUserName;
                                final buyerId = isMarketplace
                                    ? currentUser.uid
                                    : gig.creatorId;
                                final buyerName = isMarketplace
                                    ? currentUserName
                                    : gig.creatorName;
                                final otherUserId =
                                    currentUser.uid == gig.creatorId
                                        ? buyerId
                                        : gig.creatorId;

                                final newRoom = await FirebaseFirestore.instance
                                    .collection('chat_rooms')
                                    .add({
                                  'gig_id': gig.id,
                                  'gig_title': gig.title,
                                  'seller_id': sellerId,
                                  'seller_name': sellerName,
                                  'buyer_id': buyerId,
                                  'buyer_name': buyerName,
                                  'participants': [
                                    currentUser.uid,
                                    gig.creatorId
                                  ],
                                  'unread_by': [otherUserId],
                                  'gig_type':
                                      isMarketplace ? 'services' : 'bounties',
                                  'role_version': 2,
                                  'status': 'chatting',
                                  'last_message': 'Sohbet başlatıldı',
                                  'last_message_at':
                                      FieldValue.serverTimestamp(),
                                  'created_at': FieldValue.serverTimestamp(),
                                });
                                roomId = newRoom.id;
                              }

                              if (context.mounted) {
                                context.push('/chat/$roomId');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Hata oluştu: \${e.toString()}')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            shadowColor: color.withOpacity(0.5),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: isMarketplace
                                    ? const [
                                        Color(0xFF97FF84),
                                        Color(0xFF189849)
                                      ]
                                    : const [
                                        Color(0xFF9B5DFF),
                                        Color(0xFF32D8FF)
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.45),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Text(
                                activeTab == 'marketplace'
                                    ? 'Teklife Git'
                                    : 'Görevi İncele',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
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
    );
  }
}
