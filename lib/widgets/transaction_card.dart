
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/format_utils.dart';
import '../utils/date_utils.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final String displayTitle;
  final String currency;
  final VoidCallback onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.displayTitle,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == 'credit';
    final color = isCredit ? Colors.green : Colors.red;
    final amountStr = (isCredit ? '+' : '-') +
        FormatUtils.formatCurrency(transaction.amount, currency);

    return ListTile(
      leading: CircleAvatar(
        child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward),
      ),
      title: Text(displayTitle),
      subtitle: Text(
        transaction.note.isNotEmpty ? transaction.note : DateUtils.formatDateOnly(transaction.date),
      ),
      trailing: Text(amountStr, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }
}

