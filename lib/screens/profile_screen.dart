import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/providers.dart';
import '../services/calculations.dart';
import '../theme/colors.dart';
import '../utils/format_utils.dart';
import 'transaction_detail_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final balances = ref.watch(balancesProvider);

    final matchedMembers = appState.config.people.where((p) => p.id == memberId).toList();
    final member = matchedMembers.isEmpty ? null : matchedMembers.first;
    final memberName = member?.name ?? memberId;
    final initial = memberName.isNotEmpty ? memberName[0].toUpperCase() : '?';

    final activeIds = appState.config.people.where((m) => m.active).map((m) => m.id).toList();

    // Filter transactions involving this user
    final related = appState.data.transactions.where((tx) {
      if (tx.actorId == memberId || tx.targetId == memberId) return true;
      if (tx.participantIds.contains(memberId)) return true;
      if (tx.participantIds.isEmpty && tx.exemptions.isNotEmpty && !tx.exemptions.contains(memberId)) return true;
      if (tx.participantIds.isEmpty && tx.exemptions.isEmpty && activeIds.contains(memberId)) return true;
      return false;
    }).toList();

    // Sort oldest to newest for running balance calculation
    DateTime parseTxTime(Transaction tx) => DateTime.tryParse(tx.timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    related.sort((a, b) => parseTxTime(a).compareTo(parseTxTime(b)));

    double runningBalance = 0.0;
    double totalDepositedOrPaid = 0.0;
    double totalConsumedOrDebited = 0.0;

    final balanceMap = <String, double>{};
    for (final tx in related) {
      final impact = Calculations.impactForMember(tx, memberId, activeIds: activeIds);
      runningBalance += impact;
      balanceMap[tx.id] = runningBalance;

      if (impact > 0) {
        totalDepositedOrPaid += impact;
      } else if (impact < 0) {
        totalConsumedOrDebited += impact.abs();
      }
    }

    // Sort back to newest first for display
    related.sort((a, b) => parseTxTime(b).compareTo(parseTxTime(a)));

    final netBal = balances[memberId] ?? 0.0;
    final isPositive = netBal >= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('$memberName\'s Profile'),
        actions: [
          IconButton(
            tooltip: 'Switch Profile',
            icon: const Icon(Icons.switch_account_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Switch Active Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      ...appState.config.people.map((p) => ListTile(
                        leading: CircleAvatar(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?')),
                        title: Text(p.name),
                        selected: p.id == memberId,
                        onTap: () {
                          ref.read(appStateProvider.notifier).selectUser(p.id);
                          Navigator.pop(ctx);
                        },
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPositive
                    ? [AppColors.emerald800, AppColors.emerald900]
                    : [AppColors.rose800, AppColors.rose900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Text(
                        initial,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memberName,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Net Standing: ${FormatUtils.currency(netBal, appState.config.currency)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Paid / In', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '+${FormatUtils.currency(totalDepositedOrPaid, appState.config.currency)}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: Colors.white24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Consumed / Out', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '-${FormatUtils.currency(totalConsumedOrDebited, appState.config.currency)}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction Audit & Running Ledger',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${related.length} entries',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (related.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No transactions recorded for $memberName yet.', style: const TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            ...related.map((tx) {
              final impact = Calculations.impactForMember(tx, memberId, activeIds: activeIds);
              final afterBal = balanceMap[tx.id] ?? 0.0;
              final beforeBal = afterBal - impact;
              final isImpPos = impact >= 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isImpPos ? AppColors.emerald100 : AppColors.rose100,
                    child: Icon(
                      isImpPos ? Icons.add : Icons.remove,
                      size: 16,
                      color: isImpPos ? AppColors.emerald800 : AppColors.rose800,
                    ),
                  ),
                  title: Text(
                    tx.note.isNotEmpty ? tx.note : tx.type.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Impact: ${isImpPos ? "+" : ""}${FormatUtils.currency(impact, appState.config.currency)}',
                    style: TextStyle(
                      color: isImpPos ? AppColors.emerald700 : AppColors.rose700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'After: ${FormatUtils.currency(afterBal, appState.config.currency)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Before: ${FormatUtils.currency(beforeBal, appState.config.currency)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(
                        transactionId: tx.id,
                        focusedMemberId: memberId,
                        runningBalanceBefore: beforeBal,
                        runningBalanceAfter: afterBal,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
