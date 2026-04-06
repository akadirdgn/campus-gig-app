import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:campusgig/models/chat_room.dart';
import 'package:campusgig/models/message.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:campusgig/utils/chat_security_util.dart';
import 'package:campusgig/widgets/chat/message_bubble.dart';
import 'package:campusgig/widgets/chat/dispute_bottom_sheet.dart';
import 'package:campusgig/widgets/chat/rating_dialog.dart';
import 'package:campusgig/utils/profile_modal_util.dart';
import 'package:campusgig/widgets/user_avatar.dart';

enum _BannerVariant {
  paymentPending,
  pinRequired,
  lessonActive,
  dispute,
}

class _BannerData {
  final String key;
  final _BannerVariant variant;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showApprovalActions;

  const _BannerData({
    required this.key,
    required this.variant,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showApprovalActions = false,
  });
}

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final user = FirebaseAuth.instance.currentUser;
  Timer? _ticker;
  bool _isAutoReleaseInProgress = false;
  bool _isMigratingRoleMetadata = false;
  String? _dismissedBannerKey;

  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    _pinController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatRoom>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .snapshots()
          .map((doc) => ChatRoom.fromFirestore(doc)),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));

        final room = snapshot.data!;
        final otherId = room.participants.firstWhere((id) => id != user?.uid);
        final otherName =
            room.sellerId == otherId ? room.sellerName : room.buyerName;
        final isSeller = room.sellerId == user?.uid;
        final isMarketplace = room.gigType != 'bounties';
        final accent =
            isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
        final accentSecondary =
            isMarketplace ? const Color(0xFF1E9D4B) : const Color(0xFF8B5CF6);
        final bannerData = _buildBannerData(room, isSeller);
        final showBanner =
            bannerData != null && _dismissedBannerKey != bannerData.key;

        _maybeMigrateLegacyRoles(room);
        _maybeHandleAutoRelease(room);

        // Okunmadıysa (unread_by içinde varsa) kendini listeden çıkararak okundu işaretle
        if (room.unreadBy.contains(user?.uid)) {
          FirebaseFirestore.instance
              .collection('chat_rooms')
              .doc(widget.roomId)
              .update({
            'unread_by': FieldValue.arrayRemove([user?.uid])
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF080D17),
          appBar:
              _buildAppBar(context, otherId, otherName, room.gigTitle, room),
          body: Stack(
            children: [
              Positioned(
                top: -90,
                left: -60,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                right: -70,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: accentSecondary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: const SizedBox(),
                ),
              ),
              Column(
                children: [
                  Expanded(child: _buildMessageList(room)),
                  _buildQuickActions(room),
                  _buildInputArea(room, otherId),
                ],
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(animation);
                    return SlideTransition(
                      position: slide,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: !showBanner
                      ? const SizedBox(key: ValueKey('banner-hidden'))
                      : _ChatTopNotificationBanner(
                          key: ValueKey(bannerData.key),
                          data: bannerData,
                          isBuyer: !isSeller,
                          onDismissed: () {
                            setState(() {
                              _dismissedBannerKey = bannerData.key;
                            });
                          },
                          onApprove: bannerData.showApprovalActions
                              ? () async {
                                  await _approveOffer(room);
                                  if (!mounted) return;
                                  setState(() => _dismissedBannerKey = null);
                                }
                              : null,
                          onReject: bannerData.showApprovalActions
                              ? () async {
                                  await _rejectOffer(room);
                                  if (!mounted) return;
                                  setState(() => _dismissedBannerKey = null);
                                }
                              : null,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String otherId,
      String otherName, String gigTitle, ChatRoom room) {
    final isMarketplace = room.gigType != 'bounties';
    final accent =
        isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
    return AppBar(
      backgroundColor: const Color(0x22000000),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: Color(0xFFE5E7EB)),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => ProfileModalUtil.show(context, otherId),
        child: Row(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherId)
                  .snapshots(),
              builder: (context, snapshot) {
                // Resolve the display name from Firestore, fall back to ChatRoom value
                String resolvedName = (otherName == 'Öğrenci' || otherName.isEmpty) ? 'Kullanıcı' : otherName;
                if (snapshot.hasData && snapshot.data?.data() != null) {
                  final data =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final fName =
                      (data['firstName'] ?? '').toString().trim();
                  final lName =
                      (data['lastName'] ?? '').toString().trim();
                  if (fName.isNotEmpty || lName.isNotEmpty) {
                    resolvedName = '$fName $lName'.trim();
                  } else {
                    final dName = (data['displayName'] ?? '').toString().trim();
                    if (dName.isNotEmpty && dName != 'Öğrenci') {
                      resolvedName = dName;
                    }
                  }
                }

                return Row(
                  children: [
                    UserAvatar(
                      userId: otherId,
                      displayName: resolvedName,
                      radius: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                resolvedName.isNotEmpty
                                    ? resolvedName
                                    : 'Kullanıcı',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFE5E7EB)),
                              ),
                              const SizedBox(width: 6),
                              Icon(LucideIcons.badgeCheck,
                                  size: 14, color: accent),
                            ],
                          ),
                          Text(
                            gigTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accent.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const Icon(LucideIcons.chevronDown,
                size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
      actions: [
        IconButton(
            icon: const Icon(LucideIcons.moreHorizontal,
                color: Color(0xFF9CA3AF)),
            onPressed: () => _showChatMenu(context, room, otherId)),
      ],
    );
  }

  void _showChatMenu(BuildContext context, ChatRoom room, String otherId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5)),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child:
                      const Icon(LucideIcons.flag, color: Colors.red, size: 20),
                ),
                title: const Text('Kullanıcıyı Şikayet Et',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
                subtitle: const Text('Uygunsuz davranış veya içerik bildirimi',
                    style: TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final currentUser = user;
                    await FirebaseFirestore.instance.collection('reports').add({
                      'reported_user_id': otherId,
                      'reported_user_name': room.sellerId == otherId
                          ? room.sellerName
                          : room.buyerName,
                      'reporter_id': currentUser?.uid ?? '',
                      'room_id': widget.roomId,
                      'reason': 'Uygunsuz davranış veya içerik',
                      'status': 'open',
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Şikayet iletildi. Yöneticiler tarafından incelenecek.')));
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                },
              ),
              if (room.status == 'chatting') ...[
                const Divider(height: 1, indent: 70),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: const Icon(LucideIcons.ban,
                        color: Colors.orange, size: 20),
                  ),
                  title: const Text('Görüşmeyi İptal Et',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange)),
                  subtitle: const Text('Bu görev anlaşmasını sonlandır',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Görüşme iptal edildi.')));
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _BannerData? _buildBannerData(ChatRoom room, bool isSeller) {
    if (room.status == 'offer_pending') {
      return _BannerData(
        key: 'offer_pending',
        variant: _BannerVariant.paymentPending,
        icon: LucideIcons.clock3,
        title: 'Ödeme Onayı Bekleniyor',
        subtitle: isSeller
            ? 'Alıcının teklifi onaylaması bekleniyor.'
            : 'Onaylarsanız ödemeniz güvenli havuza alınır.',
        showApprovalActions: !isSeller,
      );
    }

    if (room.status == 'escrow_locked' &&
        room.sessionStatus == 'awaiting_pin') {
      return _BannerData(
        key: 'awaiting_pin_${room.sessionPin ?? ''}',
        variant: _BannerVariant.pinRequired,
        icon: LucideIcons.keyRound,
        title: 'PIN Kodu Geldi',
        subtitle: isSeller
            ? 'Alıcıdan aldığınız PIN kodunu kutucuğa girin.'
            : 'PIN kodunuzu sağlayıcı ile paylaşmanız bekleniyor.',
      );
    }

    if (room.sessionServiceType == 'live_lesson' &&
        room.sessionStatus == 'in_progress' &&
        room.sessionStartedAt != null) {
      final elapsed = _formatDuration(
        DateTime.now().difference(room.sessionStartedAt!.toDate()),
      );
      return _BannerData(
        key: 'live_lesson_${room.sessionStartedAt!.millisecondsSinceEpoch}',
        variant: _BannerVariant.lessonActive,
        icon: LucideIcons.radio,
        title: 'Canlı Ders Aktif',
        subtitle: 'Ders süresi: $elapsed',
      );
    }

    if (room.status == 'disputed') {
      return const _BannerData(
        key: 'disputed',
        variant: _BannerVariant.dispute,
        icon: LucideIcons.alertTriangle,
        title: 'İtiraz Kaydı Açıldı',
        subtitle: 'İşlem durduruldu. Admin incelemesi bekleniyor.',
      );
    }

    if (room.status == 'waiting_payment_release') {
      return _BannerData(
        key: 'waiting_payment_release',
        variant: _BannerVariant.paymentPending,
        icon: LucideIcons.hourglass,
        title: 'Ödeme Aktarım Kararı Bekleniyor',
        subtitle: isSeller
            ? 'Alıcının para aktarımı veya itiraz aksiyonu bekleniyor.'
            : 'Parayı aktarabilir veya itiraz oluşturabilirsiniz.',
      );
    }

    return null;
  }

  Widget _buildMessageList(ChatRoom room) {
    return StreamBuilder<List<Message>>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('created_at', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final messages = snapshot.data!;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final m = messages[index];
            final isMe = m.senderId == user?.uid;

            if (m.type == 'system_info') return _buildSystemMessage(m, room);
            return MessageBubble(
              message: m,
              isMe: isMe,
              accentColor: room.gigType == 'bounties'
                  ? const Color(0xFF4CC9FF)
                  : const Color(0xFF7CFF6B),
              secondaryAccent: room.gigType == 'bounties'
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF1E9D4B),
              useDarkTheme: true,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedMessageIds.contains(m.id),
              onSelectionToggled: () {
                if (_isSelectionMode) {
                  setState(() {
                    if (_selectedMessageIds.contains(m.id)) {
                      _selectedMessageIds.remove(m.id);
                      if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
                    } else {
                      _selectedMessageIds.add(m.id);
                    }
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBubble(Message m, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(isMe ? 24 : 8),
            bottomRight: Radius.circular(isMe ? 8 : 24),
          ),
          boxShadow: [
            BoxShadow(
              color: (isMe ? AppTheme.primaryColor : Colors.black)
                  .withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.content,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1E293B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            if (m.createdAt != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(m.createdAt!),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[400],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(LucideIcons.checkCheck,
                        size: 12, color: Colors.white.withOpacity(0.8)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessageContent(String content) {
    final linkMatch = RegExp(r'\[LESSON_LINK\](.*?)\[\/LESSON_LINK\]').firstMatch(content);
    
    if (linkMatch == null) {
      return Text(
        content,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE5E7EB),
            height: 1.4),
      );
    }

    final link = linkMatch.group(1) ?? '';
    final textBefore = content.substring(0, linkMatch.start).trim();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (textBefore.isNotEmpty)
          Text(
            textBefore,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E7EB),
                height: 1.4),
          ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final url = Uri.tryParse(link);
            if (url != null && await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: const Text(
            '🔗 Kayıtlı Ders Bağlantısını Aç',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF38BDF8),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemMessage(Message m, ChatRoom room) {
    final isMarketplace = room.gigType != 'bounties';
    final accent =
        isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: const Color(0x11FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.info, size: 16, color: accent),
            const SizedBox(width: 10),
            Flexible(
              child: _buildSystemMessageContent(m.content),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ChatRoom room) {
    final isSeller = room.sellerId == user?.uid;
    final isMarketplace = room.gigType != 'bounties';
    final accent =
        isMarketplace ? const Color(0xFF7CFF6B) : const Color(0xFF4CC9FF);
    final accentSecondary =
        isMarketplace ? const Color(0xFF1E9D4B) : const Color(0xFF8B5CF6);
    final buttons = <Widget>[];

    if (room.status == 'chatting') {
      if (isSeller) {
        buttons.add(
            _actionButton('Teklif Gönder', accent, () => _sendOffer(room)));
      } else {
        buttons.add(_actionButton(
            'Sağlayıcı teklifini bekleyin', Colors.grey, () {},
            disabled: true));
      }
    } else if (room.status == 'offer_pending') {
      if (isSeller) {
        buttons.add(_actionButton('Alıcı onayı bekleniyor', Colors.grey, () {},
            disabled: true));
      } else {
        buttons.add(_actionButton('Onayla', accent, () => _approveOffer(room)));
        buttons.add(const SizedBox(width: 8));
        buttons
            .add(_actionButton('Reddet', Colors.red, () => _rejectOffer(room)));
      }
    } else if (room.status == 'escrow_locked' &&
        room.sessionStatus == 'awaiting_pin') {
      if (isSeller) {
        return _pinVerificationPanel();
      }
      return _buyerPinPanel(room.sessionPin);
    } else if (room.status == 'escrow_locked' &&
        room.sessionStatus == 'pin_verified') {
      if (isSeller) {
        buttons.add(_actionButton('Canlı Ders Başlat', Colors.indigo,
            () => _selectServiceType(room, 'live_lesson')));
      } else {
        buttons.add(_actionButton(
            'Sağlayıcının dersi başlatması bekleniyor', Colors.grey, () {},
            disabled: true));
      }
    } else if (room.status == 'escrow_locked' &&
        room.sessionServiceType == 'live_lesson') {
      if (room.sessionStatus == 'in_progress') {
        if (isSeller) {
          buttons.add(_actionButton(
              'Dersi Bitir', Colors.green, () => _finishLiveLesson(room)));
        } else {
          buttons.add(_actionButton(
              'Canlı ders devam ediyor', Colors.grey, () {},
              disabled: true));
        }
      } else if (isSeller) {
        buttons.add(_actionButton(
            'Ders Linki Oluştur', accent, () => _showLiveLessonOptions(room)));
      } else {
        buttons.add(_actionButton('Ders linki hazırlanıyor', Colors.grey, () {},
            disabled: true));
      }
    } else if (room.status == 'escrow_locked' &&
        room.sessionServiceType == 'file_report') {
      if (isSeller) {
        buttons.add(_actionButton('Dosya/Rapor Teslim Ettim', accent,
            () => _completeFileService(room)));
      } else {
        buttons.add(_actionButton('Teslimat bekleniyor', Colors.grey, () {},
            disabled: true));
      }
    } else if (room.status == 'waiting_payment_release') {
      if (!isSeller) {
        if (room.sessionServiceType == 'file_report') {
          buttons.add(_actionButton(
            'Raporu Görüntüle',
            accent,
            () => _showReportReviewDialog(room),
          ));
          buttons.add(const SizedBox(width: 8));
        }
        buttons.add(_actionButton('Parayı Aktar', accent,
            () => _releasePayment(room, isAuto: false)));
        buttons.add(const SizedBox(width: 8));
        buttons.add(_actionButton('İtiraz Et', Colors.red, () {
          setState(() {
            _isSelectionMode = true;
            _selectedMessageIds.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Kanıt olarak sunmak istediğiniz mesajları seçin.')));
        }));
      } else {
        buttons.add(_actionButton(
            'Alıcı ödeme kararı bekleniyor', Colors.grey, () {},
            disabled: true));
      }
    }

    if (buttons.isEmpty) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: buttons),
      ),
    );
  }

  Widget _pinVerificationPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Color(0xFFE5E7EB)),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Alıcı PIN kodu',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: AppTheme.homeAccent.withOpacity(0.7)),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _actionButton('PIN Doğrula', AppTheme.homeAccent, () => _verifyPin(),
              compact: true),
        ],
      ),
    );
  }

  Widget _buyerPinPanel(String? pin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PIN doğrulama aşaması aktif',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFFE5E7EB))),
          const SizedBox(height: 4),
          const Text(
              'Bu kodu sağlayıcı ile paylaşın. Kod doğrulanınca işlem resmi olarak başlayacaktır.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.homeAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('PIN: ${pin ?? '----'}',
                style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 6,
                    color: Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String text, Color color, VoidCallback onTap,
      {bool disabled = false, bool compact = false}) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16, vertical: compact ? 11 : 10),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.withOpacity(0.12)
              : color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: disabled ? Colors.transparent : color.withOpacity(0.35)),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: disabled ? Colors.grey : color,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Future<void> _sendOffer(ChatRoom room) async {
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .update({
      'status': 'offer_pending',
      'session_status': null,
      'session_service_type': null,
      'session_pin': null,
      'session_meeting_link': null,
      'session_started_at': null,
      'payment_release_requested_at': null,
      'auto_release_at': null,
    });
    await _pushSystemMessage(
        'Görevi başlatmak için onayınız bekleniyor. Onayladığınız takdirde ödemeniz güvenli havuz hesabına alınacaktır.');
  }

  Future<void> _rejectOffer(ChatRoom room) async {
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .update({
      'status': 'chatting',
      'session_status': null,
      'session_service_type': null,
      'session_pin': null,
      'session_meeting_link': null,
      'session_started_at': null,
      'payment_release_requested_at': null,
      'auto_release_at': null,
    });
    await _pushSystemMessage(
        'Alıcı teklifi reddetti. Sohbet aşamasına geri dönüldü.');
  }

  Future<void> _approveOffer(ChatRoom room) async {
    try {
      await _ensureBuyerHasBalance(room);
      final pin = (1000 + Random().nextInt(9000)).toString();
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .update({
        'status': 'escrow_locked',
        'session_status': 'awaiting_pin',
        'session_pin': pin,
        'session_service_type': null,
        'session_meeting_link': null,
        'session_started_at': null,
        'payment_release_requested_at': null,
        'auto_release_at': null,
      });
      await _pushSystemMessage(
          'Alıcı teklifi onayladı. Ödeme güvenli havuza alındı. PIN doğrulaması bekleniyor.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _verifyPin() async {
    final enteredPin = _pinController.text.trim();
    if (enteredPin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen 4 haneli PIN girin.')));
      return;
    }

    final roomDoc = await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .get();
    final room = ChatRoom.fromFirestore(roomDoc);
    if (room.sessionPin != enteredPin) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN eşleşmedi. Tekrar deneyin.')));
      return;
    }

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .update({
      'session_status': 'pin_verified',
    });
    _pinController.clear();
    await _pushSystemMessage(
        'PIN doğrulandı. İşlem resmi olarak başladı. Sağlayıcı dersi başlatabilir.');
  }

  Future<void> _selectServiceType(ChatRoom room, String serviceType) async {
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .update({
      'session_service_type': serviceType,
      'session_status':

          serviceType == 'live_lesson' ? 'pin_verified' : 'in_progress',
    });

    if (serviceType == 'live_lesson') {
      await _pushSystemMessage(
          'Sağlayıcı hizmet türü olarak Canlı Ders seçti. Ders bağlantısı hazırlanıyor.');
      if (mounted) {
        await _showLiveLessonOptions(room);
      }
    } else {
      await _pushSystemMessage(
          'Sağlayıcı hizmet türü olarak Dosya/Rapor Hazırla seçti. Teslimat hazırlığı başladı.');
      if (mounted) {
        await _showFileReportDialog(room);
      }
    }
  }

  Future<void> _showLiveLessonOptions(ChatRoom room) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.link2),
                  title: const Text('Harici Link Gir (Zoom/Meet)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(context);
                    final externalLink = await _askForExternalMeetingLink();
                    if (externalLink != null) {
                      await _startLiveLessonWithLink(
                          room, externalLink, 'Harici ders linki paylaşıldı');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.video),
                  title: const Text('Sistem Üzerinden Jitsi Linki Oluştur',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(context);
                    final generated =
                        'https://meet.jit.si/campusgig-${widget.roomId.substring(0, min(8, widget.roomId.length))}-${DateTime.now().millisecondsSinceEpoch}';
                    await _startLiveLessonWithLink(
                        room, generated, 'Sistem Jitsi ders linki oluşturdu');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFileReportDialog(ChatRoom room) async {
    if (!mounted) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111421),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Teslimatı Onayla', 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('Bu işi şimdi teslim etmek istiyor musunuz?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14)),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç', style: TextStyle(color: Colors.white38))),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7CFF6B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // ANINDA KAPAT
                      Navigator.pop(context);
                      
                      // İŞLEMİ ARKA PLANDA HALLET
                      _completeFileServiceWithDetails(
                        room,
                        'Hızlı Teslimat',
                        'İş başarıyla tamamlandı.',
                        null,
                      ).catchError((e) => debugPrint('Hata: $e'));
                    },
                    child: const Text('Onayla ve Bitir', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReportReviewDialog(ChatRoom room) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text('Rapor Görüntüle',
            style: TextStyle(color: Color(0xFFF3F4F6))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Başlık: ${room.reportTitle ?? 'Belirtilmemiş'}',
                style: const TextStyle(color: Color(0xFFE5E7EB))),
            const SizedBox(height: 8),
            Text('Açıklama: ${room.reportDescription ?? 'Belirtilmemiş'}',
                style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
            if (room.reportFileUrl != null &&
                room.reportFileUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final url = Uri.tryParse(room.reportFileUrl!);
                  if (url != null && await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Dosya açılamıyor.')));
                    }
                  }
                },
                child: Row(
                  children: [
                    const Icon(LucideIcons.file,
                        color: Color(0xFF7CFF6B), size: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                        child: Text('Dosya: Mevcut (İndir)',
                            style: TextStyle(
                                color: Color(0xFF7CFF6B), fontSize: 12))),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Future<String?> _askForExternalMeetingLink() async {
    final linkController = TextEditingController();
    String? selected;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Harici Link Girin'),
        content: TextField(
          controller: linkController,
          decoration: const InputDecoration(
              hintText: 'https://zoom.us/... veya https://meet.google.com/...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              final value = linkController.text.trim();
              final uri = Uri.tryParse(value);
              if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir URL girin.')));
                return;
              }
              selected = value;
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    return selected;
  }

  Future<void> _startLiveLessonWithLink(
      ChatRoom room, String meetingLink, String contextMessage) async {
    final otherId = room.participants.firstWhere((id) => id != user?.uid);
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'sender_id': user?.uid,
      'sender_name': user?.displayName ?? 'Öğrenci',
      'content': '🎥 Canlı ders bağlantısı hazır',
      'type': 'zoom_call',
      'meeting_link': meetingLink,
      'created_at': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .update({
      'session_meeting_link': meetingLink,
      'session_status': 'in_progress',
      'session_started_at': FieldValue.serverTimestamp(),
      'last_message': '🎥 Canlı ders bağlantısı paylaşıldı',
      'last_message_at': FieldValue.serverTimestamp(),
      'unread_by': FieldValue.arrayUnion([otherId]),
    });
    await _pushSystemMessage(
        '$contextMessage. Link her iki tarafa iletildi ve ders sayacı başlatıldı.');
  }

  Future<void> _finishLiveLesson(ChatRoom room) async {
    final startedAt = room.sessionStartedAt?.toDate();
    final duration = startedAt == null
        ? const Duration()
        : DateTime.now().difference(startedAt);
    final formattedDuration = _formatDuration(duration);
    final lessonLink = room.sessionMeetingLink ?? 'link bulunamadı';

    // Ders linkini [LINK]url[/LINK] formatında kaydet
    final summary =
        'Ders tamamlandı. Süre: $formattedDuration\n[LESSON_LINK]$lessonLink[/LESSON_LINK]';

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .update({
      'status': 'waiting_payment_release',
      'session_status': 'ended_waiting_release',
      'payment_release_requested_at': FieldValue.serverTimestamp(),
      'auto_release_at':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
    });
    await _pushSystemMessage(summary);
  }

  Future<void> _completeFileServiceWithDetails(
    ChatRoom room,
    String reportTitle,
    String description,
    String? fileUrl,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .update({
        'status': 'waiting_payment_release',
        'session_status': 'ended_waiting_release',
        'report_title': reportTitle,
        'report_description': description,
        'report_file_url': fileUrl,
        'report_submitted_at': FieldValue.serverTimestamp(),
        'payment_release_requested_at': FieldValue.serverTimestamp(),
        'auto_release_at':
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });

      final summary = '''🚀 *İŞ TESLİMATI TAMAMLANDI*
──────────────────
📌 *Başlık:* $reportTitle
📝 *Açıklama:* $description
📎 *Dosya:* ${fileUrl != null ? '✅ Mevcut (İndirilebilir)' : '❌ Yüklenmedi'}
──────────────────
🔔 Alıcı onayı bekleniyor. 24 saat içinde otomatik onaylanır.''';

      await _pushSystemMessage(summary);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rapor başarıyla teslim edildi.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF7CFF6B),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Future<void> _completeFileService(ChatRoom room) async {
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .update({
      'status': 'waiting_payment_release',
      'session_status': 'ended_waiting_release',
      'payment_release_requested_at': FieldValue.serverTimestamp(),
      'auto_release_at':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
    });
    await _pushSystemMessage(
        'Sağlayıcı dosya/rapor teslimini tamamladı. Alıcıdan ödeme kararı bekleniyor.');
  }

  Future<void> _releasePayment(ChatRoom room, {required bool isAuto}) async {
    try {
      await _transferEscrowToSeller(room);
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .update({
        'status': 'completed',
        'session_status': 'completed',
      });
      await _pushSystemMessage(isAuto
          ? 'Alıcı 24 saat içinde işlem yapmadığı için ödeme otomatik olarak sağlayıcıya aktarıldı.'
          : 'Alıcı ödemeyi onayladı. Para sağlayıcı hesabına aktarıldı.');
      if (mounted) {
        _showRatingDialog(room);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _maybeHandleAutoRelease(ChatRoom room) async {
    if (_isAutoReleaseInProgress) return;
    if (room.status != 'waiting_payment_release') return;
    final deadline = room.autoReleaseAt;
    if (deadline == null || DateTime.now().isBefore(deadline.toDate())) return;

    _isAutoReleaseInProgress = true;
    try {
      await _releasePayment(room, isAuto: true);
    } finally {
      _isAutoReleaseInProgress = false;
    }
  }

  Future<void> _maybeMigrateLegacyRoles(ChatRoom room) async {
    if (_isMigratingRoleMetadata) return;
    if (room.roleVersion == 2 && room.gigType != null) return;

    _isMigratingRoleMetadata = true;
    try {
      final gigType = room.gigType ?? await _resolveGigType(room.gigId);
      final updates = <String, dynamic>{
        'gig_type': gigType,
        'role_version': 2,
      };

      // Legacy bounty rooms used the same mapping as marketplace.
      // Swap roles once so seller=para kazanan, buyer=para odeyen olur.
      if (gigType == 'bounties' && room.roleVersion != 2) {
        updates.addAll({
          'seller_id': room.buyerId,
          'seller_name': room.buyerName,
          'buyer_id': room.sellerId,
          'buyer_name': room.sellerName,
        });
      }

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .update(updates);
    } catch (_) {
      // Best-effort migration; user flow should continue.
    } finally {
      _isMigratingRoleMetadata = false;
    }
  }

  Future<String> _resolveGigType(String gigId) async {
    final serviceDoc = await FirebaseFirestore.instance
        .collection('services')
        .doc(gigId)
        .get();
    if (serviceDoc.exists) return 'services';
    return 'bounties';
  }

  Future<void> _pushSystemMessage(String message) async {
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'content': message,
      'type': 'system_info',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<(int, String, String)> _getGigPricing(ChatRoom room) async {
    int price = 0;
    String priceType = 'token';
    var gigDoc = await FirebaseFirestore.instance
        .collection('services')
        .doc(room.gigId)
        .get();
    if (!gigDoc.exists) {
      gigDoc = await FirebaseFirestore.instance
          .collection('bounties')
          .doc(room.gigId)
          .get();
    }
    if (gigDoc.exists) {
      price = (gigDoc.data()?['price'] ?? 0).toInt();
      priceType = gigDoc.data()?['price_type'] ?? 'token';
    }
    final walletField =
        priceType == 'swap' ? 'wallet_time_credit' : 'wallet_cgt';
    return (price, priceType, walletField);
  }

  Future<void> _ensureBuyerHasBalance(ChatRoom room) async {
    final (price, priceType, walletField) = await _getGigPricing(room);
    final buyerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(room.buyerId)
        .get();
    final currentBuyerBalance = (buyerDoc.data()?[walletField] ?? 0).toInt();
    if (currentBuyerBalance < price) {
      throw Exception(
          'Bakiyeniz yetersiz ($currentBuyerBalance < $price). Lütfen önce $priceType yükleyin.');
    }
  }

  Future<void> _transferEscrowToSeller(ChatRoom room) async {
    final (price, _, walletField) = await _getGigPricing(room);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final buyerRef =
          FirebaseFirestore.instance.collection('users').doc(room.buyerId);
      final sellerRef =
          FirebaseFirestore.instance.collection('users').doc(room.sellerId);

      final buyerDoc = await transaction.get(buyerRef);
      final sellerDoc = await transaction.get(sellerRef);

      final currentBuyerBalance = (buyerDoc.data()?[walletField] ?? 0).toInt();
      final currentSellerBalance =
          (sellerDoc.data()?[walletField] ?? 0).toInt();

      if (currentBuyerBalance < price) {
        throw Exception(
            'Alıcı bakiyesi yetersiz ($currentBuyerBalance < $price).');
      }

      transaction.update(buyerRef, {walletField: currentBuyerBalance - price});
      transaction
          .update(sellerRef, {walletField: currentSellerBalance + price});

      final currentCompleted =
          (sellerDoc.data()?['completed_gigs'] ?? 0).toInt();
      transaction.update(sellerRef, {'completed_gigs': currentCompleted + 1});
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<void> _showRatingDialog(ChatRoom room) async {
    if (user?.uid == room.buyerId) {
      String currentUserName = room.buyerName;
      String targetUserName = room.sellerName;

      Future<String> fetchRealName(String uid, String fallback) async {
        if (fallback == 'Öğrenci' || fallback == 'Kullanıcı' || fallback.isEmpty) {
          try {
            final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
            final fName = (doc.data()?['firstName'] ?? '').toString().trim();
            final lName = (doc.data()?['lastName'] ?? '').toString().trim();
            if (fName.isNotEmpty || lName.isNotEmpty) {
              return '$fName $lName'.trim();
            }
          } catch (_) {}
          return 'Kullanıcı';
        }
        return fallback;
      }

      currentUserName = await fetchRealName(room.buyerId, currentUserName);
      targetUserName = await fetchRealName(room.sellerId, targetUserName);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => RatingDialog(
          targetUserId: room.sellerId,
          targetUserName: targetUserName,
          roomId: widget.roomId,
          currentUserName: currentUserName,
        ),
      );
    }
  }

  Future<void> _pickAndSendFile(ChatRoom room, String otherId) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Web sürümünde yerel dosya işlemi desteklenmez.')));
        }
        return;
      }

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        final appDir = await getApplicationDocumentsDirectory();
        final localPath = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await file.copy(localPath);

        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.roomId)
            .collection('messages')
            .add({
          'sender_id': user?.uid,
          'sender_name': user?.displayName ?? 'Öğrenci',
          'content': '📁 $fileName',
          'type': 'file',
          'file_name': fileName,
          'file_local_path': localPath,
          'created_at': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.roomId)
            .update({
          'last_message': '📁 $fileName',
          'last_message_at': FieldValue.serverTimestamp(),
          'unread_by': FieldValue.arrayUnion([otherId]),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dosya işlemi başarısız: $e')));
      }
    }
  }

  Widget _buildInputArea(ChatRoom room, String otherId) {
    if (_isSelectionMode) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, -10))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedMessageIds.clear();
                }),
                child: const Text('İptal Et',
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _selectedMessageIds.isEmpty
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => DisputeBottomSheet(
                            room: room,
                            selectedMessageIds: _selectedMessageIds,
                            onSuccess: () => setState(() {
                              _isSelectionMode = false;
                              _selectedMessageIds.clear();
                            }),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Kanıt Sun (${_selectedMessageIds.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickAndSendFile(room, otherId),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.paperclip, size: 20, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(otherId),
                decoration: const InputDecoration(
                  hintText: 'Bir mesaj yazın...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _sendMessage(otherId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(LucideIcons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String otherId) async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();

    // Security check
    final securityResult = ChatSecurityUtil.analyzeMessage(text);
    if (securityResult.hasWarning) {
      final proceed =
          await ChatSecurityUtil.showSecurityWarning(context, securityResult);
      if (!proceed) return;
    }

    _controller.clear();

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'sender_id': user?.uid,
      'sender_name': user?.displayName ?? 'Öğrenci',
      'content': text,
      'type': 'text',
      'created_at': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .update({
      'last_message': text,
      'last_message_at': FieldValue.serverTimestamp(),
      'unread_by': FieldValue.arrayUnion([otherId]),
    });
  }
}

class _ChatTopNotificationBanner extends StatelessWidget {
  final _BannerData data;
  final bool isBuyer;
  final Future<void> Function()? onApprove;
  final Future<void> Function()? onReject;
  final VoidCallback onDismissed;

  const _ChatTopNotificationBanner({
    super.key,
    required this.data,
    required this.isBuyer,
    required this.onDismissed,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(data.variant);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -220) {
          onDismissed();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.68),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: palette.glowColor.withOpacity(0.55), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: palette.glowColor.withOpacity(0.25),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
                const BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, size: 18, color: palette.iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.showApprovalActions &&
                    isBuyer &&
                    onApprove != null &&
                    onReject != null) ...[
                  const SizedBox(width: 8),
                  _compactAction('Reddet', const Color(0xFFE11D48), onReject!),
                  const SizedBox(width: 6),
                  _compactAction('Onayla', const Color(0xFF0F766E), onApprove!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactAction(
      String text, Color color, Future<void> Function() onTap) {
    return GestureDetector(
      onTap: () async {
        await onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  _BannerPalette _paletteFor(_BannerVariant variant) {
    switch (variant) {
      case _BannerVariant.paymentPending:
        return const _BannerPalette(
          glowColor: Color(0xFFF59E0B),
          iconColor: Color(0xFF92400E),
          iconBackground: Color(0xFFFFF7ED),
        );
      case _BannerVariant.pinRequired:
        return const _BannerPalette(
          glowColor: Color(0xFF6366F1),
          iconColor: Color(0xFF3730A3),
          iconBackground: Color(0xFFEEF2FF),
        );
      case _BannerVariant.lessonActive:
        return const _BannerPalette(
          glowColor: Color(0xFF2563EB),
          iconColor: Color(0xFF1D4ED8),
          iconBackground: Color(0xFFEFF6FF),
        );
      case _BannerVariant.dispute:
        return const _BannerPalette(
          glowColor: Color(0xFFEF4444),
          iconColor: Color(0xFFB91C1C),
          iconBackground: Color(0xFFFFF1F2),
        );
    }
  }
}

class _BannerPalette {
  final Color glowColor;
  final Color iconColor;
  final Color iconBackground;

  const _BannerPalette({
    required this.glowColor,
    required this.iconColor,
    required this.iconBackground,
  });
}
