import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final String type; // 'text', 'offer', 'system_info', 'file'
  final String? status; // 'pending', 'accepted', 'rejected'
  final DateTime? createdAt;
  final String? meetingLink;
  final String? fileName;
  final String? fileLocalPath;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.status,
    this.createdAt,
    this.meetingLink,
    this.fileName,
    this.fileLocalPath,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['sender_id'] ?? '',
      senderName: data['sender_name'] ?? '',
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      status: data['status'],
      meetingLink: data['meeting_link'],
      fileName: data['file_name'],
      fileLocalPath: data['file_local_path'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }
}
