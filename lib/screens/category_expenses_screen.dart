import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../models/transaction.dart';
import '../repositories/fund_repository.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';

class CategoryExpensesScreen extends StatefulWidget {
  final String billTypeId;

  const CategoryExpensesScreen({
    super.key,
    required this.billTypeId,
  });

  @override
  State<CategoryExpensesScreen> createState() => _CategoryExpensesScreenState();
}

class _CategoryExpensesScreenState extends State<CategoryExpensesScreen> {
  String? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<FundRepository>();
    final config = repo.config ?? AppConfig();
    final data = repo.data ?? FundData();

    final billCategory = config.billTypes.firstWhere(
      (b) => b.id == widget.billTypeId,
      orElse: () => BillTypeConfig(
        id: widget.billTypeId,
        name: widget.billTypeId,
        icon: '🧾',
      ),
    );

    // Filter all debit transactions for this category
    final allCategoryTransactions = data.transactions.where((tx) {
      if (tx.type != 'debit') return false;
      final bId = (tx.billTypeId != null && tx.billTypeId!.isNotEmpty)
          ? tx.billTypeId!
          : tx.whoOrBill;
      return bId == widget.billTypeId;
    }).toList();

    // Sort descending (newest first)
    allCategoryTransactions.sort((a, b) {
      final timeA = DateTime.tryParse(a.date)?.millisecondsSinceEpoch ?? 0;
      final timeB = DateTime.tryParse(b.date)?.millisecondsSinceEpoch ?? 0;
      return timeB.compareTo(timeA);
    });

    // Calculate total fund debits for percentage
    double totalFundDebits = 0.0;
    for (final tx in data.transactions) {
      if (tx.type == 'debit') {
        totalFundDebits += tx.amount;
      }
    }

    final totalSpent = allCategoryTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.amount,
    );

    final pctOfTotal = totalFundDebits > 0 ? (totalSpent / totalFundDebits) * 100 : 0.0;
    final avgTx = allCategoryTransactions.isNotEmpty ? (totalSpent / allCategoryTransactions.length) : 0.0;

    // Monthly breakdown
    final monthlyMap = <String, double>{};
    final monthlyCount = <String, int>{};
    for (final tx in allCategoryTransactions) {
      final m = AppDateUtils.getMonthKey(tx.date);
      monthlyMap[m] = (monthlyMap[m] ?? 0.0) + tx.amount;
      monthlyCount[m] = (monthlyCount[m] ?? 0) + 1;
    }
    final sortedMonths = monthlyMap.keys.toList()..sort((a, b) => b.compareTo(a));

    // Filter transactions by selected month if active
    final displayedTransactions = _selectedMonth == null
        ? allCategoryTransactions
        : allCategoryTransactions.where((tx) => AppDateUtils.getMonthKey(tx.date) == _selectedMonth).toList();

    // Calculate member share consumed in this category
    final allMemberIds = config.members.map((m) => m.id).toList();
    final memberShareMap = <String, double>{for (final m in config.members) m.id: 0.0};

    for (final tx in allCategoryTransactions) {
      List<String> paying;
      if (tx.splitAmong != null && tx.splitAmong!.isNotEmpty) {
        paying = tx.splitAmong!;
      } else {
        final exemptions = tx.exemptions ?? [];
        paying = allMemberIds.where((id) => !exemptions.contains(id)).toList();
      }

      if (paying.isNotEmpty) {
        final perPerson = tx.amount / paying.length;
        for (final mId in paying) {
          memberShareMap[mId] = (memberShareMap[mId] ?? 0.0) + perPerson;
        }
      }
    }

    final currentMonthKey = AppDateUtils.todayMonthKey();
    final thisMonthSpent = monthlyMap[currentMonthKey] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(billCategory.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                billCategory.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Hero Category Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Text(billCategory.icon, style: const TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 10),
                Text(
                  billCategory.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${pctOfTotal.toStringAsFixed(1)}% of total fund expenditure',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  FormatUtils.formatCurrency(totalSpent, config.currency),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Transactions',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${allCategoryTransactions.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 26, width: 1, color: Colors.white.withOpacity(0.2)),
                      Column(
                        children: [
                          Text(
                            'Average Size',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            FormatUtils.formatCurrency(avgTx, config.currency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 26, width: 1, color: Colors.white.withOpacity(0.2)),
                      Column(
                        children: [
                          Text(
                            'This Month',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            FormatUtils.formatCurrency(thisMonthSpent, config.currency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Member Share Breakdown Card
          if (totalSpent > 0) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Member Split Breakdown',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '${config.members.length} members',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...config.members.map((member) {
                      final share = memberShareMap[member.id] ?? 0.0;
                      final memberPct = totalSpent > 0 ? (share / totalSpent) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                                  child: Text(
                                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    member.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  FormatUtils.formatCurrency(share, config.currency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: memberPct,
                                backgroundColor: theme.colorScheme.surfaceVariant,
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Monthly Breakdown Filter Chips (if more than 1 month)
          if (sortedMonths.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All Months (${allCategoryTransactions.length})'),
                    selected: _selectedMonth == null,
                    onSelected: (selected) {
                      setState(() => _selectedMonth = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ...sortedMonths.map((m) {
                    final monthTotal = monthlyMap[m] ?? 0.0;
                    final count = monthlyCount[m] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$m ($count) • ${FormatUtils.formatCurrency(monthTotal, config.currency)}'),
                        selected: _selectedMonth == m,
                        onSelected: (selected) {
                          setState(() => _selectedMonth = selected ? m : null);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Transactions List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expenses List (${displayedTransactions.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Tap receipt for full details',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (displayedTransactions.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No expenses recorded in this category yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddTransactionScreen(
                            initialMode: 0,
                            initialBillTypeId: widget.billTypeId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Add ${billCategory.name} Expense'),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...displayedTransactions.map((tx) {
              // Find who paid (paired credit if member paid, or from fund)
              String payerLabel = 'Fund Pool';
              if (tx.payerId != null && tx.payerId!.isNotEmpty) {
                final payer = config.members.firstWhere(
                  (m) => m.id == tx.payerId,
                  orElse: () => MemberConfig(id: tx.payerId!, name: tx.payerId!),
                );
                payerLabel = 'Paid by ${payer.name}';
              } else if (tx.parentId != null && tx.parentId!.isNotEmpty) {
                final pairedCredit = data.transactions.firstWhere(
                  (t) => t.parentId == tx.parentId && t.type == 'credit',
                  orElse: () => tx,
                );
                if (pairedCredit.payerId != null && pairedCredit.payerId!.isNotEmpty) {
                  final payer = config.members.firstWhere(
                    (m) => m.id == pairedCredit.payerId,
                    orElse: () => MemberConfig(id: pairedCredit.payerId!, name: pairedCredit.payerId!),
                  );
                  payerLabel = 'Paid by ${payer.name}';
                }
              }

              final splitCount = tx.splitAmong?.length ??
                  (config.members.length - (tx.exemptions?.length ?? 0));

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(
                          transaction: tx,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFDC2626).withOpacity(0.12),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.note.isNotEmpty ? tx.note : billCategory.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    AppDateUtils.formatDisplayDate(tx.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      payerLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '-${FormatUtils.formatCurrency(tx.amount, config.currency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Split with $splitCount',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
