import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _isLoading = false;

  Future<void> _claimDailyReward(String uid, DateTime? lastRewardDate) async {
    if (lastRewardDate != null && DateTime.now().difference(lastRewardDate).inHours < 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bugünkü ödülünüzü zaten aldınız! Yarın tekrar gelin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final snapshot = await transaction.get(docRef);

        final currentCgt = (snapshot.data()?['wallet_cgt'] ?? 0).toInt();
        final currentTimeCredit = (snapshot.data()?['wallet_time_credit'] ?? 0).toInt();

        transaction.update(docRef, {
          'wallet_cgt': currentCgt + 20,
          'wallet_time_credit': currentTimeCredit + 1,
          'last_daily_reward_date': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('🎉 Harika!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24), textAlign: TextAlign.center),
            content: const Text(
              '+20 CGT ve +1 ZK (Zaman Kredisi) cüzdanınıza eklendi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () => Navigator.pop(context),
                child: const Text('Teşekkürler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _buyTokens(String uid, int amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
    );

    await Future.delayed(const Duration(seconds: 2)); // Mock payment processing

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final snapshot = await transaction.get(docRef);

        final currentCgt = (snapshot.data()?['wallet_cgt'] ?? 0).toInt();
        transaction.update(docRef, {'wallet_cgt': currentCgt + amount});
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+$amount CGT başarıyla satın alındı ve cüzdanınıza eklendi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bakiye yüklenemedi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Giriş yapın')));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Cüzdanım', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Blobs
          Positioned(
            top: -100,
            left: -50,
            child: Pulse(
              infinite: true,
              duration: const Duration(seconds: 4),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }

                final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final cgt = (data['wallet_cgt'] ?? 0).toInt();
                final timeCredit = (data['wallet_time_credit'] ?? 0).toInt();
                
                DateTime? lastReward;
                if (data['last_daily_reward_date'] != null) {
                  lastReward = (data['last_daily_reward_date'] as Timestamp).toDate();
                }

                final canClaimReward = lastReward == null || DateTime.now().difference(lastReward).inHours >= 24;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DIGITAL CARD
                      FadeInDown(
                        child: Container(
                          width: double.infinity,
                          height: 220,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -20,
                                top: -20,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CAMPUSGIG BAKİYESİ', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                  const Spacer(),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text('$cgt', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2)),
                                      const SizedBox(width: 8),
                                      Text('CGT', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.timer, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Text('$timeCredit Zaman Kredisi (ZK)', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // REWARD SECTION
                      FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        child: GestureDetector(
                          onTap: (canClaimReward && !_isLoading) ? () => _claimDailyReward(user.uid, lastReward) : null,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: canClaimReward ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: canClaimReward ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.withOpacity(0.1), width: 2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: canClaimReward ? AppTheme.primaryColor : Colors.grey, shape: BoxShape.circle),
                                  child: const Icon(LucideIcons.gift, color: Colors.white),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Günlük Sürpriz Ödül', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: canClaimReward ? Colors.black87 : Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text(
                                        canClaimReward ? 'Hemen tıkla ve bugünün hediyesini topla!' : 'Bugünkü ödülü aldın. Yarın görüşürüz!', 
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[600])
                                      ),
                                    ],
                                  ),
                                ),
                                if (canClaimReward)
                                  const Icon(LucideIcons.chevronRight, color: AppTheme.primaryColor)
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // PURCHASING TOKENS
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: const Text('Bakiye Yükle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        child: Row(
                          children: [
                            _buildPurchaseCard(user.uid, 50, '49.99 ₺', Colors.blue),
                            const SizedBox(width: 16),
                            _buildPurchaseCard(user.uid, 100, '89.99 ₺', Colors.orange),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: Row(
                          children: [
                            _buildPurchaseCard(user.uid, 250, '199.99 ₺', Colors.purple),
                            const SizedBox(width: 16),
                            _buildPurchaseCard(user.uid, 500, '349.99 ₺', AppTheme.primaryColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(String uid, int amount, String price, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _buyTokens(uid, amount),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(LucideIcons.coins, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text('$amount CGT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
