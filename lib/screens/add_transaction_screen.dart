
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/transaction.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  final String? defaultType;

  const AddTransactionScreen({super.key, this.transactionId, this.defaultType});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  String _type = 'expense';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedId = '';
  String _fromId = '';
  String _toId = '';
  List<String> _exemptions = [];
  DateTime _dateTime = DateTime.now();
  bool _customDate = false;

  late List<String> _peopleIds;
  late List<String> _billTypeIds;

  @override
  void initState() {
    super.initState();
    final config = ref.read(configProvider);
    _peopleIds = config.people.map((p) => p.id).toList();
    _billTypeIds = config.billTypes.map((b) => b.id).toList();
    _type = widget.defaultType ?? 'expense';
    if (widget.transactionId != null) {
      // Load existing transaction for edit
      final data = ref.read(dataProvider);
      final tx = data.transactions.firstWhere((t) => t.id == widget.transactionId);
      if (tx != null) {
        _type = tx.type;
        _amountController.text = tx.amount.toString();
        _noteController.text = tx.note;
        _selectedId = tx.whoOrBill;
        _fromId = tx.payerId ?? '';
        _toId = tx.billTypeId ?? '';
        _exemptions = tx.exemptions ?? [];
        _dateTime = DateTime.parse(tx.date);
        _customDate = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final data = ref.watch(dataProvider);
    final activePeople = config.people.where((p) => p.active).toList();
    final activeBillTypes = config.billTypes;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionId == null ? 'Add Transaction' : 'Edit Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selection
            Wrap(
              spacing: 8,
              children: [
                _buildTypeChip('expense', Icons.flash_on),
                _buildTypeChip('credit', Icons.arrow_downward),
                _buildTypeChip('debit', Icons.arrow_upward),
                _buildTypeChip('distribute', Icons.group),
                _buildTypeChip('settlement', Icons.handshake),
                _buildTypeChip('transfer', Icons.swap_horiz),
              ],
            ),
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (${config.currency})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // Dynamic fields based on type
            _buildDynamicFields(),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Date picker
            Row(
              children: [
                const Text('Custom date:'),
                const SizedBox(width: 8),
                Checkbox(
                  value: _customDate,
                  onChanged: (val) => setState(() => _customDate = val!),
                ),
                if (_customDate)
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dateTime,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_dateTime),
                          );
                          if (time != null) {
                            setState(() {
                              _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('yyyy-MM-dd HH:mm').format(_dateTime)),
                      ),
                    ),
                  )
                else
                  const Text('Now'),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveTransaction,
              child: Text(widget.transactionId == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, IconData icon) {
    return FilterChip(
      selected: _type == type,
      label: Text(type.toUpperCase()),
      onSelected: (sel) => setState(() => _type = type),
      avatar: Icon(icon, size: 18),
    );
  }

  Widget _buildDynamicFields() {
    final config = ref.watch(configProvider);
    final activePeople = config.people.where((p) => p.active).toList();

    switch (_type) {
      case 'expense':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _fromId.isEmpty ? null : _fromId,
              items: activePeople.map((p) {
                return DropdownMenuItem(value: p.id, child: Text(p.name));
              }).toList(),
              onChanged: (val) => setState(() => _fromId = val!),
              decoration: const InputDecoration(labelText: 'Paid By'),
            ),
            DropdownButtonFormField<String>(
              value: _toId.isEmpty ? null : _toId,
              items: config.billTypes.map((b) {
                return DropdownMenuItem(value: b.id, child: Text('${b.icon} ${b.name}'));
              }).toList(),
              onChanged: (val) => setState(() => _toId = val!),
              decoration: const InputDecoration(labelText: 'Bill Type'),
            ),
            _buildExemptions(activePeople),
          ],
        );
      case 'credit':
        return DropdownButtonFormField<String>(
          value: _selectedId.isEmpty ? null : _selectedId,
          items: activePeople.map((p) {
            return DropdownMenuItem(value: p.id, child: Text(p.name));
          }).toList(),
          onChanged: (val) => setState(() => _selectedId = val!),
          decoration: const InputDecoration(labelText: 'Person'),
        );
      case 'debit':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedId.isEmpty ? null : _selectedId,
              items: config.billTypes.map((b) {
                return DropdownMenuItem(value: b.id, child: Text('${b.icon} ${b.name}'));
              }).toList(),
              onChanged: (val) => setState(() => _selectedId = val!),
              decoration: const InputDecoration(labelText: 'Bill Type'),
            ),
            _buildExemptions(activePeople),
          ],
        );
      case 'distribute':
        return _buildExemptions(activePeople);
      case 'settlement':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _fromId.isEmpty ? null : _fromId,
              items: activePeople.map((p) {
                return DropdownMenuItem(value: p.id, child: Text(p.name));
              }).toList(),
              onChanged: (val) => setState(() => _fromId = val!),
              decoration: const InputDecoration(labelText: 'From (Payer)'),
            ),
            DropdownButtonFormField<String>(
              value: _toId.isEmpty ? null : _toId,
              items: activePeople.map((p) {
                return DropdownMenuItem(value: p.id, child: Text(p.name));
              }).toList(),
              onChanged: (val) => setState(() => _toId = val!),
              decoration: const InputDecoration(labelText: 'To (Receiver)'),
            ),
          ],
        );
      case 'transfer':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _fromId.isEmpty ? null : _fromId,
              items: activePeople.map((p) {
                return DropdownMenuItem(value: p.id, child: Text(p.name));
              }).toList(),
              onChanged: (val) => setState(() => _fromId = val!),
              decoration: const InputDecoration(labelText: 'From'),
            ),
            DropdownButtonFormField<String>(
              value: _toId.isEmpty ? null : _toId,
              items: activePeople.map((p) {
                return DropdownMenuItem(value: p.id, child: Text(p.name));
              }).toList(),
              onChanged: (val) => setState(() => _toId = val!),
              decoration: const InputDecoration(labelText: 'To'),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildExemptions(List<MemberConfig> activePeople) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Exclude from split:'),
        Wrap(
          spacing: 8,
          children: activePeople.map((p) {
            return FilterChip(
              label: Text(p.name),
              selected: _exemptions.contains(p.id),
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _exemptions.add(p.id);
                  } else {
                    _exemptions.remove(p.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _saveTransaction() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final date = _customDate ? DateUtils.fromLocalDateTime(_dateTime) : DateUtils.now();
    final config = ref.read(configProvider);
    final data = ref.read(dataProvider);
    final storage = ref.read(storageProvider);
    final token = ref.read(authProvider);
    final syncService = ref.read(syncServiceProvider);

    String parentId = '';

    try {
      switch (_type) {
        case 'expense':
          parentId = 'tx_exp_${DateTime.now().millisecondsSinceEpoch}';
          final creditTx = Transaction(
            id: '${parentId}_credit',
            type: 'credit',
            payerId: _fromId,
            whoOrBill: _fromId,
            amount: amount,
            note: '${_fromId} paid for ${_noteController.text}',
            date: date,
            parentId: parentId,
          );
          final activeIds = config.people.where((p) => p.active).map((p) => p.id).toList();
          final splitAmong = activeIds.where((id) => !_exemptions.contains(id)).toList();
          final debitTx = Transaction(
            id: '${parentId}_debit',
            type: 'debit',
            billTypeId: _toId,
            whoOrBill: _toId,
            amount: amount,
            note: '${_noteController.text} is paid by ${_fromId}',
            date: date,
            parentId: parentId,
            splitAmong: splitAmong,
          );
          await syncService.addTransaction(creditTx);
          await syncService.addTransaction(debitTx);
          break;

        case 'credit':
          final tx = Transaction(
            id: DateUtils.generateId(),
            type: 'credit',
            payerId: _selectedId,
            whoOrBill: _selectedId,
            amount: amount,
            note: _noteController.text,
            date: date,
          );
          await syncService.addTransaction(tx);
          break;

        case 'debit':
          final activeIds = config.people.where((p) => p.active).map((p) => p.id).toList();
          final splitAmong = activeIds.where((id) => !_exemptions.contains(id)).toList();
          final tx = Transaction(
            id: DateUtils.generateId(),
            type: 'debit',
            billTypeId: _selectedId,
            whoOrBill: _selectedId,
            amount: amount,
            note: _noteController.text,
            date: date,
            splitAmong: splitAmong,
          );
          await syncService.addTransaction(tx);
          break;

        case 'distribute':
          final activeIds = config.people.where((p) => p.active).map((p) => p.id).toList();
          final participants = activeIds.where((id) => !_exemptions.contains(id)).toList();
          final perPerson = amount / participants.length;
          parentId = 'tx_dist_${DateTime.now().millisecondsSinceEpoch}';
          for (int i = 0; i < participants.length; i++) {
            final tx = Transaction(
              id: '${parentId}_$i',
              type: 'credit',
              payerId: participants[i],
              whoOrBill: participants[i],
              amount: perPerson,
              note: _noteController.text,
              date: date,
              parentId: parentId,
              distributionTotal: amount,
            );
            await syncService.addTransaction(tx);
          }
          break;

        case 'settlement':
          parentId = 'tx_set_${DateTime.now().millisecondsSinceEpoch}';
          final payerTx = Transaction(
            id: '${parentId}_payer',
            type: 'credit',
            payerId: _fromId,
            whoOrBill: _fromId,
            amount: amount,
            note: 'Settlement to ${_toId}${_noteController.text.isNotEmpty ? ': ${_noteController.text}' : ''}',
            date: date,
            parentId: parentId,
          );
          final receiverTx = Transaction(
            id: '${parentId}_rcvr',
            type: 'credit',
            payerId: _toId,
            whoOrBill: _toId,
            amount: -amount,
            note: 'Settlement from ${_fromId}${_noteController.text.isNotEmpty ? ': ${_noteController.text}' : ''}',
            date: date,
            parentId: parentId,
          );
          await syncService.addTransaction(payerTx);
          await syncService.addTransaction(receiverTx);
          break;

        case 'transfer':
          parentId = 'tx_trf_${DateTime.now().millisecondsSinceEpoch}';
          final sendTx = Transaction(
            id: '${parentId}_send',
            type: 'credit',
            payerId: _fromId,
            whoOrBill: _fromId,
            amount: -amount,
            note: 'Transfer to ${_toId}${_noteController.text.isNotEmpty ? ': ${_noteController.text}' : ''}',
            date: date,
            parentId: parentId,
          );
          final receiveTx = Transaction(
            id: '${parentId}_rcpt',
            type: 'credit',
            payerId: _toId,
            whoOrBill: _toId,
            amount: amount,
            note: 'Transfer from ${_fromId}${_noteController.text.isNotEmpty ? ': ${_noteController.text}' : ''}',
            date: date,
            parentId: parentId,
          );
          await syncService.addTransaction(sendTx);
          await syncService.addTransaction(receiveTx);
          break;
      }

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

