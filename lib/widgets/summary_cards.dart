import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../utils/date_utils.dart';
import '../utils/debt_simplifier.dart';
import '../utils/format_utils.dart';

class FundBalanceSummaryCard extends StatelessWidget {
  final double totalBalance;
  final double totalCredits;
  final double totalDebits;
  final String currency;
  final VoidCallback? onAddExpense;

  const FundBalanceSummaryCard({
    super.key,
    required this.totalBalance,
    required this.totalCredits,
    required this.totalDebits,
    required this.currency,
    this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = totalBalance >= 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF047857), const Color(0xFF059669), const Color(0xFF10B981)]
              : [const Color(0xFFB91C1C), const Color(0xFFDC2626), const Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626))
                .withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Fund Balance',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPositive ? 'In Fund' : 'Deficit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            FormatUtils.formatCurrency(totalBalance, currency),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSubItem('Total Paid (Credit)', totalCredits, currency, Colors.greenAccent),
                Container(height: 24, width: 1, color: Colors.white.withOpacity(0.2)),
                _buildSubItem('Total Spent (Debit)', totalDebits, currency, Colors.orangeAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem(String title, double amount, String currency, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          FormatUtils.formatCurrency(amount, currency),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// Backward compatibility alias
typedef PoolSummaryCard = FundBalanceSummaryCard;

class MemberSummaryCard extends StatelessWidget {
  final MemberFinancialSummary summary;
  final AppConfig config;
  final VoidCallback? onTap;

  const MemberSummaryCard({
    super.key,
    required this.summary,
    required this.config,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = config.members.firstWhere(
      (m) => m.id == summary.memberId,
      orElse: () => MemberConfig(id: summary.memberId, name: summary.memberId),
    );

    final isPositive = summary.netBalance >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isPositive
                        ? const Color(0xFF047857).withOpacity(0.15)
                        : const Color(0xFFDC2626).withOpacity(0.15),
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF047857) : const Color(0xFFDC2626),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '@${member.id}',
                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        FormatUtils.formatCurrency(summary.netBalance.abs(), config.currency),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isPositive ? const Color(0xFF047857) : const Color(0xFFDC2626),
                        ),
                      ),
                      Text(
                        isPositive ? 'to receive' : 'owes fund',
                        style: TextStyle(
                          fontSize: 11,
                          color: isPositive ? const Color(0xFF047857) : const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Total Deposited', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        FormatUtils.formatCurrency(summary.totalPaid, config.currency),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  Container(height: 20, width: 1, color: theme.dividerColor),
                  Column(
                    children: [
                      const Text('Share Consumed', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        FormatUtils.formatCurrency(summary.totalConsumed, config.currency),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
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

class BillTypeSummaryCard extends StatelessWidget {
  final BillTypeConfig billType;
  final double totalAmount;
  final double percentage;
  final int transactionCount;
  final String currency;
  final VoidCallback? onTap;

  const BillTypeSummaryCard({
    super.key,
    required this.billType,
    required this.totalAmount,
    required this.percentage,
    this.transactionCount = 0,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(billType.icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(billType.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '${(percentage * 100).toStringAsFixed(1)}% of total expenditure${transactionCount > 0 ? ' • $transactionCount txs' : ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    FormatUtils.formatCurrency(totalAmount, currency),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MonthSummaryCard extends StatelessWidget {
  final String monthKey;
  final double totalCredits;
  final double totalDebits;
  final int transactionCount;
  final String currency;
  final VoidCallback? onClear;

  const MonthSummaryCard({
    super.key,
    required this.monthKey,
    required this.totalCredits,
    required this.totalDebits,
    required this.transactionCount,
    required this.currency,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netCashFlow = totalCredits - totalDebits;
    final isSurplus = netCashFlow >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.7),
            theme.colorScheme.surfaceVariant.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppDateUtils.formatMonthName(monthKey),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSurplus
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSurplus ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 13,
                          color: isSurplus ? const Color(0xFF047857) : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSurplus ? 'Net Surplus' : 'Net Deficit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSurplus ? const Color(0xFF047857) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onClear != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Clear Month Filter',
                      onPressed: onClear,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Deposits (Credit)',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${FormatUtils.formatCurrency(totalCredits, currency)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                Container(height: 24, width: 1, color: theme.dividerColor.withOpacity(0.5)),
                Column(
                  children: [
                    const Text(
                      'Expenses (Debit)',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '-${FormatUtils.formatCurrency(totalDebits, currency)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                Container(height: 24, width: 1, color: theme.dividerColor.withOpacity(0.5)),
                Column(
                  children: [
                    const Text(
                      'Net Cash Flow',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isSurplus ? '+' : '-'}${FormatUtils.formatCurrency(netCashFlow.abs(), currency)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSurplus ? const Color(0xFF047857) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Showing $transactionCount ${transactionCount == 1 ? 'transaction' : 'transactions'} in ${AppDateUtils.formatMonthName(monthKey)}',
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

