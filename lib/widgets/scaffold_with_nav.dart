import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campusgig/theme/app_theme.dart';

class ScaffoldWithNav extends StatefulWidget {
  final Widget child;

  const ScaffoldWithNav({super.key, required this.child});

  @override
  State<ScaffoldWithNav> createState() => _ScaffoldWithNavState();
}

class _ScaffoldWithNavState extends State<ScaffoldWithNav> {
  DateTime _lastSeenHome = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location == '/') {
      _lastSeenHome = DateTime.now();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080D17),
      body: widget.child,
      bottomNavigationBar: ValueListenableBuilder<String>(
        valueListenable: AppTheme.homeTabNotifier,
        builder: (context, mode, _) {
          final isMarketplace = mode == 'marketplace';
          final accent =
              isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
          final accentSecondary =
              isMarketplace ? const Color(0xFF1E9D4B) : const Color(0xFF8B5CF6);

          return ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0x2AFFFFFF),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) {
                          if (location == '/') {
                            return _NavItem(
                              icon: LucideIcons.home,
                              label: 'Keşfet',
                              isSelected: true,
                              onTap: () => context.go('/'),
                              selectedColor: accent,
                            );
                          }

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('services')
                                .where('created_at',
                                    isGreaterThan:
                                        Timestamp.fromDate(_lastSeenHome))
                                .snapshots(),
                            builder: (context, servicesSnapshot) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('bounties')
                                    .where('created_at',
                                        isGreaterThan:
                                            Timestamp.fromDate(_lastSeenHome))
                                    .snapshots(),
                                builder: (context, bountiesSnapshot) {
                                  int sCount =
                                      servicesSnapshot.data?.docs.length ?? 0;
                                  int bCount =
                                      bountiesSnapshot.data?.docs.length ?? 0;
                                  return _NavItem(
                                    icon: LucideIcons.home,
                                    label: 'Keşfet',
                                    isSelected: false,
                                    onTap: () => context.go('/'),
                                    badgeCount: sCount + bCount,
                                    selectedColor: accent,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseAuth.instance.currentUser != null
                            ? FirebaseFirestore.instance
                                .collection('chat_rooms')
                                .where('participants',
                                    arrayContains:
                                        FirebaseAuth.instance.currentUser!.uid)
                                .snapshots()
                            : const Stream.empty(),
                        builder: (context, snapshot) {
                          int unreadCount = 0;
                          if (snapshot.hasData) {
                            for (var doc in snapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final List<dynamic> unreadBy =
                                  data['unread_by'] ?? [];
                              if (unreadBy.contains(
                                  FirebaseAuth.instance.currentUser!.uid)) {
                                unreadCount++;
                              }
                            }
                          }

                          return _NavItem(
                            icon: LucideIcons.messageSquare,
                            label: 'Mesajlar',
                            isSelected: location == '/messages',
                            onTap: () => context.go('/messages'),
                            badgeCount: unreadCount,
                            selectedColor: accent,
                          );
                        },
                      ),
                      _NavItem(
                        icon: LucideIcons.plusCircle,
                        label: 'Oluştur',
                        isSelected: location == '/create-gig',
                        onTap: () => context.go('/create-gig'),
                        isPrimary: true,
                        selectedColor: accent,
                        secondaryColor: accentSecondary,
                      ),
                      _NavItem(
                        icon: LucideIcons.user,
                        label: 'Profil',
                        isSelected: location == '/profile',
                        onTap: () => context.go('/profile'),
                        selectedColor: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPrimary;
  final int badgeCount;
  final Color selectedColor;
  final Color? secondaryColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isPrimary = false,
    this.badgeCount = 0,
    this.selectedColor = const Color(0xFF7CFF6B),
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryGradientB = secondaryColor ?? const Color(0xFF1E9D4B);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
            horizontal: isPrimary ? 12 : 14, vertical: isPrimary ? 8 : 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? Colors.transparent
              : (isSelected
                  ? selectedColor.withOpacity(0.14)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(isPrimary ? 20 : 24),
          boxShadow: isSelected && !isPrimary
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.28),
                    blurRadius: 14,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (isPrimary)
                  Container(
                    width: 44, // Slightly larger for better tap target and visual weight
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [selectedColor, primaryGradientB],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: selectedColor.withOpacity(0.42),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Icon(LucideIcons.plus,
                        color: Colors.white, size: 24), // Slightly larger icon
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: selectedColor.withOpacity(0.42),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? selectedColor : Colors.grey[400],
                      size: 22,
                    ),
                  ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selectedColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
