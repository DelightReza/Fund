import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../widgets/receipt_modal.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedMember;
  DateTime? _startDate;
  DateTime? _endDate;
  int _limit = 20;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    String resolveMember(String? id) {
      if (id == null || id.isEmpty) return '';
      final matched = appState.config.people.where((p) => p.id == id).toList();
      return matched.isEmpty ? id : matched.first.name;
    }

    String resolveBill(String? id) {
      if (id == null || id.isEmpty) return '';
      final matched = appState.config.billTypes.where((b) => b.id == id).toList();
      final bill = matched.isEmpty ? null : matched.first;
      return bill == null ? id : '${bill.icon} ${bill.name}';
    }

    var transactions = appState.data.transactions;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      transactions = transactions.where((tx) {
        return tx.note.toLowerCase().contains(q) ||
            resolveMember(tx.actorId).toLowerCase().contains(q) ||
            resolveMember(tx.targetId).toLowerCase().contains(q) ||
            resolveBill(tx.targetId).toLowerCase().contains(q);
      }).toList();
    }
    if (_selectedCategory != null) {
      transactions = transactions.where((tx) => tx.type == TransactionType.expense && tx.targetId == _selectedCategory).toList();
    }
    if (_selectedMember != null) {
      transactions = transactions.where((tx) => 
        tx.actorId == _selectedMember || 
        tx.targetId == _selectedMember || 
        tx.participantIds.contains(_selectedMember)
      ).toList();
    }
    if (_startDate != null) {
      transactions = transactions.where((tx) {
        final txDate = DateTime.tryParse(tx.timestamp);
        if (txDate == null) return false;
        return !txDate.isBefore(_startDate!);
      }).toList();
    }
    if (_endDate != null) {
      transactions = transactions.where((tx) {
        final txDate = DateTime.tryParse(tx.timestamp);
        if (txDate == null) return false;
        return txDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    final hasMore = transactions.length > _limit;
    final visibleTransactions = transactions.take(_limit).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search notes, names...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownButton<String?>(
                        value: _selectedCategory,
                        hint: const Text('Category'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Categories')),
                          ...appState.config.billTypes.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                        ],
                        onChanged: (val) => setState(() => _selectedCategory = val),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String?>(
                        value: _selectedMember,
                        hint: const Text('Member'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Members')),
                          ...appState.config.people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                        ],
                        onChanged: (val) => setState(() => _selectedMember = val),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_startDate == null && _endDate == null 
                          ? 'Dates' 
                          : '${_startDate != null ? "${_startDate!.month}/${_startDate!.day}" : "..."} - ${_endDate != null ? "${_endDate!.month}/${_endDate!.day}" : "..."}'
                        ),
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: (_startDate != null && _endDate != null) ? DateTimeRange(start: _startDate!, end: _endDate!) : null,
                          );
                          if (range != null) {
                            setState(() {
                              _startDate = range.start;
                              _endDate = range.end;
                            });
                          }
                        },
                      ),
                      if (_startDate != null || _endDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() {
                            _startDate = null;
                            _endDate = null;
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: visibleTransactions.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == visibleTransactions.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: FilledButton.tonal(
                        onPressed: () => setState(() => _limit += 20),
                        child: const Text('Load More'),
                      ),
                    ),
                  );
                }

                final tx = visibleTransactions[index];
                return Dismissible(
                  key: Key(tx.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete transaction?'),
                        content: const Text('Are you sure you want to delete this transaction?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    ref.read(appStateProvider.notifier).deleteTransaction(tx.id);
                  },
                  child: TransactionCard(
                    transaction: tx,
                    currency: appState.config.currency,
                    memberNameResolver: resolveMember,
                    billNameResolver: resolveBill,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: tx.id))),
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (_) => ReceiptModal(transaction: tx, currency: appState.config.currency),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
