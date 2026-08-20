import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';

class ReceiptModal extends ConsumerWidget {
  const ReceiptModal({
    super.key,
    required this.transaction,
    required this.currency,
  });

  final Transaction transaction;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appStateProvider).config;
    final isExpense = transaction.type == TransactionType.expense;
    final isSettlement = transaction.type == TransactionType.settlement;
    final isTransfer = transaction.type == TransactionType.transfer;
    final allTx = ref.watch(appStateProvider).data.transactions;
    final siblings = transaction.parentId != null
        ? allTx.where((t) => t.parentId == transaction.parentId).toList()
        : <Transaction>[];
    final isDistributionGroup = transaction.distributionTotal != null ||
        (transaction.parentId != null && transaction.parentId!.startsWith('tx_dist'));

    String resolveMember(String? id) {
      if (id == null || id.isEmpty) return id ?? '';
      return config.people.where((e) => e.id == id).firstOrNull?.name ?? id;
    }
    
    String resolveBill(String? id) {
      if (id == null || id.isEmpty) return id ?? '';
      return config.billTypes.where((e) => e.id == id).firstOrNull?.name ?? id;
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long),
          const SizedBox(width: 8),
          const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.actorId != null && transaction.actorId!.isNotEmpty)
              _InfoRow(label: 'Paid By / From', value: resolveMember(transaction.actorId)),
            if (transaction.targetId != null && transaction.targetId!.isNotEmpty)
              _InfoRow(
                label: isExpense ? 'Category' : 'Target / To',
                value: isExpense ? resolveBill(transaction.targetId) : resolveMember(transaction.targetId),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    FormatUtils.currency(transaction.amount, currency),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Type', value: transaction.type.name.toUpperCase()),
            _InfoRow(label: 'Date', value: AppDateUtils.formatDateTime(transaction.timestamp)),
            _InfoRow(label: 'Status', value: 'Success', valueColor: Colors.green),
            if (transaction.note.isNotEmpty) _InfoRow(label: 'Note', value: transaction.note),
            _InfoRow(label: 'Transaction ID', value: transaction.id),
            
            if (isExpense && transaction.participantIds.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Split Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: transaction.participantIds.map((id) {
                    final splitAmount = transaction.amount / transaction.participantIds.length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(resolveMember(id), style: const TextStyle(fontSize: 13)),
                          Text(FormatUtils.currency(splitAmount, currency),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            
            if (isDistributionGroup && siblings.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Distribution Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: siblings.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(resolveMember(s.whoOrBill), style: const TextStyle(fontSize: 13)),
                          Text(FormatUtils.currency(s.amount, currency),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, color: valueColor ?? Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}
