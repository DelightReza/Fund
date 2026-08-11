import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/transaction_card.dart';
import '../widgets/receipt_modal.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    String resolveMember(String id) {
      final matched = appState.config.people.where((p) => p.id == id).toList();
      return matched.isEmpty ? id : matched.first.name;
    }

    String resolveBill(String id) {
      final matched = appState.config.billTypes.where((b) => b.id == id).toList();
      final bill = matched.isEmpty ? null : matched.first;
      return bill == null ? id : '${bill.icon} ${bill.name}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appState.data.transactions.length,
        itemBuilder: (context, index) {
          final tx = appState.data.transactions[index];
          return Dismissible(
            key: Key(tx.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete transaction?'),
                  content: const Text('Are you sure you want to delete this transaction?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
            },
            onDismissed: (_) {
              ref.read(appStateProvider.notifier).deleteTransaction(tx.id);
            },
            child: TransactionCard(
              transaction: tx,
              currency: appState.config.currency,
              memberNameResolver: resolveMember,
              billNameResolver: resolveBill,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: tx.id))),
              onLongPress: () {
                showDialog(
                  context: context,
                  builder: (_) => ReceiptModal(transaction: tx, currency: appState.config.currency),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
