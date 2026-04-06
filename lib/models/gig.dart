import 'package:cloud_firestore/cloud_firestore.dart';

class Gig {
  final String id;
  final String title;
  final String description;
  final dynamic price;
  final String priceType;
  final String creatorId;
  final String creatorName;
  final String university;
  final String type; // 'services' or 'bounties'
  final DateTime? createdAt;
  final bool isPremium;

  Gig({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceType,
    required this.creatorId,
    required this.creatorName,
    required this.university,
    required this.type,
    this.createdAt,
    this.isPremium = false,
  });

  factory Gig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Gig(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: data['price'],
      priceType: data['price_type'] ?? 'token',
      creatorId: data['creator_id'] ?? '',
      creatorName: data['creator_name'] ?? 'Öğrenci',
      university: data['university'] ?? '',
      type: data['type'] ?? 'services',
      isPremium: data['isPremium'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }
}
