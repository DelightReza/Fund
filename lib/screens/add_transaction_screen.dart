import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/date_utils.dart';
import '../widgets/status_popup.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
    this.existingTransaction,
  });

  final TransactionType initialType;
  final Transaction? existingTransaction;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _actorId;
  String? _targetId;
  final Set<String> _selectedParticipants = <String>{};
  DateTime _selectedDateTime = DateTime.now();

  bool _saving = false;
  String? _linkedParentId;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    final existing = widget.existingTransaction;

    if (existing != null) {
      _amountController.text = existing.amount > 0 ? (existing.amount % 1 == 0 ? existing.amount.toInt().toString() : existing.amount.toStringAsFixed(2)) : ((-existing.amount) % 1 == 0 ? (-existing.amount).toInt().toString() : (-existing.amount).toStringAsFixed(2));
      _noteController.text = existing.note;
      _linkedParentId = existing.parentId;

      final dt = DateTime.tryParse(existing.date);
      if (dt != null) {
        _selectedDateTime = dt;
      }

      if (existing.parentId != null && existing.parentId!.startsWith('tx_exp')) {
        _type = TransactionType.expense;
      } else if (existing.parentId != null && existing.parentId!.startsWith('tx_dist')) {
        _type = TransactionType.distribution;
      } else if (existing.parentId != null && existing.parentId!.startsWith('tx_set')) {
        _type = TransactionType.settlement;
      } else if (existing.parentId != null && existing.parentId!.startsWith('tx_trf')) {
        _type = TransactionType.transfer;
      } else {
        _type = existing.type;
      }

      if (existing.isCredit) {
        _actorId = existing.whoOrBill;
      } else {
        _targetId = existing.whoOrBill;
      }

      if (existing.splitAmong != null && existing.splitAmong!.isNotEmpty) {
        _selectedParticipants.addAll(existing.splitAmong!);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(appStateProvider).config;
      final activePeople = config.people.where((p) => p.active).toList();

      if (_selectedParticipants.isEmpty) {
        setState(() {
          _selectedParticipants.addAll(activePeople.map((p) => p.id));
        });
      }

      if (_actorId == null && activePeople.isNotEmpty) {
        final currentUserId = ref.read(appStateProvider).userId;
        final defaultActor = activePeople.any((p) => p.id == currentUserId) ? currentUserId : activePeople.first.id;
        setState(() => _actorId = defaultActor);
      }

      if (_targetId == null) {
        if ((_type == TransactionType.expense || _type == TransactionType.debit) && config.billTypes.isNotEmpty) {
          setState(() => _targetId = config.billTypes.first.id);
        } else if ((_type == TransactionType.settlement || _type == TransactionType.transfer) && activePeople.length > 1) {
          final other = activePeople.firstWhere((p) => p.id != _actorId, orElse: () => activePeople.first);
          setState(() => _targetId = other.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final people = appState.config.people.where((p) => p.active).toList();
    final billTypes = appState.config.billTypes;
    final isEdit = widget.existingTransaction != null;

    final theme = Theme.of(context);
    final typeColor = _getTypeColor(_type);

    final amountVal = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final splitCount = _selectedParticipants.length;
    final perPerson = splitCount > 0 ? (amountVal / splitCount) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Transaction Type Selector (only on create)
          if (!isEdit) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _typeChip(TransactionType.expense, 'Quick Expense', Icons.receipt_long),
                  const SizedBox(width: 8),
                  _typeChip(TransactionType.credit, 'Credit (Deposit)', Icons.arrow_downward),
                  const SizedBox(width: 8),
                  _typeChip(TransactionType.debit, 'Debit (Bill)', Icons.arrow_upward),
                  const SizedBox(width: 8),
                  _typeChip(TransactionType.distribution, 'Distribute', Icons.call_split),
                  const SizedBox(width: 8),
                  _typeChip(TransactionType.settlement, 'Settlement', Icons.handshake),
                  const SizedBox(width: 8),
                  _typeChip(TransactionType.transfer, 'Transfer', Icons.swap_horiz),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Amount Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AMOUNT (${appState.config.currency})',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                    decoration: InputDecoration(
                      prefixText: '${appState.config.currency} ',
                      prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                      hintText: '0.00',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_requiresParticipants && splitCount > 0 && amountVal > 0) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Split among $splitCount members', style: theme.textTheme.bodySmall),
                        Text(
                          '${appState.config.currency} ${perPerson.toStringAsFixed(2)} / person',
                          style: TextStyle(fontWeight: FontWeight.bold, color: typeColor),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Actor / Payer Selection (if required)
          if (_requiresActor) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_actorLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: people.map((p) {
                        final isSel = _actorId == p.id;
                        return ChoiceChip(
                          avatar: CircleAvatar(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?')),
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

          // Target Selection (Category for expense/debit, or Member for settlement/transfer)
          if (_requiresTarget) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_targetLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
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
                        runSpacing: 8,
                        children: people.where((p) => p.id != _actorId).map((p) {
                          final isSel = _targetId == p.id;
                          return ChoiceChip(
                            avatar: CircleAvatar(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?')),
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

          // Participants / Exemptions Checklist (for split expenses / debits / distributions)
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
                        const Text('Split Among (Participants)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedParticipants.length == people.length) {
                                _selectedParticipants.clear();
                              } else {
                                _selectedParticipants.clear();
                                _selectedParticipants.addAll(people.map((p) => p.id));
                              }
                            });
                          },
                          child: Text(_selectedParticipants.length == people.length ? 'Deselect All' : 'Select All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: people.map((p) {
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
            const SizedBox(height: 16),
          ],

          // Note & Date/Time
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note / Description (Optional)',
                      hintText: 'e.g. Lunch at restaurant',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Transaction Date & Time'),
                    subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDateTime,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: typeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _saving ? null : () => _handleSave(context),
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload),
            label: Text(
              _saving
                  ? 'Pushing to GitHub...'
                  : (isEdit ? 'Update & Commit to GitHub' : 'Save & Push to GitHub'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _typeChip(TransactionType type, String label, IconData icon) {
    final isSelected = _type == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _type = type;
            final config = ref.read(appStateProvider).config;
            final activePeople = config.people.where((p) => p.active).toList();
            if ((_type == TransactionType.expense || _type == TransactionType.debit) && config.billTypes.isNotEmpty) {
              _targetId ??= config.billTypes.first.id;
            } else if ((_type == TransactionType.settlement || _type == TransactionType.transfer) && activePeople.length > 1) {
              _targetId = activePeople.firstWhere((p) => p.id != _actorId, orElse: () => activePeople.last).id;
            }
          });
        }
      },
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
        TransactionType.expense => 'Paid By (Who paid for the expense?)',
        TransactionType.settlement => 'From (Who sent the settlement?)',
        TransactionType.transfer => 'From (Source member)',
        _ => 'Member',
      };

  String get _targetLabel => switch (_type) {
        TransactionType.expense => 'Category (What bill type?)',
        TransactionType.debit => 'Category (What bill type?)',
        TransactionType.settlement => 'To (Who received the settlement?)',
        TransactionType.transfer => 'To (Destination member)',
        _ => 'Target',
      };

  Color _getTypeColor(TransactionType type) => switch (type) {
        TransactionType.credit => Colors.green,
        TransactionType.expense => Colors.blue,
        TransactionType.debit => Colors.orange,
        TransactionType.distribution => Colors.purple,
        TransactionType.settlement => Colors.teal,
        TransactionType.transfer => Colors.indigo,
      };

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _handleSave(BuildContext context) async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount > 0')));
      return;
    }

    if (_requiresActor && (_actorId == null || _actorId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a payer / source member')));
      return;
    }

    if (_requiresTarget && (_targetId == null || _targetId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category / destination')));
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
    final config = ref.read(appStateProvider).config;
    final actorName = config.people.where((p) => p.id == _actorId).map((p) => p.name).firstOrNull ?? _actorId ?? '-';
    final targetName = (_type == TransactionType.expense || _type == TransactionType.debit)
        ? (config.billTypes.where((b) => b.id == _targetId).map((b) => '${b.icon} ${b.name}').firstOrNull ?? _targetId ?? '-')
        : (config.people.where((p) => p.id == _targetId).map((p) => p.name).firstOrNull ?? _targetId ?? '-');

    final typeColor = _getTypeColor(_type);
    final splitCount = _selectedParticipants.length;
    final perPerson = splitCount > 0 ? (amount / splitCount) : amount;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm ${_type.name[0].toUpperCase()}${_type.name.substring(1)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('TOTAL AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor)),
                  const SizedBox(height: 4),
                  Text('${config.currency} ${amount.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: typeColor)),
                  if (_requiresParticipants && splitCount > 0) ...[
                    const SizedBox(height: 4),
                    Text('${config.currency} ${perPerson.toStringAsFixed(2)} / person ($splitCount paying)',
                        style: TextStyle(fontSize: 12, color: typeColor.withOpacity(0.85))),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_requiresActor) _dialogRow('Actor / Payer', actorName),
            if (_requiresTarget) _dialogRow('Target / Category', targetName),
            _dialogRow('Date', DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime)),
            if (_noteController.text.trim().isNotEmpty) _dialogRow('Note', _noteController.text.trim()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: typeColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Future<void> _executeSave(BuildContext context, double amount) async {
    setState(() => _saving = true);

    final isEdit = widget.existingTransaction != null;
    final nowIso = _selectedDateTime.toIso8601String();
    final config = ref.read(appStateProvider).config;
    final currency = config.currency;
    final noteRaw = _noteController.text.trim();

    String getPersonName(String? id) {
      if (id == null) return 'Unknown';
      final match = config.people.where((p) => p.id == id).toList();
      return match.isNotEmpty ? match.first.name : id;
    }

    String getBillTypeName(String? id) {
      if (id == null) return 'Unknown';
      final match = config.billTypes.where((b) => b.id == id).toList();
      return match.isNotEmpty ? match.first.name : id;
    }

    bool pushed = false;
    try {
      if (_type == TransactionType.expense) {
        final parentId = _linkedParentId ?? 'tx_exp_${DateTime.now().millisecondsSinceEpoch}';
        final payerName = getPersonName(_actorId);
        final billName = getBillTypeName(_targetId);
        final referenceName = noteRaw.isNotEmpty ? noteRaw : billName;

        final creditTx = Transaction(
          id: '${parentId}_credit',
          parentId: parentId,
          type: TransactionType.credit,
          whoOrBill: _actorId!,
          amount: amount,
          note: '$payerName paid for $referenceName',
          date: nowIso,
        );

        final debitTx = Transaction(
          id: '${parentId}_debit',
          parentId: parentId,
          type: TransactionType.debit,
          whoOrBill: _targetId!,
          amount: amount,
          note: '$referenceName is paid by $payerName',
          date: nowIso,
          splitAmong: _selectedParticipants.toList(),
        );

        final commitMsg = isEdit
            ? 'Edited Expense: $payerName paid $currency$amount for $billName ${noteRaw.isNotEmpty ? "($noteRaw) " : ""}- Split among ${_selectedParticipants.length}'
            : 'Expense: $payerName paid $currency$amount for $billName ${noteRaw.isNotEmpty ? "($noteRaw) " : ""}- Split among ${_selectedParticipants.length}';

        if (isEdit && _linkedParentId != null) {
          pushed = await ref.read(appStateProvider.notifier).updateGroupedExpense(
                parentId: parentId,
                newChildren: [debitTx, creditTx],
                message: commitMsg,
              );
        } else {
          pushed = await ref.read(appStateProvider.notifier).addMultipleTransactions(
                [debitTx, creditTx],
                message: commitMsg,
              );
        }
      } else if (_type == TransactionType.distribution) {
        final parentId = _linkedParentId ?? 'tx_dist_${DateTime.now().millisecondsSinceEpoch}';
        final participants = _selectedParticipants.toList();
        final shareAmount = amount / participants.length;

        final childCredits = participants.asMap().entries.map((entry) {
          final idx = entry.key;
          final pId = entry.value;
          return Transaction(
            id: '${parentId}_$idx',
            parentId: parentId,
            type: TransactionType.credit,
            whoOrBill: pId,
            amount: shareAmount,
            note: noteRaw.isNotEmpty ? noteRaw : 'From distribution',
            date: nowIso,
            distributionTotal: amount,
          );
        }).toList();

        final commitMsg = 'Distributed $currency$amount among ${participants.length} people ${noteRaw.isNotEmpty ? "for $noteRaw" : ""}';

        if (isEdit && _linkedParentId != null) {
          pushed = await ref.read(appStateProvider.notifier).updateGroupedExpense(
                parentId: parentId,
                newChildren: childCredits,
                message: commitMsg,
              );
        } else {
          pushed = await ref.read(appStateProvider.notifier).addMultipleTransactions(
                childCredits,
                message: commitMsg,
              );
        }
      } else if (_type == TransactionType.settlement) {
        final parentId = _linkedParentId ?? 'tx_set_${DateTime.now().millisecondsSinceEpoch}';
        final fromName = getPersonName(_actorId);
        final toName = getPersonName(_targetId);

        final payerTx = Transaction(
          id: '${parentId}_payer',
          parentId: parentId,
          type: TransactionType.credit,
          whoOrBill: _actorId!,
          amount: amount,
          note: noteRaw.isNotEmpty ? 'Settlement: $noteRaw' : 'Settlement to $toName',
          date: nowIso,
        );

        final rcvrTx = Transaction(
          id: '${parentId}_rcvr',
          parentId: parentId,
          type: TransactionType.credit,
          whoOrBill: _targetId!,
          amount: -amount,
          note: noteRaw.isNotEmpty ? 'Settlement: $noteRaw' : 'Settlement from $fromName',
          date: nowIso,
        );

        final commitMsg = 'Settlement: $fromName paid $currency$amount to $toName';

        if (isEdit && _linkedParentId != null) {
          pushed = await ref.read(appStateProvider.notifier).updateGroupedExpense(
                parentId: parentId,
                newChildren: [payerTx, rcvrTx],
                message: commitMsg,
              );
        } else {
          pushed = await ref.read(appStateProvider.notifier).addMultipleTransactions(
                [payerTx, rcvrTx],
                message: commitMsg,
              );
        }
      } else if (_type == TransactionType.transfer) {
        final parentId = _linkedParentId ?? 'tx_trf_${DateTime.now().millisecondsSinceEpoch}';
        final fromName = getPersonName(_actorId);
        final toName = getPersonName(_targetId);

        final senderTx = Transaction(
          id: '${parentId}_send',
          parentId: parentId,
          type: TransactionType.credit,
          whoOrBill: _actorId!,
          amount: -amount,
          note: noteRaw.isNotEmpty ? 'Transfer: $noteRaw' : 'Transfer to $toName',
          date: nowIso,
        );

        final rcptTx = Transaction(
          id: '${parentId}_rcpt',
          parentId: parentId,
          type: TransactionType.credit,
          whoOrBill: _targetId!,
          amount: amount,
          note: noteRaw.isNotEmpty ? 'Transfer: $noteRaw' : 'Transfer from $fromName',
          date: nowIso,
        );

        final commitMsg = 'Transfer: $fromName transferred $currency$amount to $toName';

        if (isEdit && _linkedParentId != null) {
          pushed = await ref.read(appStateProvider.notifier).updateGroupedExpense(
                parentId: parentId,
                newChildren: [senderTx, rcptTx],
                message: commitMsg,
              );
        } else {
          pushed = await ref.read(appStateProvider.notifier).addMultipleTransactions(
                [senderTx, rcptTx],
                message: commitMsg,
              );
        }
      } else if (_type == TransactionType.credit) {
        final personName = getPersonName(_actorId);
        final tx = Transaction(
          id: widget.existingTransaction?.id ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
          type: TransactionType.credit,
          whoOrBill: _actorId!,
          amount: amount,
          note: noteRaw,
          date: nowIso,
        );

        final commitMsg = isEdit
            ? 'Edited Credit: $personName ($currency$amount) ${noteRaw.isNotEmpty ? "for $noteRaw" : ""}'
            : 'Credit: $personName added $currency$amount ${noteRaw.isNotEmpty ? "for $noteRaw" : ""}';

        if (isEdit) {
          pushed = await ref.read(appStateProvider.notifier).updateTransaction(tx, message: commitMsg);
        } else {
          pushed = await ref.read(appStateProvider.notifier).addTransaction(tx, message: commitMsg);
        }
      } else if (_type == TransactionType.debit) {
        final billName = getBillTypeName(_targetId);
        final tx = Transaction(
          id: widget.existingTransaction?.id ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
          type: TransactionType.debit,
          whoOrBill: _targetId!,
          amount: amount,
          note: noteRaw,
          date: nowIso,
          splitAmong: _selectedParticipants.toList(),
        );

        final commitMsg = isEdit
            ? 'Edited Debit: $currency$amount used for $billName - Split among ${_selectedParticipants.length}'
            : 'Debit: $currency$amount used for $billName - Split among ${_selectedParticipants.length}';

        if (isEdit) {
          pushed = await ref.read(appStateProvider.notifier).updateTransaction(tx, message: commitMsg);
        } else {
          pushed = await ref.read(appStateProvider.notifier).addTransaction(tx, message: commitMsg);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (context.mounted) {
      final appStateAfter = ref.read(appStateProvider);
      // Grab the *root* navigator's context before popping. The screen's own
      // `context` becomes unmounted the instant its route is popped, so
      // showing a dialog on it afterwards can silently fail to appear —
      // which made push failures (and successes) invisible.
      final popupContext = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();

      if (pushed) {
        StatusPopup.show(
          popupContext,
          title: 'Committed to GitHub',
          message: 'Transaction saved and pushed to remote repository.',
          type: StatusPopupType.success,
          autoDismissDuration: const Duration(seconds: 3),
        );
      } else if (appStateAfter.error != null && appStateAfter.error!.isNotEmpty) {
        StatusPopup.show(
          popupContext,
          title: 'Push Failed (Saved Locally)',
          message: appStateAfter.error!,
          type: StatusPopupType.error,
        );
      } else if (appStateAfter.token == null || appStateAfter.token!.isEmpty) {
        StatusPopup.show(
          popupContext,
          title: 'Saved Locally',
          message: 'Saved to local device. Add a GitHub PAT in Admin to sync with remote repo.',
          type: StatusPopupType.info,
          autoDismissDuration: const Duration(seconds: 3),
        );
      }
    }
  }
}