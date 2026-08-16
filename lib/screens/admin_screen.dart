import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/settlement.dart';
import '../models/transaction.dart';
import '../utils/format_utils.dart';
import '../widgets/auth_guard.dart';
import '../widgets/status_popup.dart';
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
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final balances = ref.watch(balancesProvider);
    final settlements = ref.watch(settlementsProvider);

    String resolveMember(String id) {
      final matched = appState.config.people.where((p) => p.id == id).toList();
      return matched.isEmpty ? id : matched.first.name;
    }

    return AuthGuard(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Admin Panel'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Controls'),
                Tab(text: 'Balances'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildControlsTab(context, appState, ref),
              _buildBalancesTab(context, appState, balances, settlements, resolveMember),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalancesTab(
    BuildContext context, 
    AppState appState, 
    Map<String, double> balances, 
    List<Settlement> settlements, 
    String Function(String) resolveMember
  ) {
    // Compute total credits and debits per member
    final credits = <String, double>{};
    final debits = <String, double>{};
    for (var p in appState.config.people) {
      credits[p.id] = 0.0;
      debits[p.id] = 0.0;
    }
    for (var tx in appState.data.transactions) {
      final actorId = tx.actorId;
      if (tx.type == TransactionType.credit && actorId != null && credits.containsKey(actorId)) {
        credits[actorId] = (credits[actorId] ?? 0.0) + tx.amount;
      } else if (tx.type == TransactionType.debit || tx.type == TransactionType.expense) {
        if (tx.participantIds.isNotEmpty) {
          final split = tx.amount / tx.participantIds.length;
          for (var pid in tx.participantIds) {
            if (debits.containsKey(pid)) {
              debits[pid] = (debits[pid] ?? 0.0) + split;
            }
          }
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Member Balances', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Credits'), numeric: true),
              DataColumn(label: Text('Debits'), numeric: true),
              DataColumn(label: Text('Net Balance'), numeric: true),
            ],
            rows: appState.config.people.map<DataRow>((p) {
              final net = balances[p.id] ?? 0.0;
              final cred = credits[p.id] ?? 0.0;
              final deb = debits[p.id] ?? 0.0;
              final isNegative = net < 0;
              return DataRow(cells: [
                DataCell(Text(resolveMember(p.id))),
                DataCell(Text(FormatUtils.currency(cred, appState.config.currency))),
                DataCell(Text(FormatUtils.currency(deb, appState.config.currency))),
                DataCell(Text(
                  FormatUtils.currency(net, appState.config.currency),
                  style: TextStyle(
                    color: isNegative ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),
        Text('Debt Simplification (Who Owes Whom)', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (settlements.isEmpty)
          const Text('All debts are settled!')
        else
          ...settlements.map((s) => ListTile(
            leading: const Icon(Icons.compare_arrows),
            title: Text('${resolveMember(s.from)} owes ${resolveMember(s.to)}'),
            trailing: Text(
              FormatUtils.currency(s.amount, appState.config.currency),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          )),
      ],
    );
  }

  Widget _buildControlsTab(BuildContext context, AppState appState, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (appState.syncing)
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: LinearProgressIndicator(),
          ),
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
                            StatusPopup.show(
                              context,
                              title: 'PAT Verified & Saved',
                              message: 'Authenticated successfully for ${appState.config.repoOwner}/${appState.config.repoName}.',
                              type: StatusPopupType.success,
                              autoDismissDuration: const Duration(seconds: 3),
                            );
                            ref.read(appStateProvider.notifier).syncNow();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            StatusPopup.show(
                              context,
                              title: 'Authentication Failed',
                              message: e.toString().replaceAll('Exception: ', ''),
                              type: StatusPopupType.error,
                            );
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
          title: const Text('Sync now (Push/Pull)'),
          subtitle: Text('Pending operations: ${appState.pendingCount}'),
          onTap: () {
            if (appState.token == null || appState.token!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please save a PAT first.')));
              return;
            }
            ref.read(appStateProvider.notifier).syncNow();
          },
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Pull only'),
          subtitle: const Text('Fetch latest without pushing local changes'),
          onTap: () => ref.read(appStateProvider.notifier).pullOnly(),
        ),
        if (appState.token != null && appState.token!.isNotEmpty) ...[
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Force Commit Data'),
            subtitle: const Text('Directly write data.json to GitHub'),
            onTap: () => ref.read(appStateProvider.notifier).forceCommitData(),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Force Commit Config'),
            subtitle: const Text('Directly write config.json to GitHub'),
            onTap: () => ref.read(appStateProvider.notifier).forceCommitConfig(),
          ),
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
        if (!kIsWeb)
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
    );
  }
}
