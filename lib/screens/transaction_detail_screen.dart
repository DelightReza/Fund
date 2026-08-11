import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';
import '../widgets/receipt_modal.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final matchedTx = appState.data.transactions.where((t) => t.id == transactionId).toList();
    final tx = matchedTx.isEmpty ? null : matchedTx.first;

    if (tx == null) {
      return const Scaffold(body: Center(child: Text('Transaction not found')));
    }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ReceiptModal(transaction: tx, currency: appState.config.currency),
              );
            },
            icon: const Icon(Icons.receipt_long),
          ),
          if (appState.token != null && appState.token!.isNotEmpty)
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddTransactionScreen(existingTransaction: tx)),
                ).then((_) {
                  // Return to previous screen after edit
                  if (context.mounted) Navigator.of(context).pop();
                });
              },
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('ID'), subtitle: Text(tx.id)),
          ListTile(title: const Text('Type'), subtitle: Text(tx.type.name.toUpperCase())),
          ListTile(
            title: const Text('Amount'),
            subtitle: Text(FormatUtils.currency(tx.amount, appState.config.currency)),
          ),
          ListTile(title: const Text('Date'), subtitle: Text(AppDateUtils.formatDateTime(tx.timestamp))),
          ListTile(title: const Text('Actor'), subtitle: Text(resolveMember(tx.actorId))),
          ListTile(
            title: const Text('Target'),
            subtitle: Text((tx.type.name == 'debit' || tx.type.name == 'expense')
                ? resolveBill(tx.targetId)
                : resolveMember(tx.targetId)),
          ),
          ListTile(title: const Text('Participants'), subtitle: Text(tx.participantIds.join(', '))),
          ListTile(title: const Text('Note'), subtitle: Text(tx.note.isEmpty ? '-' : tx.note)),
        ],
      ),
    );
  }
}
