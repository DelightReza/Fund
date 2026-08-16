import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../theme/colors.dart';
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
    this.onLongPress,
  });

  final Transaction transaction;
  final String currency;
  final String Function(String id) memberNameResolver;
  final String Function(String id) billNameResolver;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Historical data written by the Kotlin/TypeScript apps encodes
    // settlements and transfers as plain `credit` rows with a *signed*
    // amount (negative = money left this person). Detect that case so we
    // don't mislabel an outgoing leg as an incoming "Deposit".
    final dateStr = AppDateUtils.formatDate(transaction.timestamp);
    final noteText = transaction.note.trim();

    String resolveBillName() {
      final name = billNameResolver(transaction.targetId ?? '-');
      if (name.toLowerCase().contains('other') && noteText.isNotEmpty) {
        return noteText;
      }
      return name;
    }

    final isOutgoingCreditLeg = transaction.type == TransactionType.credit && transaction.amount < 0;

    final (IconData icon, Color iconBg, Color amountColor, String title, String prefix) = switch (transaction.type) {
      TransactionType.credit when isOutgoingCreditLeg => (
          Icons.arrow_upward_rounded,
          AppColors.rose100,
          AppColors.rose700,
          'Sent • ${memberNameResolver(transaction.actorId ?? '-')}',
          '-',
        ),
      TransactionType.credit => (
          Icons.arrow_downward_rounded,
          AppColors.emerald100,
          AppColors.emerald700,
          'Deposit • ${memberNameResolver(transaction.actorId ?? '-')}',
          '+',
        ),
      TransactionType.debit => (
          Icons.arrow_upward_rounded,
          AppColors.rose100,
          AppColors.rose700,
          'Fund Debit • ${resolveBillName()}',
          '-',
        ),
      TransactionType.expense => (
          Icons.shopping_bag_outlined,
          Colors.amber.shade100,
          Colors.amber.shade900,
          '${memberNameResolver(transaction.actorId ?? '-')} • ${resolveBillName()}',
          '-',
        ),
      TransactionType.distribution => (
          Icons.call_split_rounded,
          Colors.purple.shade100,
          Colors.purple.shade700,
          'Distribution (${transaction.participantIds.isEmpty ? "All" : "${transaction.participantIds.length} members"})',
          '+',
        ),
      TransactionType.settlement => (
          Icons.handshake_outlined,
          Colors.teal.shade100,
          Colors.teal.shade700,
          '${memberNameResolver(transaction.actorId ?? '-')} → ${memberNameResolver(transaction.targetId ?? '-')}',
          '↔',
        ),
      TransactionType.transfer => (
          Icons.swap_horiz_rounded,
          Colors.blue.shade100,
          Colors.blue.shade700,
          '${memberNameResolver(transaction.actorId ?? '-')} → ${memberNameResolver(transaction.targetId ?? '-')}',
          '→',
        ),
    };

    final bool notePromoted = title.contains(noteText) && noteText.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Tinted Circular Icon Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? iconBg.withOpacity(0.2) : iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDark ? iconBg : amountColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Transaction info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        if (noteText.isNotEmpty && !notePromoted) ...[
                          Text(
                            ' • ',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          Expanded(
                            child: Text(
                              noteText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount Tag
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${FormatUtils.currency(transaction.amount.abs(), currency)}',
                    style: TextStyle(
                      color: isDark ? amountColor.withOpacity(0.9) : amountColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    transaction.type.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}