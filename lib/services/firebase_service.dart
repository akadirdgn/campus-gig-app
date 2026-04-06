import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  static const FirebaseOptions _firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyCgNobdNOWrvCzn2acfQGFph-EL5UXiOd8",
    authDomain: "campusgig-da185.firebaseapp.com",
    projectId: "campusgig-da185",
    storageBucket: "campusgig-da185.firebasestorage.app",
    messagingSenderId: "309528319407",
    appId: "1:309528319407:web:56c0237e359ddcd2368b5a",
  );

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: _firebaseOptions,
    );
  }
}
