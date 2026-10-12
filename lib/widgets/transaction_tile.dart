import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';
import 'glass_container.dart';

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
    Color iconBgColor = AppTheme.primaryIndigo.withValues(alpha: 0.12);
    Color iconBorderColor = AppTheme.primaryIndigo.withValues(alpha: 0.28);
    Color pillColor = AppTheme.primaryIndigo;

    if (isCredit) {
      final payer = config.members.firstWhere(
        (m) => m.id == transaction.payerId || m.id == transaction.whoOrBill,
        orElse: () => MemberConfig(
          id: transaction.whoOrBill,
          name: transaction.whoOrBill,
        ),
      );
      if (transaction.note.trim().isNotEmpty) {
        title = transaction.note.trim();
        subtitle = payer.name;
      } else {
        title = payer.name;
        subtitle = 'Deposit / Contribution';
      }
      iconText = '💵';
      iconBgColor = AppTheme.emeraldGreen.withValues(alpha: 0.18);
      iconBorderColor = AppTheme.emeraldGreen.withValues(alpha: 0.38);
      pillColor = AppTheme.emeraldDark;
    } else {
      final bill = config.billTypes.firstWhere(
        (b) => b.id == transaction.billTypeId || b.id == transaction.whoOrBill,
        orElse: () => BillTypeConfig(
          id: transaction.whoOrBill,
          name: transaction.whoOrBill,
          icon: '🧾',
        ),
      );
      if (transaction.note.trim().isNotEmpty) {
        title = transaction.note.trim();
        subtitle = bill.name;
      } else {
        title = bill.name;
        subtitle = 'Expense';
      }
      iconText = bill.icon;
      final categoryColor = AppTheme.getCategoryColor(bill.id);
      iconBgColor = categoryColor.withValues(alpha: 0.18);
      iconBorderColor = categoryColor.withValues(alpha: 0.38);
      pillColor = categoryColor;
    }

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 0),
      borderRadius: 18,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: iconBorderColor, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            iconText,
            style: const TextStyle(fontSize: 22),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (transaction.parentId != null && transaction.parentId!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.electricViolet.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.electricViolet.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'Grouped',
                  style: TextStyle(
                    color: AppTheme.violetDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: pillColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: pillColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 11.5,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        AppDateUtils.formatRelativeDate(transaction.date),
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        trailing: Text(
          '${isCredit ? "+" : "-"}${FormatUtils.formatCurrency(transaction.amount, config.currency)}',
          style: TextStyle(
            color: isCredit ? AppTheme.emeraldDark : AppTheme.roseDark,
            fontWeight: FontWeight.w800,
            fontSize: 15.5,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
