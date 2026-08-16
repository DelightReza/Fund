import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/date_utils.dart';
import '../widgets/status_popup.dart';

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
  String? _groupedParentId;
  List<Transaction> _existingGroupedChildren = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    final appState = ref.read(appStateProvider);
    final appConfig = appState.config;
    final activePeople = appConfig.people.where((p) => p.active).toList();

    if (existing != null) {
      _type = existing.type;
      _actorId = existing.actorId;
      _targetId = existing.targetId;
      _selectedParticipants.addAll(
        existing.participantIds.isNotEmpty 
          ? existing.participantIds 
          : activePeople.map((p) => p.id),
      );

      // Check if this existing transaction is part of a grouped expense
      final parentId = (existing.parentId != null && existing.parentId!.isNotEmpty) ? existing.parentId : null;
      if (parentId != null) {
        _groupedParentId = parentId;
        final siblings = appState.data.transactions.where((t) => t.parentId == parentId).toList();
        if (siblings.isNotEmpty) {
          _existingGroupedChildren = siblings;
          _isGroupedExpense = true;
          final totalAmount = siblings.fold(0.0, (sum, t) => sum + t.amount);
          _amountController.text = totalAmount.toStringAsFixed(2);
          _noteController.text = siblings.first.note;
          for (final s in siblings) {
            _subItems.add(_GroupedSubItem(
              amountController: TextEditingController(text: s.amount.toString()),
              noteController: TextEditingController(text: s.note),
              categoryId: s.targetId ?? (appConfig.billTypes.isNotEmpty ? appConfig.billTypes.first.id : 'others'),
            ));
          }
        } else {
          _amountController.text = existing.amount.toString();
          _noteController.text = existing.note;
        }
      } else {
        _amountController.text = existing.amount.toString();
        _noteController.text = existing.note;
      }
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
        title: Text(
          isEdit 
            ? (_isGroupedExpense ? 'Edit Grouped Expense' : 'Edit Transaction') 
            : 'New Transaction Entry'
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isEdit || !_isGroupedExpense) ...[
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
          ],
          if (_type == TransactionType.expense && !isEdit) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Grouped Expense Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Split receipt across multiple items/categories under one transaction group'),
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
            onPressed: _saving ? null : () => _handleSavePressed(context),
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

  Future<void> _handleSavePressed(BuildContext context) async {
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

    final confirmed = await _showConfirmationDialog(context, amount);
    if (confirmed == true && mounted) {
      await _executeSave(context, amount);
    }
  }

  Future<bool?> _showConfirmationDialog(BuildContext context, double amount) {
    final appState = ref.read(appStateProvider);
    final config = appState.config;
    final actorName = config.people.where((p) => p.id == _actorId).map((p) => p.name).firstOrNull ?? _actorId ?? 'N/A';
    final targetName = config.billTypes.where((b) => b.id == _targetId).map((b) => b.name).firstOrNull ?? _targetId ?? 'N/A';
    final note = _noteController.text.trim();
    final isEdit = widget.existingTransaction != null;

    final typeColor = switch (_type) {
      TransactionType.credit => Colors.green,
      TransactionType.expense => Colors.blue,
      TransactionType.debit => Colors.orange,
      TransactionType.distribution => Colors.purple,
      TransactionType.settlement => Colors.teal,
      TransactionType.transfer => Colors.indigo,
    };

    final typeIcon = switch (_type) {
      TransactionType.credit => Icons.arrow_downward,
      TransactionType.expense => Icons.receipt_long,
      TransactionType.debit => Icons.arrow_upward,
      TransactionType.distribution => Icons.pie_chart,
      TransactionType.settlement => Icons.handshake,
      TransactionType.transfer => Icons.swap_horiz,
    };

    final splitCount = _selectedParticipants.length;
    final perPerson = splitCount > 0 ? (amount / splitCount) : amount;

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Confirm Transaction',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnim = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnim),
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Confirm Edit' : 'Confirm ${_type.name[0].toUpperCase()}${_type.name.substring(1)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isEdit ? 'Update transaction details' : 'Review before committing',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'AMOUNT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${config.currency} ${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: typeColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (_requiresParticipants && splitCount > 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${config.currency} ${perPerson.toStringAsFixed(2)} per person ($splitCount paying)',
                              style: TextStyle(fontSize: 12, color: typeColor.withOpacity(0.85), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_requiresActor)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              _type == TransactionType.expense ? 'Paid By: ' : 'Payer: ',
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            Expanded(
                              child: Text(
                                actorName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_requiresTarget && !_isGroupedExpense)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(Icons.category_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Category: ',
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            Expanded(
                              child: Text(
                                targetName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Note: ',
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_isGroupedExpense && _subItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${_subItems.length} category items in grouped breakdown',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: typeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isEdit ? 'Save Changes' : 'Confirm & Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeSave(BuildContext context, double amount) async {
    setState(() => _saving = true);

    final existing = widget.existingTransaction;
    final isEdit = existing != null;
    final parentId = _groupedParentId ?? existing?.parentId ?? existing?.id ?? AppDateUtils.generateId();
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

        if (isEdit && (_groupedParentId != null || existing?.parentId != null)) {
          pushed = await ref.read(appStateProvider.notifier).updateGroupedExpense(
            parentId: parentId,
            newChildren: childTransactions,
            message: 'Update grouped expense ($parentId)',
          );
        } else {
          pushed = await ref.read(appStateProvider.notifier).addGroupedExpense(
            parentId: parentId,
            children: childTransactions,
            message: 'Add grouped expense breakdown (${childTransactions.length} items)',
          );
        }
      } else if (_type == TransactionType.distribution && !isEdit) {
        // Kotlin/Android compatible distribution: creates linked credit entries for each participant
        final participants = _selectedParticipants.toList();
        final shareAmount = amount / participants.length;
        final distParentId = AppDateUtils.generateId();
        final childCredits = participants.map((pId) {
          return Transaction(
            id: AppDateUtils.generateId(),
            type: TransactionType.credit,
            amount: shareAmount,
            actorId: pId,
            note: _noteController.text.trim().isNotEmpty 
                ? _noteController.text.trim() 
                : 'Distribution share',
            timestamp: nowIso,
            parentId: distParentId,
            distributionTotal: amount,
            participantIds: participants,
          );
        }).toList();

        pushed = await ref.read(appStateProvider.notifier).addGroupedExpense(
          parentId: distParentId,
          children: childCredits,
          message: 'Distribute funds among ${participants.length} members',
        );
      } else {
        final tx = Transaction(
          id: existing?.id ?? parentId,
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
      final appStateAfter = ref.read(appStateProvider);
      final nav = Navigator.of(context);
      final parentContext = context;
      nav.pop();

      if (pushed) {
        StatusPopup.show(
          parentContext,
          title: 'Changes Pushed to GitHub',
          message: 'Transaction successfully saved and committed to remote repository.',
          type: StatusPopupType.success,
          autoDismissDuration: const Duration(seconds: 3),
        );
      } else if (appStateAfter.error != null && appStateAfter.error!.isNotEmpty) {
        StatusPopup.show(
          parentContext,
          title: 'Push Failed (Saved Locally)',
          message: appStateAfter.error!,
          type: StatusPopupType.error,
        );
      } else if (appStateAfter.token == null || appStateAfter.token!.isEmpty) {
        StatusPopup.show(
          parentContext,
          title: 'Saved to Local Queue',
          message: 'Saved locally. Add a GitHub PAT in the Admin panel to sync changes to GitHub.',
          type: StatusPopupType.info,
          autoDismissDuration: const Duration(seconds: 4),
        );
      } else {
        StatusPopup.show(
          parentContext,
          title: 'Queued for Sync',
          message: 'Saved locally and queued for synchronization.',
          type: StatusPopupType.info,
          autoDismissDuration: const Duration(seconds: 3),
        );
      }
    }
  }
}
