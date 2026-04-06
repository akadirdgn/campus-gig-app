import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:campusgig/widgets/user_avatar.dart';

// ─── Dark Theme Colors ────────────────────────────────────────────────────
const _bg = Color(0xFF0A0A0F);
const _surface = Color(0xFF13131A);
const _card = Color(0xFF1C1C27);
const _border = Color(0xFF2A2A38);
const _accent = Color(0xFF6366F1); // Indigo
const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);
const _amber = Color(0xFFF59E0B);
const _textPrimary = Color(0xFFF8FAFC);
const _textSecondary = Color(0xFF94A3B8);

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: _textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.shieldCheck, color: _accent, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Admin Paneli', style: TextStyle(fontWeight: FontWeight.w900, color: _textPrimary, fontSize: 18)),
            ],
          ),
          bottom: const TabBar(
            labelColor: _accent,
            unselectedLabelColor: _textSecondary,
            indicatorColor: _accent,
            indicatorSize: TabBarIndicatorSize.tab,
            isScrollable: true,
            tabs: [
              Tab(text: 'Şikayetler', icon: Icon(LucideIcons.flag, size: 16)),
              Tab(text: 'İtirazlar', icon: Icon(LucideIcons.alertOctagon, size: 16)),
              Tab(text: 'Kullanıcılar', icon: Icon(LucideIcons.users, size: 16)),
              Tab(text: 'İlanlar', icon: Icon(LucideIcons.layers, size: 16)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReportsTab(),
            _DisputesTab(),
            _UsersTab(),
            _GigsTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Reports (Şikayetler) Tab ─────────────────────────────────────────────

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _DarkLoader();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _DarkEmpty(
            icon: LucideIcons.checkCircle,
            message: 'Açık şikayet yok',
            color: _green,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'open';
            final reportedUserId = data['reported_user_id'] ?? '';
            final reportedUserName = data['reported_user_name'] ?? 'Bilinmiyor';
            final reason = data['reason'] ?? 'Belirtilmemiş';
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();

            return Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: status == 'open' ? _red.withOpacity(0.3) : _border),
              ),
              child: ExpansionTile(
                collapsedIconColor: _textSecondary,
                iconColor: _accent,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (status == 'open' ? _red : _green).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status == 'open' ? LucideIcons.flag : LucideIcons.checkCircle,
                    color: status == 'open' ? _red : _green,
                    size: 16,
                  ),
                ),
                title: Text(reportedUserName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reason, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    if (createdAt != null)
                      Text(DateFormat('dd.MM.yyyy HH:mm').format(createdAt),
                          style: const TextStyle(color: _textSecondary, fontSize: 10)),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (status == 'open' && reportedUserId.isNotEmpty) ...[
                          Expanded(
                            child: _DarkButton(
                              label: 'Kullanıcıyı Banla',
                              color: _red,
                              icon: LucideIcons.ban,
                              onTap: () async {
                                await FirebaseFirestore.instance.collection('users').doc(reportedUserId).update({'isBanned': true});
                                await FirebaseFirestore.instance.collection('reports').doc(doc.id).update({'status': 'actioned'});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: _DarkButton(
                            label: status == 'open' ? 'Kapat' : 'Tekrar Aç',
                            color: status == 'open' ? _green : _amber,
                            icon: status == 'open' ? LucideIcons.checkCircle : LucideIcons.refreshCw,
                            onTap: () async {
                              await FirebaseFirestore.instance.collection('reports').doc(doc.id).update({
                                'status': status == 'open' ? 'closed' : 'open',
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Disputes (İtirazlar) Tab ─────────────────────────────────────────────

class _DisputesTab extends StatelessWidget {
  const _DisputesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disputes')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _DarkLoader();

        final disputes = snapshot.data!.docs;
        if (disputes.isEmpty) {
          return _DarkEmpty(
            icon: LucideIcons.checkCircle,
            message: 'Açık itiraz yok',
            color: _green,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: disputes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = disputes[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'open';
            final reason = data['reason'] ?? 'Bilinmeyen Neden';
            final roomId = data['room_id'] ?? '';
            final details = data['details'] ?? 'Detay yok';
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();

            return Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: status == 'open' ? _red.withOpacity(0.4) : _border),
              ),
              child: ExpansionTile(
                collapsedIconColor: _textSecondary,
                iconColor: _accent,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (status == 'open' ? _red : _green).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status == 'open' ? LucideIcons.alertTriangle : LucideIcons.checkCircle,
                    color: status == 'open' ? _red : _green,
                    size: 16,
                  ),
                ),
                title: Text(reason,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary)),
                subtitle: Text(
                  status == 'open' ? 'Açık İtiraz' : 'Çözüldü',
                  style: TextStyle(color: status == 'open' ? _red : _green, fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kullanıcı Açıklaması:', style: TextStyle(fontWeight: FontWeight.bold, color: _textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(details, style: const TextStyle(fontSize: 14, color: _textPrimary)),
                        const SizedBox(height: 12),
                        if (createdAt != null)
                          Text('Tarih: ${DateFormat("dd.MM.yyyy HH:mm").format(createdAt)}',
                              style: const TextStyle(fontSize: 12, color: _textSecondary)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (roomId.isNotEmpty)
                              Expanded(
                                child: _DarkButton(
                                  label: 'Sohbeti İncele',
                                  color: _accent,
                                  icon: LucideIcons.messageSquare,
                                  onTap: () => context.push('/chat/$roomId'),
                                ),
                              ),
                            if (status == 'open') ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _DarkButton(
                                  label: 'Çözüldü',
                                  color: _green,
                                  icon: LucideIcons.checkCircle,
                                  onTap: () async {
                                    await FirebaseFirestore.instance.collection('disputes').doc(doc.id).update({'status': 'closed'});
                                    if (roomId.isNotEmpty) {
                                      await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).update({'status': 'chatting'});
                                      await FirebaseFirestore.instance
                                          .collection('chat_rooms')
                                          .doc(roomId)
                                          .collection('messages')
                                          .add({
                                        'content': '✅ Moderatör itirazı inceledi ve çözüme kavuşturdu.',
                                        'type': 'system_info',
                                        'created_at': FieldValue.serverTimestamp(),
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Users Tab ───────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _DarkLoader();

        final users = snapshot.data!.docs;
        if (users.isEmpty) return _DarkEmpty(icon: LucideIcons.users, message: 'Kullanıcı bulunamadı', color: _textSecondary);

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = users[index];
            final data = doc.data() as Map<String, dynamic>;
            final uid = doc.id;
            final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
            final email = data['studentEmail'] ?? 'Email yok';
            final isAdmin = data['isAdmin'] == true;
            final isBanned = data['isBanned'] == true;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isBanned ? _red.withOpacity(0.3) : _border),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    userId: uid,
                    displayName: name.isEmpty ? 'İsimsiz' : name,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name.isEmpty ? 'İsimsiz' : name,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                            if (isAdmin) ...[
                              const SizedBox(width: 6),
                              _Badge(label: 'ADMIN', color: _accent),
                            ],
                            if (isBanned) ...[
                              const SizedBox(width: 6),
                              _Badge(label: 'BANLANDI', color: _red),
                            ],
                          ],
                        ),
                        Text(email, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ban / Unban
                      IconButton(
                        icon: Icon(
                          isBanned ? LucideIcons.userCheck : LucideIcons.ban,
                          color: isBanned ? _green : _amber,
                          size: 18,
                        ),
                        tooltip: isBanned ? 'Banı Kaldır' : 'Banla',
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('users').doc(uid).update({'isBanned': !isBanned});
                        },
                      ),
                      // Delete
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, color: _red, size: 18),
                        tooltip: 'Kullanıcıyı Sil',
                        onPressed: () async {
                          final confirm = await _confirmDialog(context, 'Kullanıcıyı Sil',
                              '$name kullanıcısını kalıcı olarak silmek istiyor musunuz?');
                          if (confirm == true) {
                            await FirebaseFirestore.instance.collection('users').doc(uid).delete();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Gigs Tab ─────────────────────────────────────────────────────────────

class _GigsTab extends StatefulWidget {
  const _GigsTab();

  @override
  State<_GigsTab> createState() => _GigsTabState();
}

class _GigsTabState extends State<_GigsTab> {
  String _collection = 'services';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _TabChip(
                label: 'Hizmetler',
                isActive: _collection == 'services',
                onTap: () => setState(() => _collection = 'services'),
              ),
              const SizedBox(width: 10),
              _TabChip(
                label: 'Görevler',
                isActive: _collection == 'bounties',
                onTap: () => setState(() => _collection = 'bounties'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(_collection).orderBy('created_at', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const _DarkLoader();
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _DarkEmpty(icon: LucideIcons.layers, message: 'İlan bulunamadı', color: _textSecondary);
              }

              final docs = snapshot.data!.docs;
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>? ?? {};
                  final id = docs[index].id;
                  final title = data['title'] ?? 'Başlıksız';
                  final creatorName = data['creator_name'] ?? 'Öğrenci';
                  final price = data['price'] ?? 0;
                  final priceType = data['price_type'] ?? 'token';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(LucideIcons.briefcase, color: _accent, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                              Text('$creatorName • $price ${priceType == 'swap' ? 'ZK' : 'CGT'}',
                                  style: const TextStyle(color: _textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, color: _red, size: 18),
                          onPressed: () async {
                            final confirm = await _confirmDialog(context, 'İlanı Sil', '"$title" ilanını kalıcı olarak silmek istiyor musunuz?');
                            if (confirm == true) {
                              await FirebaseFirestore.instance.collection(_collection).doc(id).delete();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Shared Helpers ──────────────────────────────────────────────────────

Future<bool?> _confirmDialog(BuildContext context, String title, String content) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
      content: Text(content, style: const TextStyle(color: _textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: _textSecondary))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla', style: TextStyle(color: _red))),
      ],
    ),
  );
}

class _DarkLoader extends StatelessWidget {
  const _DarkLoader();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: _accent));
}

class _DarkEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _DarkEmpty({required this.icon, required this.message, required this.color});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: _textSecondary, fontSize: 16)),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
      );
}

class _DarkButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _DarkButton({required this.label, required this.color, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _accent : _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? _accent : _border),
          ),
          child: Text(label, style: TextStyle(color: isActive ? Colors.white : _textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      );
}
