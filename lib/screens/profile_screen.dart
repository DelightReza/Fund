
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../services/calculations.dart';
import '../utils/format_utils.dart';
import '../utils/date_utils.dart';

class ProfileScreen extends ConsumerWidget {
  final String id;
  const ProfileScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final data = ref.watch(dataProvider);
    final balances = ref.watch(balancesProvider);
    final person = config.people.firstWhere((p) => p.id == id,
        orElse: () => MemberConfig(id: id, name: id));
    final netBalance = balances[id] ?? 0.0;
    final credits = data.transactions
        .where((t) => t.type == 'credit' && t.whoOrBill == id)
        .fold(0.0, (sum, t) => sum + t.amount);

    // Filter transactions involving this person
    final txs = data.transactions.where((tx) {
      if (tx.type == 'credit' && tx.whoOrBill == id) return true;
      if (tx.type == 'debit') {
        final payers = tx.splitAmong ?? [];
        if (payers.contains(id)) return true;
      }
      return false;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${person.name}\'s Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 50,
            child: Text(person.name[0].toUpperCase(), style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 12),
          Text(person.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Given'),
                          Text(FormatUtils.formatCurrency(credits, config.currency)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Net'),
                          Text(
                            FormatUtils.formatCurrency(netBalance, config.currency),
                            style: TextStyle(color: netBalance >= 0 ? Colors.green : Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...txs.map((tx) {
            final share = tx.type == 'debit'
                ? tx.amount / (tx.splitAmong?.length ?? 1)
                : tx.amount;
            return ListTile(
              title: Text(tx.type == 'credit' ? 'Credit' : 'Debit'),
              subtitle: Text(tx.note),
              trailing: Text(FormatUtils.formatCurrency(share, config.currency)),
              onTap: () => context.go('/transaction_detail/${tx.id}'),
            );
          }),
        ],
      ),
    );
  }
}

