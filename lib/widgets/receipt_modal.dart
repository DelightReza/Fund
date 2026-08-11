import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';

class ReceiptModal extends StatelessWidget {
  const ReceiptModal({
    super.key,
    required this.transaction,
    required this.currency,
  });

  final Transaction transaction;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receipt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Type: ${transaction.type.name}'),
          Text('Amount: ${FormatUtils.currency(transaction.amount, currency)}'),
          Text('Date: ${AppDateUtils.formatDateTime(transaction.timestamp)}'),
          Text('Note: ${transaction.note.isEmpty ? '-' : transaction.note}'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
