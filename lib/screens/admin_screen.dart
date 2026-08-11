import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
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
                        onPressed: () async {
                                final token = _tokenController.text.trim();
                                if (token.isEmpty) {
                                  await ref.read(appStateProvider.notifier).setToken(null);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token removed.')));
                                  }
                                  return;
                                }

                                try {
                                  await ref.read(appStateProvider.notifier).setToken(token);
                                  
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text('Token saved successfully.'),
                                      backgroundColor: Colors.green,
                                    ));
                                    ref.read(appStateProvider.notifier).syncNow();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text('Failed to save token: $e'),
                                      backgroundColor: Colors.red,
                                    ));
                                  }
                                }
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
          if (appState.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appState.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
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
          if (appState.token != null && appState.token!.isNotEmpty) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuration & Settings'),
              subtitle: const Text('Manage members, bill types, and app config'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Advanced Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add Expense'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.expense))),
            ),
            ListTile(
              leading: const Icon(Icons.call_split),
              title: const Text('Distribute Funds'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.distribution))),
            ),
            ListTile(
              leading: const Icon(Icons.handshake),
              title: const Text('Record Settlement'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.settlement))),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Transfer Balance'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.transfer))),
            ),
            const Divider(),
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
          ],
          ListTile(
            leading: const Icon(Icons.person_remove),
            title: const Text('Switch user'),
            onTap: () {
              ref.read(appStateProvider.notifier).logoutUser();
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear local cache & restart', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear all data?'),
                  content: const Text('This will delete all local data, pending offline transactions, and reset the app.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true), 
                      child: const Text('Clear')
                    ),
                  ],
                ),
              );
              
              if (confirm == true && context.mounted) {
                await ref.read(appStateProvider.notifier).clearLocalData();
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}
