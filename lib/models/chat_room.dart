import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String gigId;
  final String gigTitle;
  final String? gigType; // 'services' or 'bounties'
  final int? roleVersion; // 2 => seller always earner, buyer always payer
  final String sellerId;
  final String sellerName;
  final String buyerId;
  final String buyerName;
  final List<String> participants;
  final List<String> unreadBy;
  final String
      status; // 'chatting', 'waiting_approval', 'escrow_locked', 'completed', 'disputed'
  final dynamic lastMessage;
  final DateTime? lastMessageAt;
  final String? sessionServiceType; // 'live_lesson', 'file_report'
  final String? sessionPin;
  final String?
      sessionStatus; // 'awaiting_pin', 'pin_verified', 'in_progress', 'ended_waiting_release'
  final String? sessionMeetingLink;
  final Timestamp? sessionStartedAt;
  final Timestamp? paymentReleaseRequestedAt;
  final Timestamp? autoReleaseAt;
  final String? reportTitle;
  final String? reportDescription;
  final String? reportFileUrl;

  ChatRoom({
    required this.id,
    required this.gigId,
    required this.gigTitle,
    this.gigType,
    this.roleVersion,
    required this.sellerId,
    required this.sellerName,
    required this.buyerId,
    required this.buyerName,
    required this.participants,
    required this.unreadBy,
    required this.status,
    this.lastMessage,
    this.lastMessageAt,
    this.sessionServiceType,
    this.sessionPin,
    this.sessionStatus,
    this.sessionMeetingLink,
    this.sessionStartedAt,
    this.paymentReleaseRequestedAt,
    this.autoReleaseAt,
    this.reportTitle,
    this.reportDescription,
    this.reportFileUrl,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      gigId: data['gig_id'] ?? '',
      gigTitle: data['gig_title'] ?? '',
      gigType: data['gig_type'],
      roleVersion: (data['role_version'] as num?)?.toInt(),
      sellerId: data['seller_id'] ?? '',
      sellerName: data['seller_name'] ?? '',
      buyerId: data['buyer_id'] ?? '',
      buyerName: data['buyer_name'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      unreadBy: List<String>.from(data['unread_by'] ?? []),
      status: data['status'] ?? 'chatting',
      lastMessage: data['last_message'],
      lastMessageAt: (data['last_message_at'] as Timestamp?)?.toDate(),
      sessionServiceType: data['session_service_type'],
      sessionPin: data['session_pin'],
      sessionStatus: data['session_status'],
      sessionMeetingLink: data['session_meeting_link'],
      sessionStartedAt: data['session_started_at'] as Timestamp?,
      paymentReleaseRequestedAt:
          data['payment_release_requested_at'] as Timestamp?,
      autoReleaseAt: data['auto_release_at'] as Timestamp?,
      reportTitle: data['report_title'],
      reportDescription: data['report_description'],
      reportFileUrl: data['report_file_url'],
    );
  }
}
