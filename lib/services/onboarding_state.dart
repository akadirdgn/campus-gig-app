import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  static const String _seenKey = 'onboarding_seen';
  static bool hasSeen = false;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    hasSeen = prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    hasSeen = true;
  }
}
