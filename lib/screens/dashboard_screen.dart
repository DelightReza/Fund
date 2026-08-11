import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/format_utils.dart';
import '../widgets/member_card.dart';
import '../widgets/transaction_card.dart';
import 'add_transaction_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';
import 'transaction_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final balances = ref.watch(balancesProvider);
    final totals = ref.watch(totalsProvider);
    final bills = ref.watch(billTotalsProvider);
    final settlements = ref.watch(settlementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.config.siteTitle),
        actions: [
          IconButton(
            onPressed: appState.syncing ? null : () => ref.read(appStateProvider.notifier).syncNow(),
            icon: appState.syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
            icon: const Icon(Icons.admin_panel_settings),
          ),
        ],
      ),
      floatingActionButton: (appState.token != null && appState.token!.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(appStateProvider.notifier).refreshReadOnly(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Balance', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      FormatUtils.currency(totals.credits - totals.debits, appState.config.currency),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Collected: ${FormatUtils.currency(totals.credits, appState.config.currency)}')),
                        Expanded(child: Text('Spent: ${FormatUtils.currency(totals.debits, appState.config.currency)}')),
                      ],
                    ),
                    if (appState.pendingCount > 0) ...[
                      const SizedBox(height: 8),
                      Text('Pending sync: ${appState.pendingCount}', style: const TextStyle(color: Colors.orange)),
                    ],
                  ],
                ),
              ),
            ),
            if (bills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bills.entries.map((entry) {
                  final matched = appState.config.billTypes.where((e) => e.id == entry.key).toList();
                  final type = matched.isEmpty ? null : matched.first;
                  final label = '${type?.icon ?? '🧾'} ${type?.name ?? entry.key}: ${FormatUtils.currency(entry.value, appState.config.currency)}';
                  return Chip(label: Text(label));
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text('Members', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GridView.builder(
              itemCount: appState.config.people.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.4,
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
            const SizedBox(height: 12),
            if (settlements.isNotEmpty) ...[
              Text('Debt Simplification', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ...settlements.map(
                (s) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.arrow_right_alt),
                  title: Text('${_memberName(appState, s.from)} → ${_memberName(appState, s.to)}'),
                  trailing: Text(FormatUtils.currency(s.amount, appState.config.currency)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('Transactions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...appState.data.transactions.map(
              (tx) => TransactionCard(
                transaction: tx,
                currency: appState.config.currency,
                memberNameResolver: (id) => _memberName(appState, id),
                billNameResolver: (id) => _billName(appState, id),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: tx.id))),
              ),
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
}
