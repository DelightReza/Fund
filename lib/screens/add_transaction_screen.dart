import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/date_utils.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.initialType,
    this.existingTransaction,
  });

  final TransactionType? initialType;
  final Transaction? existingTransaction;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _GroupedSubItem {
  _GroupedSubItem({
    required this.amountController,
    required this.noteController,
    required this.categoryId,
  });

  final TextEditingController amountController;
  final TextEditingController noteController;
  String categoryId;

  void dispose() {
    amountController.dispose();
    noteController.dispose();
  }
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _actorId;
  String? _targetId;
  final Set<String> _selectedParticipants = {};
  bool _saving = false;

  // Grouped expense state
  bool _isGroupedExpense = false;
  final List<_GroupedSubItem> _subItems = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    final appConfig = ref.read(appStateProvider).config;
    final activePeople = appConfig.people.where((p) => p.active).toList();

    if (existing != null) {
      _type = existing.type;
      _amountController.text = existing.amount.toString();
      _noteController.text = existing.note;
      _actorId = existing.actorId;
      _targetId = existing.targetId;
      _selectedParticipants.addAll(
        existing.participantIds.isNotEmpty 
          ? existing.participantIds 
          : activePeople.map((p) => p.id),
      );
    } else {
      _type = widget.initialType ?? TransactionType.expense;
      if (activePeople.isNotEmpty) {
        _actorId = activePeople.first.id;
        _selectedParticipants.addAll(activePeople.map((p) => p.id));
      }
      final billTypes = appConfig.billTypes;
      if (billTypes.isNotEmpty) {
        _targetId = billTypes.first.id;
      }
    }
  }

  void _addSubItem() {
    final billTypes = ref.read(appStateProvider).config.billTypes;
    final defaultCategory = billTypes.isNotEmpty ? billTypes.first.id : 'others';
    setState(() {
      _subItems.add(_GroupedSubItem(
        amountController: TextEditingController(),
        noteController: TextEditingController(),
        categoryId: defaultCategory,
      ));
    });
  }

  void _removeSubItem(int index) {
    setState(() {
      _subItems[index].dispose();
      _subItems.removeAt(index);
    });
    _recalculateGroupedTotal();
  }

  void _recalculateGroupedTotal() {
    if (!_isGroupedExpense) return;
    double total = 0.0;
    for (final item in _subItems) {
      total += double.tryParse(item.amountController.text.trim()) ?? 0.0;
    }
    if (total > 0) {
      _amountController.text = total.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    for (final item in _subItems) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final people = appState.config.people;
    final billTypes = appState.config.billTypes;
    final activePeople = people.where((p) => p.active).toList();

    final isEdit = widget.existingTransaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Transaction' : 'New Transaction Entry'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'TRANSACTION TYPE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TransactionType.values.map((t) {
                final isSelected = _type == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.name.toUpperCase()),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _type = t;
                          if (_type != TransactionType.expense) {
                            _isGroupedExpense = false;
                          }
                          if (_requiresActor && (_actorId == null || _actorId!.isEmpty)) {
                            if (activePeople.isNotEmpty) _actorId = activePeople.first.id;
                          }
                          if (_requiresTarget) {
                            if (_type == TransactionType.expense || _type == TransactionType.debit) {
                              if (billTypes.isNotEmpty && (billTypes.every((b) => b.id != _targetId))) {
                                _targetId = billTypes.first.id;
                              }
                            } else {
                              if (activePeople.isNotEmpty && (activePeople.every((p) => p.id != _targetId))) {
                                _targetId = activePeople.first.id;
                              }
                            }
                          }
                          if (_requiresParticipants && _selectedParticipants.isEmpty) {
                            _selectedParticipants.addAll(activePeople.map((p) => p.id));
                          }
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          if (_type == TransactionType.expense && !isEdit) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Grouped Expense Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Split receipt across multiple items/categories under one transaction'),
              value: _isGroupedExpense,
              onChanged: (val) {
                setState(() {
                  _isGroupedExpense = val;
                  if (val && _subItems.isEmpty) {
                    _addSubItem();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
          ],
          if (!_isGroupedExpense) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Amount (${appState.config.currency})',
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note / Description',
                        hintText: 'e.g. Grocery shopping, Electricity bill...',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Receipt / Overall Note',
                        hintText: 'e.g. Supermarket Trip (Items itemized below)',
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SUB-ITEMS (${_subItems.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _addSubItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._subItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: item.amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Amount (${appState.config.currency})',
                                      prefixIcon: const Icon(Icons.attach_money, size: 18),
                                    ),
                                    onChanged: (_) => _recalculateGroupedTotal(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    value: item.categoryId,
                                    isDense: true,
                                    decoration: const InputDecoration(labelText: 'Category', isDense: true),
                                    items: billTypes.map((b) => DropdownMenuItem(
                                      value: b.id,
                                      child: Text('${b.icon} ${b.name}'),
                                    )).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => item.categoryId = val);
                                    },
                                  ),
                                ),
                                if (_subItems.length > 1) ...[
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => _removeSubItem(idx),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: item.noteController,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Item Description',
                                hintText: 'e.g. Milk & Eggs',
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Calculated Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '${appState.config.currency} ${_amountController.text.isEmpty ? "0.00" : _amountController.text}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_requiresActor) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _actorLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: activePeople.map((p) {
                        final isSel = _actorId == p.id;
                        return ChoiceChip(
                          avatar: CircleAvatar(child: Text(p.name[0])),
                          label: Text(p.name),
                          selected: isSel,
                          onSelected: (sel) {
                            if (sel) setState(() => _actorId = p.id);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_requiresTarget && !_isGroupedExpense) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _targetLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    if (_type == TransactionType.expense || _type == TransactionType.debit) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: billTypes.map((b) {
                          final isSel = _targetId == b.id;
                          return ChoiceChip(
                            label: Text('${b.icon} ${b.name}'),
                            selected: isSel,
                            onSelected: (sel) {
                              if (sel) setState(() => _targetId = b.id);
                            },
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        children: activePeople.map((p) {
                          final isSel = _targetId == p.id;
                          return ChoiceChip(
                            avatar: CircleAvatar(child: Text(p.name[0])),
                            label: Text(p.name),
                            selected: isSel,
                            onSelected: (sel) {
                              if (sel) setState(() => _targetId = p.id);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_requiresParticipants) ...[
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
                          'SPLIT AMONG PARTICIPANTS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedParticipants.length == activePeople.length) {
                                _selectedParticipants.clear();
                              } else {
                                _selectedParticipants.addAll(activePeople.map((p) => p.id));
                              }
                            });
                          },
                          child: Text(_selectedParticipants.length == activePeople.length ? 'Deselect All' : 'Select All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: activePeople.map((p) {
                        final isSel = _selectedParticipants.contains(p.id);
                        return FilterChip(
                          avatar: CircleAvatar(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?')),
                          label: Text(p.name),
                          selected: isSel,
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _selectedParticipants.add(p.id);
                              } else {
                                _selectedParticipants.remove(p.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _saving ? null : () => _save(context),
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload),
            label: Text(_saving ? 'Pushing to GitHub...' : (isEdit ? 'Update & Sync to GitHub' : 'Save & Push to GitHub')),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool get _requiresActor => const {
        TransactionType.credit,
        TransactionType.expense,
        TransactionType.settlement,
        TransactionType.transfer,
      }.contains(_type);

  bool get _requiresTarget => const {
        TransactionType.debit,
        TransactionType.expense,
        TransactionType.settlement,
        TransactionType.transfer,
      }.contains(_type);

  bool get _requiresParticipants => const {
        TransactionType.debit,
        TransactionType.expense,
        TransactionType.distribution,
      }.contains(_type);

  String get _actorLabel => switch (_type) {
        TransactionType.credit => 'Payer (Who deposited into fund?)',
        TransactionType.expense => 'Paid By (Who paid out-of-pocket?)',
        TransactionType.settlement => 'Payer (Who gave the money?)',
        TransactionType.transfer => 'From (Source member)',
        _ => 'Actor / Payer',
      };

  String get _targetLabel => switch (_type) {
        TransactionType.expense => 'Category (What was paid for?)',
        TransactionType.debit => 'Category (What bill?)',
        TransactionType.settlement => 'Receiver (Who received the settlement?)',
        TransactionType.transfer => 'To (Destination member)',
        _ => 'Target',
      };

  Future<void> _save(BuildContext context) async {
    _recalculateGroupedTotal();
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount greater than 0')));
      return;
    }

    if (_requiresActor && (_actorId == null || _actorId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an actor / payer')));
      return;
    }

    if (_requiresTarget && !_isGroupedExpense && (_targetId == null || _targetId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a target / category')));
      return;
    }

    if (_requiresParticipants && _selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one participant')));
      return;
    }

    setState(() => _saving = true);

    final existing = widget.existingTransaction;
    final parentId = existing?.id ?? AppDateUtils.generateId();
    final nowIso = existing?.timestamp ?? AppDateUtils.nowIso();

    bool pushed = false;
    try {
      if (_isGroupedExpense && _subItems.isNotEmpty) {
        final childTransactions = <Transaction>[];
        for (final item in _subItems) {
          final itemAmount = double.tryParse(item.amountController.text.trim()) ?? 0.0;
          if (itemAmount <= 0) continue;
          childTransactions.add(
            Transaction(
              id: AppDateUtils.generateId(),
              type: TransactionType.expense,
              amount: itemAmount,
              actorId: _actorId,
              targetId: item.categoryId,
              participantIds: _selectedParticipants.toList(),
              note: item.noteController.text.trim().isNotEmpty 
                  ? item.noteController.text.trim() 
                  : _noteController.text.trim(),
              timestamp: nowIso,
              parentId: parentId,
              distributionTotal: amount,
            ),
          );
        }

        if (childTransactions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid sub-item amounts')));
          setState(() => _saving = false);
          return;
        }

        // Add all sub transactions
        for (final childTx in childTransactions) {
          pushed = await ref.read(appStateProvider.notifier).addTransaction(
            childTx,
            message: 'Add grouped sub-item (${childTx.id})',
          );
        }
      } else {
        final tx = Transaction(
          id: parentId,
          type: _type,
          amount: amount,
          actorId: _requiresActor ? _actorId : null,
          targetId: _requiresTarget ? _targetId : null,
          participantIds: _requiresParticipants ? _selectedParticipants.toList() : [],
          note: _noteController.text.trim(),
          timestamp: nowIso,
        );

        if (existing != null) {
          pushed = await ref.read(appStateProvider.notifier).updateTransaction(
                tx,
                message: 'Edit ${_type.name} transaction (${tx.id})',
              );
        } else {
          pushed = await ref.read(appStateProvider.notifier).addTransaction(
                tx,
                message: 'Add ${_type.name} transaction (${tx.id})',
              );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (context.mounted) {
      if (pushed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Saved and pushed directly to GitHub!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally! (Configure PAT to push to GitHub)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      Navigator.of(context).pop();
    }
  }
}
