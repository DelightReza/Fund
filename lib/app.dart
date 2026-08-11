import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'screens/dashboard_screen.dart';
import 'screens/repo_selection_screen.dart';
import 'screens/user_selection_screen.dart';
import 'theme/theme.dart';

class FundApp extends ConsumerStatefulWidget {
  const FundApp({super.key});

  @override
  ConsumerState<FundApp> createState() => _FundAppState();
}

class _FundAppState extends ConsumerState<FundApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appStateProvider.notifier).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: appState.config.siteTitle,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: switch (appState.stage) {
        LaunchStage.loading => const _LoadingScreen(),
        LaunchStage.repoSelection => const RepoSelectionScreen(),
        LaunchStage.userSelection => const UserSelectionScreen(),
        LaunchStage.dashboard => const DashboardScreen(),
        LaunchStage.error => _ErrorScreen(message: appState.error ?? 'Unknown error'),
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends ConsumerWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(appStateProvider.notifier).bootstrap(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
