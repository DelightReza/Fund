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

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _actorId;
  String? _targetId;
  final Set<String> _selectedParticipants = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    if (existing != null) {
      _type = existing.type;
      _amountController.text = existing.amount.toString();
      _noteController.text = existing.note;
      _actorId = existing.actorId;
      _targetId = existing.targetId;
      _selectedParticipants.addAll(existing.participantIds);
    } else {
      _type = widget.initialType ?? TransactionType.expense;
      final people = ref.read(appStateProvider).config.people;
      if (people.isNotEmpty) {
        _actorId = people.first.id;
        _selectedParticipants.addAll(people.map((p) => p.id));
      }
      final billTypes = ref.read(appStateProvider).config.billTypes;
      if (billTypes.isNotEmpty) {
        _targetId = billTypes.first.id;
      }
    }
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
    final people = appState.config.people;
    final billTypes = appState.config.billTypes;

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
                      if (sel) setState(() => _type = t);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
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
                      children: people.map((p) {
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
          if (_requiresTarget) ...[
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
                        children: people.map((p) {
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
                              if (_selectedParticipants.length == people.length) {
                                _selectedParticipants.clear();
                              } else {
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
                      children: people.map((p) {
                        final isSel = _selectedParticipants.contains(p.id);
                        return FilterChip(
                          avatar: CircleAvatar(child: Text(p.name[0])),
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
        TransactionType.settlement => 'Payer (Who gave the money?)',
        TransactionType.transfer => 'From (Source member)',
        _ => 'Actor',
      };

  String get _targetLabel => switch (_type) {
        TransactionType.expense => 'Category (What was paid for?)',
        TransactionType.debit => 'Category (What bill?)',
        TransactionType.settlement => 'Receiver (Who received the settlement?)',
        TransactionType.transfer => 'To (Destination member)',
        _ => 'Target',
      };

  Future<void> _save(BuildContext context) async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount greater than 0')));
      return;
    }

    if (_requiresActor && (_actorId == null || _actorId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an actor / payer')));
      return;
    }

    if (_requiresTarget && (_targetId == null || _targetId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a target / category')));
      return;
    }

    if (_requiresParticipants && _selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one participant')));
      return;
    }

    setState(() => _saving = true);

    final existing = widget.existingTransaction;
    final tx = Transaction(
      id: existing?.id ?? AppDateUtils.generateId(),
      type: _type,
      amount: amount,
      actorId: _requiresActor ? _actorId : null,
      targetId: _requiresTarget ? _targetId : null,
      participantIds: _requiresParticipants ? _selectedParticipants.toList() : [],
      note: _noteController.text.trim(),
      timestamp: existing?.timestamp ?? AppDateUtils.nowIso(),
    );

    bool pushed = false;
    try {
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
