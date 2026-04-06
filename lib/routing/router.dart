import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campusgig/screens/home_screen.dart';
import 'package:campusgig/screens/login_screen.dart';
import 'package:campusgig/screens/register_screen.dart';
import 'package:campusgig/screens/chat_screen.dart';
import 'package:campusgig/screens/messages_screen.dart';
import 'package:campusgig/screens/profile_screen.dart';
import 'package:campusgig/screens/create_gig_screen.dart';
import 'package:campusgig/screens/gig_detail_screen.dart';
import 'package:campusgig/screens/my_gigs_screen.dart';
import 'package:campusgig/models/gig.dart';
import 'package:campusgig/widgets/scaffold_with_nav.dart';
import 'package:campusgig/screens/admin_panel_screen.dart';
import 'package:campusgig/screens/wallet_screen.dart';
import 'package:campusgig/screens/onboarding_screen.dart';
import 'package:campusgig/services/onboarding_state.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Stream<User?> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthStateListenable(
    FirebaseAuth.instance.authStateChanges(),
  );
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final hasSeenOnboarding = OnboardingState.hasSeen;
      final isOnboardingRoute = state.matchedLocation == '/onboarding';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Onboarding tamamlanmadan auth guard calismasin.
      if (!hasSeenOnboarding) {
        if (!isOnboardingRoute) {
          return '/onboarding';
        }
        return null;
      }

      if (isOnboardingRoute) {
        return isLoggedIn ? '/' : '/login';
      }

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => const MessagesScreen(),
          ),
          GoRoute(
            path: '/create-gig',
            builder: (context, state) => const CreateGigScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/my-gigs',
        builder: (context, state) => const MyGigsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/chat/:roomId',
        builder: (context, state) => ChatScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/gig-detail',
        builder: (context, state) {
          final gig = state.extra;
          // In real app we might want to fetch by ID if extra is null,
          // but for this UI enhancement we rely on passing the extra Object.
          // importing 'package:campusgig/models/gig.dart' is needed. Let's add it below block, wait no, this whole block is replaced.
          return gig is Gig
              ? GigDetailScreen(gig: gig)
              : const Scaffold(body: Center(child: Text('Gig Bulunamadı')));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin',
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
    ],
  );
});
