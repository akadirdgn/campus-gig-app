import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:campusgig/models/chat_room.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:campusgig/utils/profile_modal_util.dart';
import 'package:campusgig/widgets/user_avatar.dart';
import 'dart:ui';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Lütfen giriş yapın')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080D17),
      appBar: AppBar(
        title: const Text('Mesajlar',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Color(0xFFF3F4F6))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -70,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.homeAccent.withOpacity(0.22),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.homeAccentSecondary.withOpacity(0.2),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: const SizedBox(),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chat_rooms')
                .where('participants', arrayContains: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text('Hata: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final rooms = snapshot.data!.docs
                  .map((doc) => ChatRoom.fromFirestore(doc))
                  .toList();
              rooms.sort((a, b) {
                if (a.lastMessageAt == null && b.lastMessageAt == null)
                  return 0;
                if (a.lastMessageAt == null) return 1;
                if (b.lastMessageAt == null) return -1;
                return b.lastMessageAt!.compareTo(a.lastMessageAt!);
              });

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: rooms.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final otherId =
                      room.participants.firstWhere((id) => id != user.uid);
                  final storedName = room.sellerId == otherId
                      ? room.sellerName
                      : room.buyerName;
                  final isUnread = room.unreadBy.contains(user.uid);
                  final cardAccent = room.gigType == 'bounties'
                      ? const Color(0xFF4CC9FF)
                      : const Color(0xFF7CFF6B);

                  // Firestore kullanıcı koleksiyonundan güncel ismi çek (Öğrenci yazısını ezmek için)
                  final Future<String> resolvedNameFuture = FirebaseFirestore.instance
                      .collection('users')
                      .doc(otherId)
                      .get()
                      .then((snap) {
                    if (!snap.exists) {
                      return (storedName.isEmpty || storedName == 'Öğrenci') 
                          ? 'Kullanıcı' 
                          : storedName;
                    }
                    
                    final d = snap.data()!;
                    final first = (d['firstName'] as String? ?? '').trim();
                    final last = (d['lastName'] as String? ?? '').trim();
                    
                    if (first.isNotEmpty || last.isNotEmpty) {
                      return '$first $last'.trim();
                    }
                    
                    final dispName = (d['displayName'] as String? ?? '').trim();
                    if (dispName.isNotEmpty && dispName != 'Öğrenci') {
                      return dispName;
                    }
                    
                    return 'Kullanıcı';
                  });

                  return FutureBuilder<String>(
                    future: resolvedNameFuture,
                    builder: (context, nameSnap) {
                      final otherName = nameSnap.data ?? (storedName == 'Öğrenci' ? 'Yükleniyor...' : (storedName.isNotEmpty ? storedName : 'Yükleniyor...'));

                      return InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => context.push('/chat/${room.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0x1EFFFFFF),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: cardAccent
                                    .withOpacity(isUnread ? 0.45 : 0.22)),
                            boxShadow: [
                              BoxShadow(
                                color: cardAccent
                                    .withOpacity(isUnread ? 0.18 : 0.08),
                                blurRadius: 16,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    ProfileModalUtil.show(context, otherId),
                                child: Stack(
                                  children: [
                                    UserAvatar(
                                      userId: otherId,
                                      displayName: otherName,
                                      radius: 28,
                                    ),
                                    if (isUnread)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: cardAccent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: const Color(0xFF080D17),
                                                width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            otherName == '?'
                                                ? 'Yükleniyor...'
                                                : otherName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: isUnread
                                                  ? FontWeight.w900
                                                  : FontWeight.bold,
                                              fontSize: 16,
                                              color: const Color(0xFFF3F4F6),
                                            ),
                                          ),
                                        ),
                                        if (room.lastMessageAt != null)
                                          Text(
                                            DateFormat('HH:mm')
                                                .format(room.lastMessageAt!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isUnread
                                                  ? cardAccent
                                                  : Colors.grey[400],
                                              fontWeight: isUnread
                                                  ? FontWeight.w900
                                                  : FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      room.gigTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: cardAccent.withOpacity(0.85),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      room.lastMessage ?? 'Henüz mesaj yok',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isUnread
                                            ? const Color(0xFFE5E7EB)
                                            : Colors.grey[400],
                                        fontWeight: isUnread
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.messageSquare,
              size: 48, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          const Text('Henüz mesajın yok',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFE5E7EB))),
        ],
      ),
    );
  }
}
