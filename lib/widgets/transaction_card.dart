import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    required this.currency,
    required this.memberNameResolver,
    required this.billNameResolver,
    required this.onTap,
  });

  final Transaction transaction;
  final String currency;
  final String Function(String id) memberNameResolver;
  final String Function(String id) billNameResolver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = switch (transaction.type) {
      TransactionType.credit => 'Credit • ${memberNameResolver(transaction.actorId ?? '-')}',
      TransactionType.debit => 'Debit • ${billNameResolver(transaction.targetId ?? '-')}',
      TransactionType.expense => 'Expense • ${billNameResolver(transaction.targetId ?? '-')}',
      TransactionType.distribution => 'Distribution',
      TransactionType.settlement => 'Settlement',
      TransactionType.transfer => 'Transfer',
    };

    final color = switch (transaction.type) {
      TransactionType.debit => Colors.red,
      _ => Colors.green,
    };

    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          '${AppDateUtils.formatDate(transaction.timestamp)}${transaction.note.isEmpty ? '' : ' • ${transaction.note}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          FormatUtils.currency(transaction.amount, currency),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        onTap: onTap,
      ),
    );
  }
}
