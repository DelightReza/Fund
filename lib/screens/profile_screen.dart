import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/providers.dart';
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

    // Filter transactions involving this user
    final related = appState.data.transactions.where((tx) {
      if (tx.actorId == memberId || tx.targetId == memberId) return true;
      return tx.participantIds.contains(memberId);
    }).toList();

    // Sort oldest to newest for running balance calculation
    DateTime parseTxTime(Transaction tx) => DateTime.tryParse(tx.timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    related.sort((a, b) => parseTxTime(a).compareTo(parseTxTime(b)));

    double runningBalance = 0.0;
    final balanceMap = <String, double>{};
    for (final tx in related) {
      runningBalance += _impactForMember(tx, memberId);
      balanceMap[tx.id] = runningBalance;
    }

    // Sort back to newest first for display
    related.sort((a, b) => parseTxTime(b).compareTo(parseTxTime(a)));

    final netBal = balances[memberId] ?? 0.0;
    final isPositive = netBal >= 0;

    return Scaffold(
      appBar: AppBar(title: Text('$memberName\'s Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPositive
                    ? [Colors.emerald.shade800, Colors.emerald.shade900]
                    : [Colors.red.shade800, Colors.red.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
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
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Transaction Audit & Running Ledger',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...related.map((tx) {
            final impact = _impactForMember(tx, memberId);
            final afterBal = balanceMap[tx.id] ?? 0.0;
            final beforeBal = afterBal - impact;
            final isImpPos = impact >= 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: isImpPos ? Colors.emerald.shade100 : Colors.red.shade100,
                  child: Icon(
                    isImpPos ? Icons.add : Icons.remove,
                    size: 16,
                    color: isImpPos ? Colors.emerald.shade800 : Colors.red.shade800,
                  ),
                ),
                title: Text(
                  tx.note.isNotEmpty ? tx.note : tx.type.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Impact: ${FormatUtils.currency(impact, appState.config.currency)}'),
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

  double _impactForMember(Transaction tx, String memberId) {
    switch (tx.type) {
      case TransactionType.credit:
        return tx.actorId == memberId ? tx.amount : 0;
      case TransactionType.debit:
      case TransactionType.expense:
        if (!tx.participantIds.contains(memberId)) return 0;
        return -(tx.amount / tx.participantIds.length);
      case TransactionType.distribution:
        if (!tx.participantIds.contains(memberId)) return 0;
        return tx.amount / tx.participantIds.length;
      case TransactionType.settlement:
        if (tx.actorId == memberId) return tx.amount;
        if (tx.targetId == memberId) return -tx.amount;
        return 0;
      case TransactionType.transfer:
        if (tx.actorId == memberId) return -tx.amount;
        if (tx.targetId == memberId) return tx.amount;
        return 0;
    }
  }
}
