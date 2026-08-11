
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/providers.dart';
import 'screens/repo_selection_screen.dart';
import 'screens/user_selection_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/transaction_detail_screen.dart';
import 'screens/reset_commit_screen.dart';
import 'theme/theme.dart';

class FundApp extends ConsumerWidget {
  const FundApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final user = ref.watch(userProvider);

    // On web, we load config from the same domain; skip repo/user selection.
    final bool isWeb = const bool.fromEnvironment('dart.library.js_util') == true;

    return MaterialApp.router(
      title: config.siteTitle,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: GoRouter(
        initialLocation: '/',
        redirect: (context, state) {
          if (isWeb) {
            // Web: always go to dashboard (config is fetched on startup)
            return '/dashboard';
          } else {
            // Mobile: check repo and user
            if (config.repoOwner.isEmpty) return '/repo_selection';
            if (user == null || user.isEmpty) return '/user_selection';
            return null;
          }
        },
        routes: [
          GoRoute(
            path: '/repo_selection',
            builder: (context, state) => const RepoSelectionScreen(),
          ),
          GoRoute(
            path: '/user_selection',
            builder: (context, state) => const UserSelectionScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminScreen(),
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProfileScreen(id: id);
            },
          ),
          GoRoute(
            path: '/add_transaction',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return AddTransactionScreen(
                transactionId: extra?['txId'] as String?,
                defaultType: extra?['type'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/transaction_detail/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TransactionDetailScreen(transactionId: id);
            },
          ),
          GoRoute(
            path: '/reset_commit',
            builder: (context, state) => const ResetCommitScreen(),
          ),
        ],
      ),
    );
  }
}

