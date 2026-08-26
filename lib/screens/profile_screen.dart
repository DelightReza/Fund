import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../repositories/fund_repository.dart';
import '../services/storage_service.dart';
import '../utils/date_utils.dart';
import '../utils/debt_simplifier.dart';
import '../utils/format_utils.dart';
import '../widgets/settlement_card.dart';
import 'transaction_detail_screen.dart';
import 'user_selection_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String? memberId;

  const ProfileScreen({super.key, this.memberId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<FundRepository>();
    final storage = context.watch<StorageService>();
    final config = repo.config ?? AppConfig();
    final data = repo.data ?? FundData();

    final targetMemberId = memberId ?? storage.currentUser;

    final member = config.members.firstWhere(
      (m) => m.id == targetMemberId,
      orElse: () => config.members.isNotEmpty
          ? config.members.first
          : MemberConfig(id: targetMemberId ?? 'guest', name: targetMemberId ?? 'Member'),
    );

    final summaries = BalanceEngine.calculateMemberSummaries(data, config);
    final userSummary = summaries[member.id] ??
        MemberFinancialSummary(
          memberId: member.id,
          totalPaid: 0.0,
          totalConsumed: 0.0,
          netBalance: 0.0,
        );

    final net = userSummary.netBalance;
    final isPositive = net >= 0;

    final timelineItems = BalanceEngine.calculatePersonTimeline(data, config, member.id);

    final isOwnProfile = memberId == null || memberId == storage.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isOwnProfile ? 'My Profile' : '${member.name}\'s Profile',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: theme.brightness == Brightness.dark ? 'Switch to Light Mode' : 'Switch to Dark/Night Mode',
            onPressed: () => storage.toggleTheme(context),
          ),
          if (isOwnProfile)
            TextButton.icon(
              icon: const Icon(Icons.switch_account_outlined, size: 18),
              label: const Text('Switch'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Header Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPositive
                    ? [const Color(0xFF047857), const Color(0xFF10B981)]
                    : [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                      .withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '@${member.id}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPositive
                      ? (isOwnProfile ? 'You are owed / To Receive' : 'To Receive (Credit)')
                      : (isOwnProfile ? 'You owe the fund' : 'Owes the Fund (Debit)'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  FormatUtils.formatCurrency(net.abs(), config.currency),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 18),
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
                            'Credits (Given)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FormatUtils.formatCurrency(userSummary.totalPaid, config.currency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 28, width: 1, color: Colors.white.withOpacity(0.2)),
                      Column(
                        children: [
                          Text(
                            'Debits (Consumed)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FormatUtils.formatCurrency(userSummary.totalConsumed, config.currency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
          const SizedBox(height: 20),

          // Transaction History section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOwnProfile
                        ? 'Your Transactions (${timelineItems.length})'
                        : '${member.name}\'s Transactions (${timelineItems.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Activity history and balances',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (timelineItems.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32.0),
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
                    'No transactions recorded for this member yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...timelineItems.map((item) {
              final isCredit = item.sign == '+';
              final isBalPositive = item.runningBalance >= 0;

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
                          transaction: item.transaction,
                          personId: member.id,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Icon Avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isCredit
                              ? const Color(0xFF10B981).withOpacity(0.15)
                              : const Color(0xFFEF4444).withOpacity(0.12),
                          child: Icon(
                            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isCredit ? const Color(0xFF047857) : const Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title, Date, and Type Badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 3,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    AppDateUtils.formatDisplayDate(item.transaction.date),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isCredit
                                          ? const Color(0xFF10B981).withOpacity(0.12)
                                          : theme.colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.displayType,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isCredit
                                            ? const Color(0xFF047857)
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Amount & Running Balance
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item.sign}${FormatUtils.formatCurrency(item.displayAmount, config.currency)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isCredit ? const Color(0xFF047857) : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isBalPositive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444))
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Bal: ${isBalPositive ? '+' : '-'}${FormatUtils.formatCurrency(item.runningBalance.abs(), config.currency)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isBalPositive
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFDC2626),
                                ),
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
