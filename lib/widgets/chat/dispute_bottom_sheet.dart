import 'package:flutter/material.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:campusgig/models/chat_room.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DisputeBottomSheet extends StatefulWidget {
  final ChatRoom room;
  final Set<String> selectedMessageIds;
  final VoidCallback onSuccess;

  const DisputeBottomSheet({
    super.key,
    required this.room,
    required this.selectedMessageIds,
    required this.onSuccess,
  });

  @override
  State<DisputeBottomSheet> createState() => _DisputeBottomSheetState();
}

class _DisputeBottomSheetState extends State<DisputeBottomSheet> {
  String? _selectedReason;
  final TextEditingController _detailController = TextEditingController();
  bool _isLoading = false;

  final List<String> _reasons = [
    'Eksik Teslimat',
    'Hatalı Çözüm / Yanlış Bilgi',
    'İletişimsizlik / Yanıt Yok',
    'Platform Dışı Yönlendirme',
    'Diğer'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Icon(LucideIcons.alertOctagon, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('İtiraz Başlat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Seçilen kanıtlar (${widget.selectedMessageIds.length} mesaj) ile birlikte itirazınız moderatörlere iletilecektir.',
            style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Reason Chips
          const Text('İtiraz Nedeni', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? Colors.red : Colors.grey.withOpacity(0.2)),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      color: isSelected ? Colors.red : Colors.black87,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Detailed Explanation
          const Text('Detaylı Açıklama (İsteğe Bağlı)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _detailController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Sorunu yetkililere detaylıca açıklayın...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8F9FB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('İptal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selectedReason == null || _isLoading ? null : _submitDispute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('İtirazı Gönder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitDispute() async {
    setState(() => _isLoading = true);

    try {
      // Create Dispute Record
      await FirebaseFirestore.instance.collection('disputes').add({
        'room_id': widget.room.id,
        'reason': _selectedReason,
        'details': _detailController.text,
        'evidence_message_ids': widget.selectedMessageIds.toList(),
        'status': 'open',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update Room Status
      await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id).update({
        'status': 'disputed',
      });

      // Add System Message
      await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id).collection('messages').add({
        'content': 'Kullanıcı bir itiraz (dispute) başlattı. İşlem askıya alındı, moderatörlerimizin incelemesi bekleniyor.',
        'type': 'system_info',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close Bottom Sheet
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
