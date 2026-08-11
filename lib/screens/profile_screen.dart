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

    // Filter transactions involving this user
    final related = appState.data.transactions.where((tx) {
      if (tx.actorId == memberId || tx.targetId == memberId) return true;
      return tx.participantIds.contains(memberId);
    }).toList();

    // Ensure they are sorted oldest to newest for running balance calculation
    related.sort((a, b) => a.date.compareTo(b.date));

    double runningBalance = 0.0;
    final balanceMap = <String, double>{};
    for (final tx in related) {
      runningBalance += _impactForMember(tx, memberId);
      balanceMap[tx.id] = runningBalance;
    }

    // Sort back to newest first for display
    related.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text(member?.name ?? memberId)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Net: ${FormatUtils.currency(balances[memberId] ?? 0, appState.config.currency)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Transaction History & Running Balance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...related.map((tx) {
            final impact = _impactForMember(tx, memberId);
            final afterBal = balanceMap[tx.id] ?? 0.0;
            final beforeBal = afterBal - impact;
            return ListTile(
              title: Text(tx.note.isNotEmpty ? tx.note : tx.type.name.toUpperCase()),
              subtitle: Text('Impact: ${FormatUtils.currency(impact, appState.config.currency)}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'After: ${FormatUtils.currency(afterBal, appState.config.currency)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Before: ${FormatUtils.currency(beforeBal, appState.config.currency)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TransactionDetailScreen(
                  transactionId: tx.id,
                  focusedMemberId: memberId,
                  runningBalanceBefore: beforeBal,
                  runningBalanceAfter: afterBal,
                )),
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
