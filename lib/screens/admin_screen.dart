import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'add_transaction_screen.dart';
import 'reset_commit_screen.dart';
import 'settings_screen.dart';
import 'transaction_history_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tokenController.text = ref.read(appStateProvider).token ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GitHub Authentication', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('A Personal Access Token (PAT) is required to save changes to GitHub.'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tokenController,
                          decoration: const InputDecoration(labelText: 'Personal Access Token', isDense: true),
                          obscureText: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          ref.read(appStateProvider.notifier).setToken(_tokenController.text.trim());
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token saved.')));
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync now'),
            subtitle: Text('Pending operations: ${appState.pendingCount}'),
            onTap: () {
               if (appState.token == null || appState.token!.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please save a PAT first.')));
                 return;
               }
               ref.read(appStateProvider.notifier).syncNow();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuration & Settings'),
            subtitle: const Text('Manage members, bill types, and app config'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add transaction'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Transaction History'),
            subtitle: const Text('View or delete past transactions'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Reset branch to commit'),
            subtitle: const Text('Revert remote repository state'),
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
