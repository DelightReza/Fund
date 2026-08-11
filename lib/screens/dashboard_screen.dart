
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../services/calculations.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';
import '../widgets/transaction_card.dart';
import '../widgets/member_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _searchQuery = '';
  String _filterCategory = 'all';
  String _dateFrom = '';
  String _dateTo = '';
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final data = ref.watch(dataProvider);
    final balances = ref.watch(balancesProvider);
    final totals = ref.watch(totalsProvider);

    // Filter transactions
    final filtered = data.transactions.where((tx) {
      // Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        String name = tx.whoOrBill;
        if (tx.type == 'credit') {
          name = config.people.firstWhere((p) => p.id == tx.whoOrBill,
              orElse: () => MemberConfig(id: tx.whoOrBill, name: tx.whoOrBill))
              .name;
        } else {
          name = config.billTypes.firstWhere((b) => b.id == tx.whoOrBill,
              orElse: () => BillTypeConfig(id: tx.whoOrBill, name: tx.whoOrBill, icon: ''))
              .name;
        }
        final match = tx.note.toLowerCase().contains(q) ||
            name.toLowerCase().contains(q) ||
            tx.amount.toString().contains(q);
        if (!match) return false;
      }

      // Category filter
      if (_filterCategory != 'all') {
        if (_filterCategory == 'credit' && tx.type != 'credit') return false;
        if (_filterCategory == 'debit' && tx.type != 'debit') return false;
        if (_filterCategory.startsWith('person_')) {
          final pid = _filterCategory.substring(7);
          if (tx.type != 'credit' || tx.whoOrBill != pid) return false;
        }
        if (_filterCategory.startsWith('bill_')) {
          final bid = _filterCategory.substring(5);
          if (tx.type != 'debit' || tx.whoOrBill != bid) return false;
        }
      }

      // Date range
      if (_dateFrom.isNotEmpty && tx.date.compareTo(_dateFrom) < 0) return false;
      if (_dateTo.isNotEmpty && tx.date.compareTo('$_dateTo 23:59:59') > 0) return false;

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(config.siteTitle),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Balance hero
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Balance', style: TextStyle(fontSize: 18)),
                      Text(config.currency),
                    ],
                  ),
                  Text(
                    '${FormatUtils.formatCurrency(totals.credits - totals.debits, config.currency)}',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Collected', style: TextStyle(color: Colors.grey[600])),
                          Text(
                            '+${FormatUtils.formatCurrency(totals.credits, config.currency)}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Spent', style: TextStyle(color: Colors.grey[600])),
                          Text(
                            '-${FormatUtils.formatCurrency(totals.debits, config.currency)}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Category breakdown (simple)
          if (data.billTypes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Bill Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: data.billTypes.entries.map((entry) {
                  final bill = config.billTypes.firstWhere(
                        (b) => b.id == entry.key,
                    orElse: () => BillTypeConfig(id: entry.key, name: entry.key, icon: ''),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Chip(
                      label: Text('${bill.icon} ${bill.name}: ${FormatUtils.formatCurrency(entry.value, config.currency)}'),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Member cards
          const SizedBox(height: 16),
          const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: config.people.length,
            itemBuilder: (context, index) {
              final person = config.people[index];
              final balance = balances[person.id] ?? 0.0;
              final credits = data.transactions
                  .where((t) => t.type == 'credit' && t.whoOrBill == person.id)
                  .fold(0.0, (sum, t) => sum + t.amount);
              return MemberCard(
                name: person.name,
                net: balance,
                given: credits,
                currency: config.currency,
                onTap: () {
                  context.go('/profile/${person.id}');
                },
              );
            },
          ),

          // Transaction list
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${filtered.length} entries'),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 8),
            _buildFilters(),
          ],
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final tx = filtered[index];
              String displayName;
              if (tx.type == 'credit') {
                final person = config.people.firstWhere(
                      (p) => p.id == tx.whoOrBill,
                  orElse: () => MemberConfig(id: tx.whoOrBill, name: tx.whoOrBill),
                );
                displayName = person.name;
              } else {
                final bill = config.billTypes.firstWhere(
                      (b) => b.id == tx.whoOrBill,
                  orElse: () => BillTypeConfig(id: tx.whoOrBill, name: tx.whoOrBill, icon: ''),
                );
                displayName = bill.icon + ' ' + bill.name;
              }
              return TransactionCard(
                transaction: tx,
                displayTitle: displayName,
                currency: config.currency,
                onTap: () => context.go('/transaction_detail/${tx.id}'),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final config = ref.watch(configProvider);
    final filterOptions = [
      'all',
      'credit',
      'debit',
      ...config.people.map((p) => 'person_${p.id}'),
      ...config.billTypes.map((b) => 'bill_${b.id}'),
    ];
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _filterCategory,
          items: filterOptions.map((opt) {
            String label = opt;
            if (opt == 'all') label = 'All';
            else if (opt == 'credit') label = 'Credits';
            else if (opt == 'debit') label = 'Debits';
            else if (opt.startsWith('person_')) {
              final pid = opt.substring(7);
              final p = config.people.firstWhere((p) => p.id == pid);
              label = '👤 ${p.name}';
            } else if (opt.startsWith('bill_')) {
              final bid = opt.substring(5);
              final b = config.billTypes.firstWhere((b) => b.id == bid);
              label = '🧾 ${b.name}';
            }
            return DropdownMenuItem(value: opt, child: Text(label));
          }).toList(),
          onChanged: (val) => setState(() => _filterCategory = val!),
          decoration: const InputDecoration(labelText: 'Category'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'From date'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _dateFrom = date.toIso8601String().split('T').first);
                  }
                },
                readOnly: true,
                controller: TextEditingController(text: _dateFrom),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'To date'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _dateTo = date.toIso8601String().split('T').first);
                  }
                },
                readOnly: true,
                controller: TextEditingController(text: _dateTo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _filterCategory = 'all';
                  _dateFrom = '';
                  _dateTo = '';
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ],
    );
  }
}

