import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campusgig/models/gig.dart';
import 'package:campusgig/theme/app_theme.dart';

class MyGigsScreen extends ConsumerWidget {
  const MyGigsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Giriş yapın')));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İlanlarım', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
          bottom: const TabBar(
            tabs: [Tab(text: 'HİZMETLERİM'), Tab(text: 'GÖREVLERİM')],
            unselectedLabelColor: Colors.grey,
            labelColor: Colors.black,
            indicatorColor: AppTheme.primaryColor,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
          ),
        ),
        body: TabBarView(
          children: [
            _buildList('services', user.uid),
            _buildList('bounties', user.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String collection, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('creator_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('İlanınız bulunmuyor'));

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['title'] ?? ''),
              subtitle: Text(data['description'] ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => FirebaseFirestore.instance.collection(collection).doc(docs[index].id).delete(),
              ),
            );
          },
        );
      },
    );
  }
}
