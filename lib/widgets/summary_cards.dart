import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../utils/debt_simplifier.dart';
import '../utils/format_utils.dart';
import 'glass_container.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final isPositive = totalBalance >= 0;

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: isDark ? Colors.white : AppTheme.primaryIndigo,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Total Fund Balance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isPositive
                          ? AppTheme.emeraldGreen
                          : AppTheme.roseCrimson)
                      .withValues(alpha: isDark ? 0.20 : 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isPositive
                            ? AppTheme.emeraldGreen
                            : AppTheme.roseCrimson)
                        .withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPositive
                            ? AppTheme.emeraldGreen
                            : AppTheme.roseCrimson,
                        boxShadow: [
                          BoxShadow(
                            color: (isPositive
                                    ? AppTheme.emeraldGreen
                                    : AppTheme.roseCrimson)
                                .withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPositive ? 'Surplus Reserve' : 'Deficit Alert',
                      style: TextStyle(
                        color: isPositive
                            ? AppTheme.emeraldDark
                            : AppTheme.roseDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            FormatUtils.formatCurrency(totalBalance, currency),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isPositive
                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                  : (isDark
                      ? const Color(0xFFF87171)
                      : const Color(0xFFDC2626)),
              fontWeight: FontWeight.w900,
              fontSize: 34,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Deposits (+)',
                    amount: totalCredits,
                    currency: currency,
                    color: isDark
                        ? const Color(0xFF34D399)
                        : const Color(0xFF059669),
                    icon: Icons.arrow_downward_rounded,
                    isDark: isDark,
                  ),
                ),
                Container(
                  height: 38,
                  width: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Spent (-)',
                    amount: totalDebits,
                    currency: currency,
                    color: isDark
                        ? const Color(0xFFFB7185)
                        : const Color(0xFFE11D48),
                    icon: Icons.arrow_upward_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required double amount,
    required String currency,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.80)
                      : Colors.black.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            FormatUtils.formatCurrency(amount, currency),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

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

    final isPositive = summary.netBalance > 0.001;
    final isNegative = summary.netBalance < -0.001;

    final avatarGradient = isPositive
        ? AppTheme.emeraldGradient
        : (isNegative ? AppTheme.roseGradient : AppTheme.violetGradient);

    final badgeColor = isPositive
        ? AppTheme.emeraldDark
        : (isNegative ? AppTheme.roseDark : AppTheme.violetDark);

    final badgeBg = isPositive
        ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
        : (isNegative
            ? AppTheme.roseCrimson.withValues(alpha: 0.12)
            : AppTheme.electricViolet.withValues(alpha: 0.12));

    final badgeBorder = isPositive
        ? AppTheme.emeraldGreen.withValues(alpha: 0.35)
        : (isNegative
            ? AppTheme.roseCrimson.withValues(alpha: 0.35)
            : AppTheme.electricViolet.withValues(alpha: 0.35));

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: avatarGradient,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: (isPositive
                              ? AppTheme.emeraldGreen
                              : (isNegative
                                  ? AppTheme.roseCrimson
                                  : AppTheme.electricViolet))
                          .withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '@${member.id}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isPositive
                          ? '+${FormatUtils.formatCurrency(summary.netBalance, config.currency)}'
                          : (isNegative
                              ? '-${FormatUtils.formatCurrency(summary.netBalance.abs(), config.currency)}'
                              : FormatUtils.formatCurrency(0, config.currency)),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: badgeColor,
                      ),
                    ),
                    Text(
                      isPositive
                          ? 'to receive'
                          : (isNegative ? 'owes fund' : 'settled up'),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Total Deposited',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.formatCurrency(
                          summary.totalPaid, config.currency),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  height: 20,
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
                Column(
                  children: [
                    Text(
                      'Share Consumed',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.formatCurrency(
                          summary.totalConsumed, config.currency),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
    final categoryColor = AppTheme.getCategoryColor(billType.id);

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      categoryColor.withValues(alpha: 0.25),
                      categoryColor.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: categoryColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child:
                    Text(billType.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      billType.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(percentage * 100).toStringAsFixed(1)}% of total spent${transactionCount > 0 ? " • $transactionCount txs" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                FormatUtils.formatCurrency(totalAmount, currency),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation(categoryColor),
              minHeight: 7,
            ),
          ),
        ],
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

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 20,
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryIndigo.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppTheme.primaryIndigo,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppDateUtils.formatMonthName(monthKey),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSurplus
                          ? AppTheme.emeraldGreen.withValues(alpha: 0.20)
                          : AppTheme.roseCrimson.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSurplus
                            ? AppTheme.emeraldGreen.withValues(alpha: 0.4)
                            : AppTheme.roseCrimson.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSurplus
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 13,
                          color: isSurplus
                              ? AppTheme.emeraldDark
                              : AppTheme.roseDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSurplus ? 'Net Surplus' : 'Net Deficit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSurplus
                                ? AppTheme.emeraldDark
                                : AppTheme.roseDark,
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
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
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
              color: theme.colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Deposits (Credit)',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${FormatUtils.formatCurrency(totalCredits, currency)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.emeraldDark,
                      ),
                    ),
                  ],
                ),
                Container(
                    height: 24,
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.3)),
                Column(
                  children: [
                    const Text(
                      'Expenses (Debit)',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '-${FormatUtils.formatCurrency(totalDebits, currency)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.roseDark,
                      ),
                    ),
                  ],
                ),
                Container(
                    height: 24,
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.3)),
                Column(
                  children: [
                    const Text(
                      'Net Cash Flow',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isSurplus ? '+' : '-'}${FormatUtils.formatCurrency(netCashFlow.abs(), currency)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSurplus
                            ? AppTheme.emeraldDark
                            : AppTheme.roseDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Showing $transactionCount ${transactionCount == 1 ? "transaction" : "transactions"} in ${AppDateUtils.formatMonthName(monthKey)}',
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
