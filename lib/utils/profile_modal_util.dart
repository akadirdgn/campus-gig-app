import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:campusgig/widgets/user_avatar.dart';

class ProfileModalUtil {
  static void show(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }

              final data = snapshot.data?.data() as Map<String, dynamic>?;
              
              final firstName = (data?['firstName'] ?? '').toString().trim();
              final lastName = (data?['lastName'] ?? '').toString().trim();
              final dispName = (data?['displayName'] ?? '').toString().trim();
              
              String displayName = 'Kullanıcı';
              if (firstName.isNotEmpty || lastName.isNotEmpty) {
                displayName = '$firstName $lastName'.trim();
              } else if (dispName.isNotEmpty && dispName != 'Öğrenci') {
                displayName = dispName;
              }

              final university = data?['university']?.toString().toUpperCase() ?? 'KAMPÜS ÖĞRENCİSİ';
              final department = data?['department'] ?? 'BELİRTİLMEMİŞ';
              final ratingStr = data?['rating']?.toString() ?? 'Yeni';
              final completedGigsStr = data?['completed_gigs']?.toString() ?? '0';
              final responseTimeStr = data?['response_time']?.toString() ?? 'Hızlı';

              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.grey, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: UserAvatar(
                      userId: userId,
                      displayName: displayName,
                      radius: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            displayName, 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.badgeCheck, color: AppTheme.primaryColor, size: 24),
                      ],
                    ),
                  ),
                  Center(
                    child: Text('$university • $department', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildProfileStatCard('Puan', '⭐ $ratingStr', Colors.orange),
                      _buildProfileStatCard('Tamamlanan', '🎉 $completedGigsStr', AppTheme.primaryColor),
                      _buildProfileStatCard('Yanıt', '⚡ $responseTimeStr', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.shieldAlert, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Güvenliğiniz için işlemleri yalnızca CampusApp platformu üzerinden gerçekleştirin.',
                            style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _buildProfileStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
