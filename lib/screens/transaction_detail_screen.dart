
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/calculations.dart';
import '../utils/format_utils.dart';
import '../utils/date_utils.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final data = ref.watch(dataProvider);
    final tx = data.transactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => Transaction(
        id: '',
        type: 'credit',
        whoOrBill: '',
        amount: 0,
        note: '',
        date: '',
      ),
    );

    if (tx.id.isEmpty) {
      return const Scaffold(body: Center(child: Text('Transaction not found')));
    }

    // If it's a group transaction, show all related
    final isGroup = tx.parentId != null;
    final List<Transaction> groupTxs = isGroup
        ? data.transactions.where((t) => t.parentId == tx.parentId).toList()
        : [tx];

    return Scaffold(
      appBar: AppBar(
        title: Text(isGroup ? 'Group Transaction' : 'Transaction Detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isGroup)
            ...groupTxs.map((t) => _buildTransactionTile(t, config, isGroup: true))
          else
            _buildTransactionTile(tx, config),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Transaction tx, AppConfig config, {bool isGroup = false}) {
    final String displayName;
    if (tx.type == 'credit') {
      final person = config.people.firstWhere((p) => p.id == tx.whoOrBill,
          orElse: () => MemberConfig(id: tx.whoOrBill, name: tx.whoOrBill));
      displayName = person.name;
    } else {
      final bill = config.billTypes.firstWhere((b) => b.id == tx.whoOrBill,
          orElse: () => BillTypeConfig(id: tx.whoOrBill, name: tx.whoOrBill, icon: ''));
      displayName = '${bill.icon} ${bill.name}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  FormatUtils.formatCurrency(tx.amount, config.currency),
                  style: TextStyle(color: tx.type == 'credit' ? Colors.green : Colors.red),
                ),
              ],
            ),
            Text(tx.note),
            Text(DateUtils.formatDate(tx.date), style: const TextStyle(fontSize: 12)),
            if (tx.type == 'debit' && tx.splitAmong != null) ...[
              const SizedBox(height: 8),
              const Text('Split among:'),
              ...tx.splitAmong!.map((id) {
                final p = config.people.firstWhere((p) => p.id == id,
                    orElse: () => MemberConfig(id: id, name: id));
                return Text('• ${p.name}');
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}

