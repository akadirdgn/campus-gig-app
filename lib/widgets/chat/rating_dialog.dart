import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:campusgig/theme/app_theme.dart';

class RatingDialog extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String roomId;
  final String currentUserName;

  const RatingDialog({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.roomId,
    required this.currentUserName,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 5;
  bool _isLoading = false;

  void _submitRating() async {
    setState(() => _isLoading = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.targetUserId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(userRef);
        final data = doc.data() ?? {};
        final currentRating = (data['rating'] ?? 0.0).toDouble();
        final currentCount = (data['rating_count'] ?? 0).toInt();

        final newCount = currentCount + 1;
        final newRating = ((currentRating * currentCount) + _rating) / newCount;

        transaction.update(userRef, {
          'rating': double.parse(newRating.toStringAsFixed(1)),
          'rating_count': newCount,
        });
      });
      
      // Sohbete sistem mesajı olarak değerlendirmeyi düşün
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'content': '${widget.currentUserName}, ${widget.targetUserName} ile olan çalışmasını değerlendirdi: ⭐ $_rating/5',
        'type': 'system_info',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Değerlendirme gönderildi!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.star, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              '${widget.targetUserName} ile çalışmanız nasıldı?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _rating ? LucideIcons.star : LucideIcons.star,
                      size: 32,
                      color: index < _rating ? Colors.orange : Colors.grey[300],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('DEĞERLENDİR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
