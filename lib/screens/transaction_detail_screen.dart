import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/providers.dart';
import '../services/calculations.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';
import '../widgets/receipt_modal.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({
    super.key, 
    required this.transactionId,
    this.focusedMemberId,
    this.runningBalanceBefore,
    this.runningBalanceAfter,
  });

  final String transactionId;
  final String? focusedMemberId;
  final double? runningBalanceBefore;
  final double? runningBalanceAfter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final matchedTx = appState.data.transactions.where((t) => t.id == transactionId).toList();
    final tx = matchedTx.isEmpty ? null : matchedTx.first;

    if (tx == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Detail')),
        body: const Center(child: Text('Transaction not found or deleted.')),
      );
    }

    final activeIds = appState.config.people.where((m) => m.active).map((m) => m.id).toList();

    String resolveMember(String? id) {
      if (id == null || id.isEmpty) return '-';
      final matched = appState.config.people.where((p) => p.id == id).toList();
      return matched.isEmpty ? id : matched.first.name;
    }

    String resolveBill(String? id) {
      if (id == null || id.isEmpty) return '-';
      final matched = appState.config.billTypes.where((b) => b.id == id).toList();
      final bill = matched.isEmpty ? null : matched.first;
      return bill == null ? id : '${bill.icon} ${bill.name}';
    }

    double? impact;
    if (focusedMemberId != null) {
      impact = Calculations.impactForMember(tx, focusedMemberId!, activeIds: activeIds);
    }

    final siblings = (tx.parentId != null && tx.parentId!.isNotEmpty)
        ? appState.data.transactions.where((t) => t.parentId == tx.parentId).toList()
        : <Transaction>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        actions: [
          IconButton(
            tooltip: 'View Receipt',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ReceiptModal(transaction: tx, currency: appState.config.currency),
              );
            },
            icon: const Icon(Icons.receipt_long),
          ),
          if (appState.token != null && appState.token!.isNotEmpty) ...[
            IconButton(
              tooltip: 'Edit Transaction',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddTransactionScreen(existingTransaction: tx)),
                );
              },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete Transaction',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Transaction?'),
                    content: const Text('This will remove the transaction from the ledger. Continue?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await ref.read(appStateProvider.notifier).deleteTransaction(tx.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (focusedMemberId != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Impact on ${resolveMember(focusedMemberId)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '${(impact ?? 0) >= 0 ? "+" : ""}${FormatUtils.currency(impact ?? 0.0, appState.config.currency)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    if (runningBalanceBefore != null && runningBalanceAfter != null) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Balance Before', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                          Text(
                            FormatUtils.currency(runningBalanceBefore!, appState.config.currency),
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Balance After', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                          Text(
                            FormatUtils.currency(runningBalanceAfter!, appState.config.currency),
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    FormatUtils.currency(tx.amount, appState.config.currency),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ),
                if (tx.parentId != null && tx.parentId!.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_shared_outlined),
                    title: const Text('Grouped Expense Item', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Group ID: ${tx.parentId}'),
                    trailing: tx.distributionTotal != null
                        ? Text(
                            'Group Total: ${FormatUtils.currency(tx.distributionTotal!, appState.config.currency)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          )
                        : null,
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  title: const Text('Type'),
                  trailing: Chip(
                    label: Text(tx.type.name.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                ListTile(title: const Text('Date & Time'), subtitle: Text(AppDateUtils.formatDateTime(tx.timestamp))),
                if (tx.actorId != null && tx.actorId!.isNotEmpty)
                  ListTile(
                    title: Text(tx.type == TransactionType.expense ? 'Paid Out of Pocket By' : (tx.type == TransactionType.credit ? 'Deposited By' : 'From / Payer')),
                    subtitle: Text(resolveMember(tx.actorId), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                if (tx.targetId != null && tx.targetId!.isNotEmpty)
                  ListTile(
                    title: Text((tx.type == TransactionType.debit || tx.type == TransactionType.expense) ? 'Category / Bill' : 'To / Recipient'),
                    subtitle: Text(
                      (tx.type == TransactionType.debit || tx.type == TransactionType.expense)
                          ? resolveBill(tx.targetId)
                          : resolveMember(tx.targetId),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (tx.note.isNotEmpty)
                  ListTile(title: const Text('Note'), subtitle: Text(tx.note)),
                ListTile(title: const Text('Transaction ID'), subtitle: SelectableText(tx.id)),
              ],
            ),
          ),
          if (siblings.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'Group Items (${siblings.length} items • Total: ${FormatUtils.currency(siblings.fold(0.0, (s, t) => s + t.amount), appState.config.currency)})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: siblings.map((sibling) {
                  final isCurrent = sibling.id == tx.id;
                  return ListTile(
                    dense: true,
                    selected: isCurrent,
                    selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    leading: Icon(
                      isCurrent ? Icons.check_circle : Icons.subdirectory_arrow_right,
                      size: 18,
                      color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(resolveBill(sibling.targetId), style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    subtitle: sibling.note.isNotEmpty ? Text(sibling.note) : null,
                    trailing: Text(
                      FormatUtils.currency(sibling.amount, appState.config.currency),
                      style: TextStyle(fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (tx.participantIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Participants & Split Breakdown (${tx.participantIds.length} members)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: tx.participantIds.map((id) {
                  final splitShare = tx.amount / tx.participantIds.length;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(resolveMember(id).substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12)),
                    ),
                    title: Text(resolveMember(id)),
                    trailing: Text(
                      FormatUtils.currency(splitShare, appState.config.currency),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
