import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../models/transaction.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final AppConfig config;
  final VoidCallback onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.config,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = transaction.type == 'credit';

    String title = transaction.note;
    String subtitle = '';
    String iconText = '💰';

    if (isCredit) {
      final payer = config.members.firstWhere(
        (m) => m.id == transaction.payerId || m.id == transaction.whoOrBill,
        orElse: () => MemberConfig(
          id: transaction.whoOrBill,
          name: transaction.whoOrBill,
        ),
      );
      title = payer.name;
      subtitle = transaction.note.isNotEmpty
          ? transaction.note
          : 'Deposit / Contribution';
      iconText = '💵';
    } else {
      final bill = config.billTypes.firstWhere(
        (b) => b.id == transaction.billTypeId || b.id == transaction.whoOrBill,
        orElse: () => BillTypeConfig(
          id: transaction.whoOrBill,
          name: transaction.whoOrBill,
          icon: '🧾',
        ),
      );
      title = bill.name;
      subtitle = transaction.note.isNotEmpty ? transaction.note : 'Expense';
      iconText = bill.icon;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCredit
                ? const Color(0xFF10B981).withOpacity(0.12)
                : const Color(0xFFEF4444).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            iconText,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (transaction.parentId != null && transaction.parentId!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Grouped',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              AppDateUtils.formatRelativeDate(transaction.date),
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Text(
          '${isCredit ? "+" : "-"}${FormatUtils.formatCurrency(transaction.amount, config.currency)}',
          style: TextStyle(
            color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
