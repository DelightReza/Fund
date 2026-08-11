
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/format_utils.dart';
import '../utils/date_utils.dart';

class ReceiptModal extends StatelessWidget {
  final Transaction transaction;
  final String currency;

  const ReceiptModal({super.key, required this.transaction, required this.currency});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(transaction.type == 'credit' ? 'Credit Receipt' : 'Debit Receipt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${transaction.id}'),
          Text('Amount: ${FormatUtils.formatCurrency(transaction.amount, currency)}'),
          Text('Date: ${DateUtils.formatDate(transaction.date)}'),
          if (transaction.note.isNotEmpty) Text('Note: ${transaction.note}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

