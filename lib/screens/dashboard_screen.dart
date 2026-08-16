import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_sync_manager.dart';
import '../providers/providers.dart';
import '../utils/format_utils.dart';
import '../widgets/auth_guard.dart';
import '../widgets/hero_balance_card.dart';
import '../widgets/member_card.dart';
import '../widgets/transaction_card.dart';
import '../widgets/receipt_modal.dart';
import 'add_transaction_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';
import 'repo_selection_screen.dart';
import 'transaction_detail_screen.dart';
import 'transaction_history_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize background connectivity sync watcher
    ref.read(connectivitySyncManagerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final balances = ref.watch(balancesProvider);
    final totals = ref.watch(totalsProvider);
    final bills = ref.watch(billTotalsProvider);
    final settlements = ref.watch(settlementsProvider);
    final hasToken = appState.token != null && appState.token!.isNotEmpty;

    final currentUserId = appState.userId ?? (appState.config.people.isNotEmpty ? appState.config.people.first.id : '');

    // On Android, show Profile tab bound to active user. On Web, omit Profile tab (accessed via member cards).
    final pages = [
      _buildOverviewTab(context, appState, balances, totals, bills, settlements, hasToken),
      if (hasToken) const AuthGuard(child: AdminScreen()),
      if (!kIsWeb) ProfileScreen(memberId: currentUserId),
    ];

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Overview',
      ),
      if (hasToken)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      if (!kIsWeb)
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
    ];

    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    final hasSubtitle = appState.config.siteSubtitle.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: kIsWeb
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appState.config.siteTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (hasSubtitle)
                    Text(
                      appState.config.siteSubtitle,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                ],
              )
            : InkWell(
                onTap: () => _showRepoSwitcherBottomSheet(context, ref),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            appState.config.siteTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          if (hasSubtitle)
                            Text(
                              appState.config.siteSubtitle,
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
        actions: [
          IconButton(
            onPressed: () => _showTokenDialog(context, ref),
            icon: Icon(
              hasToken ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
              color: hasToken ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: hasToken ? 'Admin Access Active' : 'Admin Authentication',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RepoSelectionScreen())),
            icon: const Icon(Icons.source_outlined),
            tooltip: 'Switch or Manage Repositories',
          ),
          IconButton(
            onPressed: () {
              final currentMode = ref.read(themeModeProvider);
              if (currentMode == ThemeMode.light) {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
              } else if (currentMode == ThemeMode.dark) {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
              } else {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
              }
            },
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.light
                  ? Icons.light_mode
                  : ref.watch(themeModeProvider) == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.brightness_auto,
            ),
          ),
          IconButton(
            onPressed: appState.syncing ? null : () => ref.read(appStateProvider.notifier).syncNow(),
            icon: appState.syncing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
            tooltip: 'Sync with GitHub',
          ),
        ],
      ),
      bottomNavigationBar: destinations.length > 1
          ? NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              destinations: destinations,
            )
          : null,
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    appState,
    Map<String, double> balances,
    totals,
    Map<String, double> bills,
    settlements,
    bool hasToken,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(appStateProvider.notifier).refreshReadOnly(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeroBalanceCard(
            netBalance: totals.credits - totals.debits,
            totalCollected: totals.credits,
            totalSpent: totals.debits,
            currency: appState.config.currency,
            siteTitle: appState.config.siteTitle,
            repoOwner: appState.config.repoOwner,
            repoName: appState.config.repoName,
            hasToken: hasToken,
            pendingCount: appState.pendingCount,
            onTapRepo: () => _showRepoSwitcherBottomSheet(context, ref),
          ),
          const SizedBox(height: 16),
          if (bills.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pie_chart_outline, size: 20),
                        const SizedBox(width: 8),
                        Text('Expenses by Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...bills.entries.map((entry) {
                      final matched = appState.config.billTypes.where((e) => e.id == entry.key).toList();
                      final type = matched.isEmpty ? null : matched.first;
                      final name = '${type?.icon ?? '🧾'} ${type?.name ?? entry.key}';
                      final amount = entry.value;
                      final proportion = totals.debits > 0 ? amount / totals.debits : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  FormatUtils.currency(amount, appState.config.currency),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: proportion,
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              color: Theme.of(context).colorScheme.primary,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Members', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('${appState.config.people.length} active', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            itemCount: appState.config.people.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, index) {
              final person = appState.config.people[index];
              return MemberCard(
                name: person.name,
                net: balances[person.id] ?? 0,
                currency: appState.config.currency,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(memberId: person.id))),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...appState.data.transactions.take(8).map(
                (tx) => TransactionCard(
                  transaction: tx,
                  currency: appState.config.currency,
                  memberNameResolver: (id) => _memberName(appState, id),
                  billNameResolver: (id) => _billName(appState, id),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: tx.id))),
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (_) => ReceiptModal(transaction: tx, currency: appState.config.currency),
                    );
                  },
                ),
              ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showTokenDialog(BuildContext context, WidgetRef ref) {
    final appState = ref.read(appStateProvider);
    final currentToken = appState.token ?? '';
    final controller = TextEditingController(text: currentToken);
    bool isVerifying = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: !isVerifying,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isCurrentlyAuthenticated = currentToken.isNotEmpty;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isCurrentlyAuthenticated ? Icons.verified_user : Icons.admin_panel_settings_outlined,
                  color: isCurrentlyAuthenticated ? Theme.of(context).colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Text(isCurrentlyAuthenticated ? 'Admin Authentication' : 'GitHub Admin Access'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentlyAuthenticated
                        ? 'Authenticated for repo: ${appState.config.repoOwner}/${appState.config.repoName} (${appState.config.repoBranch})'
                        : 'Enter a GitHub Personal Access Token (PAT) for ${appState.config.repoOwner}/${appState.config.repoName} to unlock saving & pushing changes.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    enabled: !isVerifying,
                    decoration: InputDecoration(
                      labelText: 'Personal Access Token',
                      hintText: 'ghp_...',
                      prefixIcon: const Icon(Icons.key),
                      errorText: errorMessage,
                      suffixIcon: isVerifying
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                    ),
                    obscureText: true,
                  ),
                  if (isCurrentlyAuthenticated) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: isVerifying
                          ? null
                          : () async {
                              setDialogState(() {
                                isVerifying = true;
                                errorMessage = null;
                              });
                              try {
                                await ref.read(appStateProvider.notifier).setToken(null);
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Logged out of Admin session')),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() {
                                  errorMessage = e.toString();
                                  isVerifying = false;
                                });
                              }
                            },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Remove Token / Log Out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        final token = controller.text.trim();
                        if (token.isEmpty) {
                          setDialogState(() => errorMessage = 'Please enter a token');
                          return;
                        }

                        setDialogState(() {
                          isVerifying = true;
                          errorMessage = null;
                        });

                        try {
                          await ref.read(appStateProvider.notifier).setToken(token);
                          await ref.read(appStateProvider.notifier).syncNow();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('GitHub repository access verified successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isVerifying = false;
                            errorMessage = 'Verification failed: Make sure token has repo access to this repository.';
                          });
                        }
                      },
                child: Text(isVerifying ? 'Verifying...' : 'Verify & Unlock'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLockedAdminTab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Admin Access Required',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please add and verify a GitHub Personal Access Token (PAT) in settings to access admin features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (kIsWeb) {
                  _showTokenDialog(context, ref);
                } else {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RepoSelectionScreen()));
                }
              },
              icon: const Icon(Icons.vpn_key),
              label: const Text('Add Token'),
            ),
          ],
        ),
      ),
    );
  }

  String _memberName(AppState state, String id) {
    final matched = state.config.people.where((p) => p.id == id).toList();
    return matched.isEmpty ? id : matched.first.name;
  }

  String _billName(AppState state, String id) {
    final matched = state.config.billTypes.where((b) => b.id == id).toList();
    final bill = matched.isEmpty ? null : matched.first;
    if (bill == null) return id;
    return '${bill.icon} ${bill.name}';
  }

  void _showRepoSwitcherBottomSheet(BuildContext context, WidgetRef ref) {
    final state = ref.read(appStateProvider);
    final savedRepos = state.savedRepos;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Switch Repository', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              if (savedRepos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No saved repositories found.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: savedRepos.length,
                    itemBuilder: (context, index) {
                      final repo = savedRepos[index];
                      final isActive = state.config.repoOwner.toLowerCase() == repo.owner.toLowerCase() &&
                          state.config.repoName.toLowerCase() == repo.repo.toLowerCase();

                      return ListTile(
                        leading: Icon(
                          isActive ? Icons.folder_special : Icons.folder_outlined,
                          color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        title: Text(repo.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${repo.owner}/${repo.repo} (${repo.branch})'),
                        trailing: isActive
                            ? const Chip(
                                label: Text('Active', style: TextStyle(fontSize: 12, color: Colors.white)),
                                backgroundColor: Colors.blue,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          if (!isActive) {
                            ref.read(appStateProvider.notifier).switchRepository(repo);
                          }
                        },
                      );
                    },
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add or Manage Repositories'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RepoSelectionScreen()));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
