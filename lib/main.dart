import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campusgig/services/firebase_service.dart';
import 'package:campusgig/services/onboarding_state.dart';
import 'package:campusgig/theme/app_theme.dart';
import 'package:campusgig/routing/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await OnboardingState.load();

  runApp(
    const ProviderScope(
      child: CampusGigApp(),
    ),
  );
}

class CampusGigApp extends ConsumerWidget {
  const CampusGigApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CampusGig',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
