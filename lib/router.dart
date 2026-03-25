import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_state.dart';
import 'features/about/about_screen.dart';
import 'features/about/creative_commons_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/collections/collection_detail_screen.dart';
import 'features/collections/collections_screen.dart';
import 'features/credits/credits_screen.dart';
import 'features/home/home_screen.dart';
import 'features/image_detail/image_detail_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_results_screen.dart';
import 'shared/widgets/app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildAppRouter(Ref ref) {
  final authNotifier = ref.read(authStateProvider.notifier);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier.authChangeNotifier,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final notifier = ref.read(authStateProvider.notifier);
      final isOnLogin = state.uri.path == '/login';

      // While auth is still loading from storage, stay put – don't redirect.
      if (!notifier.isInitialized) return null;

      // Not authenticated → force login (except if already on login page).
      if (!auth.isAuthenticated) {
        return isOnLogin ? null : '/login';
      }

      // Authenticated but on login page → send to home.
      if (isOnLogin) return '/';

      return null;
    },
    routes: [
      // Login route — outside the shell
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) {
              final requestToken =
                  int.tryParse(state.uri.queryParameters['rt'] ?? '') ?? 0;
              return SearchResultsScreen(
                imageId: state.uri.queryParameters['i'],
                secondaryImageId: state.uri.queryParameters['i2'],
                query: state.uri.queryParameters['q'],
                requestToken: requestToken,
              );
            },
          ),
          GoRoute(
            path: '/saved',
            builder: (context, state) => const CollectionsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (context, state) => _slideUpTransitionPage(
          key: state.pageKey,
          child: const AboutScreen(),
        ),
      ),
      GoRoute(
        path: '/creativecommons',
        pageBuilder: (context, state) => _slideUpTransitionPage(
          key: state.pageKey,
          child: const CreativeCommonsScreen(),
        ),
      ),
      GoRoute(
        path: '/credits',
        pageBuilder: (context, state) => _slideUpTransitionPage(
          key: state.pageKey,
          child: const CreditsScreen(),
        ),
      ),
      GoRoute(
        path: '/saved/collection/:collectionId',
        pageBuilder: (context, state) => _slideUpTransitionPage(
          key: state.pageKey,
          child: CollectionDetailScreen(
            collectionId: state.pathParameters['collectionId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/i/:imageId',
        pageBuilder: (context, state) {
          final args = state.extra is ImageDetailArgs
              ? state.extra as ImageDetailArgs
              : null;
          return _slideUpTransitionPage(
            key: state.pageKey,
            child: ImageDetailScreen(
              imageId: state.pathParameters['imageId'] ?? '',
              args: args,
            ),
          );
        },
      ),
    ],
  );
}



/// Slide-up transition for detail/push pages.
CustomTransitionPage _slideUpTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: animation.drive(tween), child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}
