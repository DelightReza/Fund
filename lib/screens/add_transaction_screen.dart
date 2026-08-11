import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/date_utils.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.existingTransaction, this.initialType});
  
  final Transaction? existingTransaction;
  final TransactionType? initialType;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _type;
  String? _actor;
  String? _target;
  final Set<String> _participants = <String>{};
  
  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TransactionType.expense;
    
    final appState = ref.read(appStateProvider);
    final members = appState.config.people.where((p) => p.active).toList();
    
    if (widget.existingTransaction != null) {
      final tx = widget.existingTransaction!;
      _type = tx.type;
      _amountController.text = tx.amount.toString();
      _noteController.text = tx.note;
      _actor = tx.actorId;
      _target = tx.targetId;
      
      if (tx.participantIds.isNotEmpty) {
        _participants.addAll(tx.participantIds);
      } else if (tx.exemptions.isNotEmpty) {
        final activeIds = members.map((e) => e.id).toList();
        _participants.addAll(activeIds.where((id) => !tx.exemptions.contains(id)));
      }
    }
    
    if (_participants.isEmpty && _needsParticipants) {
      _participants.addAll(members.map((e) => e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final members = appState.config.people.where((p) => p.active).toList();
    final billTypes = appState.config.billTypes;

    return Scaffold(
      appBar: AppBar(title: Text(widget.existingTransaction == null ? 'Add Transaction' : 'Edit Transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<TransactionType>(
            value: _type,
            items: TransactionType.values
                .map((type) => DropdownMenuItem(value: type, child: Text(type.name.toUpperCase())))
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? TransactionType.expense),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 12),
          if (_needsActor)
            DropdownButtonFormField<String>(
              value: _actor,
              items: members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
              onChanged: (value) => setState(() => _actor = value),
              decoration: const InputDecoration(labelText: 'From / Actor'),
            ),
          if (_needsActor) const SizedBox(height: 12),
          if (_needsTarget)
            DropdownButtonFormField<String>(
              value: _target,
              items: (_type == TransactionType.debit || _type == TransactionType.expense)
                  ? billTypes.map((b) => DropdownMenuItem(value: b.id, child: Text('${b.icon} ${b.name}'))).toList()
                  : members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
              onChanged: (value) => setState(() => _target = value),
              decoration: InputDecoration(labelText: _type == TransactionType.debit || _type == TransactionType.expense ? 'Bill Type' : 'To'),
            ),
          if (_needsTarget) const SizedBox(height: 12),
          if (_needsParticipants)
            _ParticipantsSelector(
              members: members.map((e) => MapEntry(e.id, e.name)).toList(),
              selected: _participants,
              onToggle: (id) {
                setState(() {
                  if (_participants.contains(id)) {
                    _participants.remove(id);
                  } else {
                    _participants.add(id);
                  }
                });
              },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _save(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool get _needsActor => {
        TransactionType.expense,
        TransactionType.credit,
        TransactionType.settlement,
        TransactionType.transfer,
      }.contains(_type);

  bool get _needsTarget => {
        TransactionType.expense,
        TransactionType.debit,
        TransactionType.settlement,
        TransactionType.transfer,
      }.contains(_type);

  bool get _needsParticipants => {
        TransactionType.expense,
        TransactionType.debit,
        TransactionType.distribution,
      }.contains(_type);

  Future<void> _save(BuildContext context) async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError(context, 'Please enter a valid amount.');
      return;
    }

    if (_needsActor && (_actor == null || _actor!.isEmpty)) {
      _showError(context, 'Please select actor.');
      return;
    }

    if (_needsTarget && (_target == null || _target!.isEmpty)) {
      _showError(context, 'Please select target.');
      return;
    }

    if (_needsParticipants && _participants.isEmpty) {
      _showError(context, 'Please select at least one participant.');
      return;
    }

    final existing = widget.existingTransaction;
    final tx = Transaction(
      id: existing?.id ?? AppDateUtils.generateId(),
      type: _type,
      amount: amount,
      note: _noteController.text.trim(),
      actorId: _actor,
      targetId: _target,
      participantIds: _participants.toList(),
      exemptions: existing?.exemptions ?? const [],
      parentId: existing?.parentId,
      distributionTotal: existing?.distributionTotal,
      timestamp: existing?.timestamp ?? AppDateUtils.nowIso(),
    );

    if (existing != null) {
      await ref.read(appStateProvider.notifier).updateTransaction(
            tx,
            message: 'Edit ${_type.name} transaction (${tx.id})',
          );
    } else {
      await ref.read(appStateProvider.notifier).addTransaction(
            tx,
            message: 'Add ${_type.name} transaction (${tx.id})',
          );
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ParticipantsSelector extends StatelessWidget {
  const _ParticipantsSelector({
    required this.members,
    required this.selected,
    required this.onToggle,
  });

  final List<MapEntry<String, String>> members;
  final Set<String> selected;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Participants'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: members
              .map(
                (member) => FilterChip(
                  label: Text(member.value),
                  selected: selected.contains(member.key),
                  onSelected: (_) => onToggle(member.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
