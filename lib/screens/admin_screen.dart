import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'add_transaction_screen.dart';
import 'reset_commit_screen.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync now'),
            subtitle: Text('Pending operations: ${appState.pendingCount}'),
            onTap: () => ref.read(appStateProvider.notifier).syncNow(),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add transaction'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Reset branch to commit'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResetCommitScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.person_remove),
            title: const Text('Switch user'),
            onTap: () {
              ref.read(appStateProvider.notifier).logoutUser();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
