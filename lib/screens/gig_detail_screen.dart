import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campusgig/models/gig.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campusgig/utils/profile_modal_util.dart';
import 'package:campusgig/widgets/user_avatar.dart';
import 'package:intl/intl.dart';

class GigDetailScreen extends ConsumerStatefulWidget {
  final Gig gig;

  const GigDetailScreen({super.key, required this.gig});

  @override
  ConsumerState<GigDetailScreen> createState() => _GigDetailScreenState();
}

class _GigDetailScreenState extends ConsumerState<GigDetailScreen> {
  bool _isLoading = false;

  bool get _isMarketplace => widget.gig.type == 'services';
  Color get _accent =>
      _isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
  Color get _accentSecondary =>
      _isMarketplace ? const Color(0xFF1E9D4B) : const Color(0xFF8B5CF6);
  Color get _bgStart =>
      _isMarketplace ? const Color(0xFF09110D) : const Color(0xFF070B1A);
  Color get _bgEnd =>
      _isMarketplace ? const Color(0xFF0D1A14) : const Color(0xFF151235);

  void _startChat() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sohbet başlatabilmek için giriş yapmalısınız.')),
      );
      return;
    }

    if (currentUser.uid == widget.gig.creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kendi ilanınıza teklif veremezsiniz.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existingRooms = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('gig_id', isEqualTo: widget.gig.id)
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String roomId;
      if (existingRooms.docs.isNotEmpty) {
        roomId = existingRooms.docs.first.id;
      } else {
        // Fetch current user's name from Firestore for the chat room
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final uData = userDoc.data();
        final fName = (uData?['firstName'] ?? '').toString().trim();
        final lName = (uData?['lastName'] ?? '').toString().trim();
        
        String currentUserName = 'Kullanıcı';
        if (fName.isNotEmpty || lName.isNotEmpty) {
          currentUserName = '$fName $lName'.trim();
        } else {
          final dName = (currentUser.displayName ?? '').trim();
          if (dName.isNotEmpty && dName != 'Öğrenci') {
            currentUserName = dName;
          }
        }

        final isMarketplace = widget.gig.type == 'services';

        // Marketplace: ilan sahibi kazanır, başlatan kullanıcı öder.
        // Bounties: ilan sahibi öder, görevi üstlenen kullanıcı kazanır.
        final sellerId = isMarketplace ? widget.gig.creatorId : currentUser.uid;
        final sellerName =
            isMarketplace ? widget.gig.creatorName : currentUserName;
        final buyerId = isMarketplace ? currentUser.uid : widget.gig.creatorId;
        final buyerName =
            isMarketplace ? currentUserName : widget.gig.creatorName;

        final newRoom =
            await FirebaseFirestore.instance.collection('chat_rooms').add({
          'gig_id': widget.gig.id,
          'gig_title': widget.gig.title,
          'seller_id': sellerId,
          'seller_name': sellerName,
          'buyer_id': buyerId,
          'buyer_name': buyerName,
          'participants': [currentUser.uid, widget.gig.creatorId],
          'unread_by': [widget.gig.creatorId],
          'gig_type': isMarketplace ? 'services' : 'bounties',
          'role_version': 2,
          'status': 'chatting',
          'last_message': 'Sohbet başlatıldı',
          'last_message_at': FieldValue.serverTimestamp(),
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
          SnackBar(content: Text('Hata oluştu: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _accent;

    return Scaffold(
      backgroundColor: _bgStart,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: _bgStart,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x24FFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.3), blurRadius: 14),
                  ],
                ),
                child: const Icon(LucideIcons.arrowLeft,
                    color: Color(0xFFF3F4F6), size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'gig-${widget.gig.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Backdrop Blurry Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _bgStart,
                              _bgEnd,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      // Content
                      Positioned(
                        bottom: 40,
                        left: 24,
                        right: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x24FFFFFF),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: color.withOpacity(0.38)),
                                boxShadow: [
                                  BoxShadow(
                                      color: color.withOpacity(0.24),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Text(
                                widget.gig.type == 'services'
                                    ? 'HİZMET'
                                    : 'GÖREV',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.gig.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF3F4F6),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Card (Glassmorphism)
                  GestureDetector(
                    onTap: () =>
                        ProfileModalUtil.show(context, widget.gig.creatorId),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x1EFFFFFF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: color.withOpacity(0.24)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.gig.creatorId)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final data =
                              snapshot.data?.data() as Map<String, dynamic>?;
                          final firstName =
                              (data?['firstName'] ?? '').toString().trim();
                          final lastName =
                              (data?['lastName'] ?? '').toString().trim();
                          final displayName =
                              (firstName.isNotEmpty || lastName.isNotEmpty)
                                  ? '$firstName $lastName'.trim()
                                  : widget.gig.creatorName;

                          final university =
                              data?['university']?.toString().toUpperCase() ??
                                  widget.gig.university;

                          return Row(
                            children: [
                              UserAvatar(
                                userId: widget.gig.creatorId,
                                displayName: displayName,
                                radius: 28,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF3F4F6)),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(LucideIcons.graduationCap,
                                            size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            university,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(LucideIcons.chevronRight,
                                  color: Colors.grey[400]),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Açıklama',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF3F4F6)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.gig.description,
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey[300], height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  // Likes & Comments Section
                  _buildLikesRow(context),
                  const SizedBox(height: 24),
                  _buildCommentsSection(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20).copyWith(
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: const Color(0x2AFFFFFF),
          border:
              Border(top: BorderSide(color: Colors.white.withOpacity(0.15))),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.24),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ÖDÜL BÜTÇESİ',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${widget.gig.price}',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: color),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.gig.priceType == 'swap' ? 'ZK' : 'CGT',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _startChat,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          )
                        : Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: _isMarketplace
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
                                  color: color.withOpacity(0.48),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.gig.type == 'services'
                                    ? 'Hemen Teklif Ver'
                                    : 'Görevi Üstlen',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Likes ─────────────────────────────────────────────────────────────

  Widget _buildLikesRow(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final collection = widget.gig.type == 'services' ? 'services' : 'bounties';
    final docRef =
        FirebaseFirestore.instance.collection(collection).doc(widget.gig.id);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final List<dynamic> likes = data?['likes'] ?? [];
        final bool isLiked =
            currentUser != null && likes.contains(currentUser.uid);

        return Row(
          children: [
            GestureDetector(
              onTap: () async {
                if (currentUser == null) return;
                if (isLiked) {
                  await docRef.update({
                    'likes': FieldValue.arrayRemove([currentUser.uid])
                  });
                } else {
                  await docRef.update({
                    'likes': FieldValue.arrayUnion([currentUser.uid])
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isLiked
                      ? _accent.withOpacity(0.2)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isLiked
                          ? _accent.withOpacity(0.45)
                          : Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? LucideIcons.heart : LucideIcons.heart,
                      size: 18,
                      color: isLiked ? _accent : Colors.grey[400],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${likes.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isLiked ? _accent : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.messageCircle,
                      size: 18, color: Colors.grey[300]),
                  const SizedBox(width: 6),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('gig_comments')
                        .where('gig_id', isEqualTo: widget.gig.id)
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return Text('$count yorum',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[300]));
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Comments ──────────────────────────────────────────────────────────

  Widget _buildCommentsSection() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final commentController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yorumlar',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF3F4F6)),
        ),
        const SizedBox(height: 16),

        // Comment Input
        Row(
          children: [
            UserAvatar(
              userId: currentUser?.uid ?? 'anon',
              displayName: currentUser?.displayName ?? 'Öğrenci',
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: commentController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Bir yorum yaz...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0x1EFFFFFF),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(LucideIcons.send, color: _accent, size: 18),
                    onPressed: () async {
                      if (currentUser == null ||
                          commentController.text.trim().isEmpty) return;
                      final text = commentController.text.trim();
                      commentController.clear();

                      // Fetch the current user's name from Firestore
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .get();
                      final uData = userDoc.data();
                      final firstName =
                          (uData?['firstName'] ?? '').toString().trim();
                      final lastName =
                          (uData?['lastName'] ?? '').toString().trim();
                      final name = (firstName.isNotEmpty || lastName.isNotEmpty)
                          ? '$firstName $lastName'.trim()
                          : (currentUser.displayName ?? 'Öğrenci');

                      await FirebaseFirestore.instance
                          .collection('gig_comments')
                          .add({
                        'gig_id': widget.gig.id,
                        'gig_collection': widget.gig.type,
                        'user_id': currentUser.uid,
                        'user_name': name,
                        'comment': text,
                        'created_at': FieldValue.serverTimestamp(),
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Comments List
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('gig_comments')
              .where('gig_id', isEqualTo: widget.gig.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Henüz yorum yok. İlk yorumu yap!',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ),
              );
            }

            final comments = List.from(snapshot.data!.docs)
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = (aData['created_at'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                final bTime = (bData['created_at'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                return bTime.compareTo(aTime);
              });
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final commentDocId = comments[index].id;
                final data = comments[index].data() as Map<String, dynamic>;
                final userId = data['user_id'] ?? '';
                final userName = data['user_name'] ?? 'Öğrenci';
                final comment = data['comment'] ?? '';
                final createdAt = (data['created_at'] as Timestamp?)?.toDate();
                final isOwner = currentUser?.uid == userId;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => ProfileModalUtil.show(context, userId),
                      child: UserAvatar(
                        userId: userId,
                        displayName: userName,
                        radius: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFFF3F4F6)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (createdAt != null)
                                      Text(
                                        DateFormat('dd.MM HH:mm')
                                            .format(createdAt),
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 10),
                                      ),
                                    if (isOwner) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () async {
                                          await FirebaseFirestore.instance
                                              .collection('gig_comments')
                                              .doc(commentDocId)
                                              .delete();
                                        },
                                        child: Icon(LucideIcons.trash2,
                                            size: 13, color: Colors.red[300]),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(comment,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[300],
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
