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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          elevation: 4,
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── GitHub Authentication ──
            _sectionHeader(context, 'GITHUB AUTHENTICATION'),
            _authCard(context, appState),

            // ── Sync Status ──
            if (appState.syncing) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            ],
            if (appState.error != null) ...[
              const SizedBox(height: 12),
              _errorBanner(context, appState.error!),
            ],
            _sectionHeader(context, 'SYNC & REPOSITORY'),
            _syncCard(context, appState),

            // ── Member Balances ──
            _sectionHeader(context, 'MEMBER BALANCES'),
            _balancesCard(context, appState, balances, resolveMember),

            // ── Debt Simplification ──
            _sectionHeader(context, 'DEBT SIMPLIFICATION'),
            _settlementsCard(context, appState, settlements, resolveMember),

            // ── Quick Actions ──
            _sectionHeader(context, 'QUICK ACTIONS'),
            _quickActionsGrid(context),

            // ── Tools ──
            _sectionHeader(context, 'TOOLS & HISTORY'),
            _toolsCard(context),

            // ── Account ──
            _sectionHeader(context, 'ACCOUNT'),
            _accountCard(context, appState),
          ],
        ),
      ),
    );
  }

  // ── Section Header (old Kotlin "preference category" style) ──
  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Auth Card ──
  Widget _authCard(BuildContext context, AppState appState) {
    final hasToken = appState.token != null && appState.token!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasToken ? Icons.verified_user : Icons.vpn_key_outlined,
                  color: hasToken ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasToken ? 'Authenticated' : 'Personal Access Token Required',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (hasToken)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'A PAT with repo scope is required to push changes to GitHub.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'Token (ghp_…)',
                isDense: true,
                prefixIcon: const Icon(Icons.key, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save, size: 20),
                  tooltip: 'Save Token',
                  onPressed: () => _onSaveToken(context),
                ),
              ),
              obscureText: true,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSaveToken(BuildContext context) async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      await ref.read(appStateProvider.notifier).setToken(null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token removed.')),
        );
      }
      return;
    }
    try {
      await ref.read(appStateProvider.notifier).setToken(token);
      if (context.mounted) {
        StatusPopup.show(
          context,
          title: 'PAT Verified & Saved',
          message: 'Authenticated successfully for ${ref.read(appStateProvider).config.repoOwner}/${ref.read(appStateProvider).config.repoName}.',
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
  }

  // ── Error Banner ──
  Widget _errorBanner(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sync Card ──
  Widget _syncCard(BuildContext context, AppState appState) {
    final hasToken = appState.token != null && appState.token!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync Now'),
            subtitle: Text('Pending: ${appState.pendingCount}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (!hasToken) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please save a PAT first.')),
                );
                return;
              }
              final ok = await ref.read(appStateProvider.notifier).syncNow();
              if (context.mounted) {
                if (ok) {
                  StatusPopup.show(
                    context,
                    title: 'Sync Complete',
                    message: 'All pending changes and remote updates synchronized successfully.',
                    type: StatusPopupType.success,
                    autoDismissDuration: const Duration(seconds: 3),
                  );
                } else {
                  final err = ref.read(appStateProvider).error ?? 'Sync encountered an issue.';
                  StatusPopup.show(
                    context,
                    title: 'Sync Issue',
                    message: err,
                    type: StatusPopupType.error,
                  );
                }
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Pull Only'),
            subtitle: const Text('Fetch latest without pushing'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await ref.read(appStateProvider.notifier).pullOnly();
              if (context.mounted) {
                final err = ref.read(appStateProvider).error;
                if (err == null) {
                  StatusPopup.show(
                    context,
                    title: 'Pull Successful',
                    message: 'Fetched latest data from GitHub repository.',
                    type: StatusPopupType.success,
                    autoDismissDuration: const Duration(seconds: 3),
                  );
                } else {
                  StatusPopup.show(
                    context,
                    title: 'Pull Failed',
                    message: err,
                    type: StatusPopupType.error,
                  );
                }
              }
            },
          ),
          if (hasToken) ...[
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Force Commit Data'),
              subtitle: const Text('Directly write data.json'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await ref.read(appStateProvider.notifier).forceCommitData();
                if (context.mounted) {
                  if (ok) {
                    StatusPopup.show(
                      context,
                      title: 'Data Committed',
                      message: 'Successfully pushed data.json to GitHub repository.',
                      type: StatusPopupType.success,
                      autoDismissDuration: const Duration(seconds: 3),
                    );
                  } else {
                    final err = ref.read(appStateProvider).error ?? 'Commit data failed.';
                    StatusPopup.show(
                      context,
                      title: 'Commit Failed',
                      message: err,
                      type: StatusPopupType.error,
                    );
                  }
                }
              },
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Force Commit Config'),
              subtitle: const Text('Directly write config.json'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await ref.read(appStateProvider.notifier).forceCommitConfig();
                if (context.mounted) {
                  if (ok) {
                    StatusPopup.show(
                      context,
                      title: 'Config Committed',
                      message: 'Successfully pushed config.json to GitHub repository.',
                      type: StatusPopupType.success,
                      autoDismissDuration: const Duration(seconds: 3),
                    );
                  } else {
                    final err = ref.read(appStateProvider).error ?? 'Commit config failed.';
                    StatusPopup.show(
                      context,
                      title: 'Commit Failed',
                      message: err,
                      type: StatusPopupType.error,
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Balances Card ──
  Widget _balancesCard(
    BuildContext context,
    AppState appState,
    Map<String, double> balances,
    String Function(String) resolveMember,
  ) {
    // Compute per-member credit / debit breakdown
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal "summary chips"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: appState.config.people.map((p) {
                final net = balances[p.id] ?? 0.0;
                final isNeg = net < 0;
                return Chip(
                  avatar: CircleAvatar(
                    radius: 12,
                    backgroundColor: isNeg ? Colors.red.shade100 : Colors.green.shade100,
                    child: Text(
                      p.name.isNotEmpty ? p.name[0] : '?',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isNeg ? Colors.red.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ),
                  label: Text(
                    '${resolveMember(p.id)}: ${FormatUtils.currency(net, appState.config.currency)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isNeg ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                  backgroundColor: isNeg ? Colors.red.shade50 : Colors.green.shade50,
                  side: BorderSide.none,
                );
              }).toList(),
            ),
          ),
          const Divider(height: 24),
          // Detailed table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              columns: const [
                DataColumn(label: Text('Member')),
                DataColumn(label: Text('In'), numeric: true),
                DataColumn(label: Text('Out'), numeric: true),
                DataColumn(label: Text('Net'), numeric: true),
              ],
              rows: appState.config.people.map<DataRow>((p) {
                final net = balances[p.id] ?? 0.0;
                final cred = credits[p.id] ?? 0.0;
                final deb = debits[p.id] ?? 0.0;
                final isNegative = net < 0;
                return DataRow(cells: [
                  DataCell(Text(resolveMember(p.id))),
                  DataCell(Text(FormatUtils.currency(cred, appState.config.currency),
                      style: const TextStyle(color: Colors.green))),
                  DataCell(Text(FormatUtils.currency(deb, appState.config.currency),
                      style: const TextStyle(color: Colors.red))),
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
        ],
      ),
    );
  }

  // ── Settlements Card ──
  Widget _settlementsCard(
    BuildContext context,
    AppState appState,
    List<Settlement> settlements,
    String Function(String) resolveMember,
  ) {
    if (settlements.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'All debts are settled! 🎉',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: settlements.asMap().entries.map((e) {
          final s = e.value;
          final isLast = e.key == settlements.length - 1;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 18,
                  ),
                ),
                title: Text('${resolveMember(s.from)} owes ${resolveMember(s.to)}'),
                trailing: Text(
                  FormatUtils.currency(s.amount, appState.config.currency),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 72),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Quick Actions Grid ──
  Widget _quickActionsGrid(BuildContext context) {
    final actions = [
      _ActionItem(
        icon: Icons.add_circle_outline,
        label: 'Add\nExpense',
        color: Colors.blue,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.expense)),
        ),
      ),
      _ActionItem(
        icon: Icons.call_split,
        label: 'Distribute\nFunds',
        color: Colors.purple,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.distribution)),
        ),
      ),
      _ActionItem(
        icon: Icons.handshake,
        label: 'Record\nSettlement',
        color: Colors.teal,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.settlement)),
        ),
      ),
      _ActionItem(
        icon: Icons.swap_horiz,
        label: 'Transfer\nBalance',
        color: Colors.indigo,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: TransactionType.transfer)),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemBuilder: (context, index) {
          final a = actions[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: a.onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a.icon, color: a.color, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      a.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: a.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tools Card ──
  Widget _toolsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuration & Settings'),
            subtitle: const Text('Members, bill types, currency'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Transaction History'),
            subtitle: const Text('View or delete past entries'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Reset Branch to Commit'),
            subtitle: const Text('Revert remote repository state'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResetCommitScreen())),
          ),
        ],
      ),
    );
  }

  // ── Account Card ──
  Widget _accountCard(BuildContext context, AppState appState) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.person_remove),
              title: const Text('Switch User'),
              subtitle: const Text('Log out and select another profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(appStateProvider.notifier).logoutUser();
                Navigator.of(context).pop();
              },
            ),
          if (!kIsWeb) const Divider(height: 1, indent: 56),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red.shade400),
            title: const Text('Clear Local Cache & Restart'),
            subtitle: const Text('Delete all offline data and reset'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _onClearCache(context),
          ),
        ],
      ),
    );
  }

  Future<void> _onClearCache(BuildContext context) async {
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
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(appStateProvider.notifier).clearLocalData();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

// ── Helper model for grid actions ──
class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}
