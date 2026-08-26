import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/transaction.dart';
import '../repositories/fund_repository.dart';
import '../services/storage_service.dart';
import '../utils/date_utils.dart';
import '../widgets/confirmation_dialog.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? existingTransaction;
  final TransactionModel? pairedExpenseTransaction;
  final String? initialType;
  final String? initialBillTypeId;
  final int initialMode;

  const AddTransactionScreen({
    super.key,
    this.existingTransaction,
    this.pairedExpenseTransaction,
    this.initialType,
    this.initialBillTypeId,
    this.initialMode = 0,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // Types: "expense", "debit", "credit", "distribute", "settlement", "transfer"
  late String _type;

  String? _selectedPayerId;
  String? _selectedBillTypeId;
  String? _selectedFromId;
  String? _selectedToId;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedDate = AppDateUtils.todayString();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final Set<String> _exemptions = {}; // IDs exempt from split or distribution
  bool _isLoading = false;
  String? _error;

  // Scroll controllers & keys for auto-scrolling to selected items
  final ScrollController _payerScrollController = ScrollController();
  final ScrollController _billTypeScrollController = ScrollController();
  final ScrollController _fromScrollController = ScrollController();
  final ScrollController _toScrollController = ScrollController();

  final Map<String, GlobalKey> _payerChipKeys = {};
  final Map<String, GlobalKey> _billTypeChipKeys = {};
  final Map<String, GlobalKey> _fromChipKeys = {};
  final Map<String, GlobalKey> _toChipKeys = {};

  bool get isEditing => widget.existingTransaction != null;

  Color get _themeColor {
    switch (_type) {
      case 'credit':
        return const Color(0xFF10B981);
      case 'debit':
        return const Color(0xFFEF4444);
      case 'distribute':
        return const Color(0xFF8B5CF6);
      case 'settlement':
        return const Color(0xFF059669);
      case 'transfer':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  GlobalKey _getPayerKey(String id) => _payerChipKeys.putIfAbsent(id, () => GlobalKey());
  GlobalKey _getBillTypeKey(String id) => _billTypeChipKeys.putIfAbsent(id, () => GlobalKey());
  GlobalKey _getFromKey(String id) => _fromChipKeys.putIfAbsent(id, () => GlobalKey());
  GlobalKey _getToKey(String id) => _toChipKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _type = widget.initialType!;
    } else {
      switch (widget.initialMode) {
        case 1:
          _type = 'credit';
          break;
        case 2:
          _type = 'debit';
          break;
        case 3:
          _type = 'distribute';
          break;
        case 4:
          _type = 'settlement';
          break;
        case 5:
          _type = 'transfer';
          break;
        default:
          _type = 'expense';
      }
    }

    final repo = context.read<FundRepository>();
    final config = repo.config;

    final existing = widget.existingTransaction;
    if (existing != null) {
      _amountController.text = existing.amount % 1.0 == 0.0
          ? existing.amount.toInt().toString()
          : existing.amount.toString();
      _selectedDate = AppDateUtils.formatDateOnly(existing.date);
      _selectedTime = AppDateUtils.parseTimeOfDay(existing.date);

      if (existing.parentId != null && existing.parentId!.startsWith('tx_exp')) {
        _type = 'expense';
        final pairedDebit = widget.pairedExpenseTransaction ??
            repo.data?.transactions.firstWhere(
              (t) => t.parentId == existing.parentId && t.type == 'debit',
              orElse: () => existing,
            );
        final pairedCredit = repo.data?.transactions.firstWhere(
          (t) => t.parentId == existing.parentId && t.type == 'credit',
          orElse: () => existing,
        );

        _selectedPayerId = pairedCredit?.payerId ?? pairedCredit?.whoOrBill;
        _selectedBillTypeId = pairedDebit?.billTypeId ?? pairedDebit?.whoOrBill;

        // Clean user-entered note for grouped expense
        final rawNote = existing.note.trim();
        final billName = config?.billTypes
                .firstWhere(
                  (b) => b.id == _selectedBillTypeId,
                  orElse: () => BillTypeConfig(
                    id: _selectedBillTypeId ?? '',
                    name: _selectedBillTypeId ?? '',
                    icon: '',
                  ),
                )
                .name ??
            '';
        final payerName = config?.members
                .firstWhere(
                  (m) => m.id == _selectedPayerId,
                  orElse: () => MemberConfig(
                    id: _selectedPayerId ?? '',
                    name: _selectedPayerId ?? '',
                  ),
                )
                .name ??
            '';

        String cleanNote = rawNote;
        // Strip out auto-generated suffixes and prefixes
        if (cleanNote.contains(' is paid by ')) {
          cleanNote = cleanNote.split(' is paid by ').first.trim();
        }
        if (cleanNote.startsWith('$payerName paid for ')) {
          cleanNote = cleanNote.substring('$payerName paid for '.length).trim();
        } else if (cleanNote.contains(' paid for ')) {
          final idx = cleanNote.indexOf(' paid for ');
          cleanNote = cleanNote.substring(idx + ' paid for '.length).trim();
        }

        // If the clean note is identical to default bill category name, keep note field empty
        if (cleanNote == billName || cleanNote == _selectedBillTypeId) {
          _noteController.text = '';
        } else {
          _noteController.text = cleanNote;
        }

        if (pairedDebit?.splitAmong != null && config != null) {
          final allActive = config.members.where((m) => m.active).map((m) => m.id).toSet();
          final splitSet = pairedDebit!.splitAmong!.toSet();
          for (final mId in allActive) {
            if (!splitSet.contains(mId)) {
              _exemptions.add(mId);
            }
          }
        }
      } else if (existing.type == 'credit') {
        _type = 'credit';
        _noteController.text = existing.note;
        _selectedPayerId = existing.payerId ?? existing.whoOrBill;
      } else {
        _type = 'debit';
        _noteController.text = existing.note;
        _selectedBillTypeId = existing.billTypeId ?? existing.whoOrBill;
        if (existing.exemptions != null) {
          _exemptions.addAll(existing.exemptions!);
        }
      }

      // Automatically scroll to selected bill type and person when editing
      _scheduleAutoScroll();
    } else {
      // New transaction default setup:
      // Bill type and people are NOT selected by default.
      _selectedDate = AppDateUtils.todayString();
      _selectedTime = TimeOfDay.now();

      _selectedPayerId = null;
      _selectedFromId = null;
      _selectedToId = null;
      _selectedBillTypeId = widget.initialBillTypeId;

      if (_selectedBillTypeId != null) {
        _scheduleAutoScroll();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _payerScrollController.dispose();
    _billTypeScrollController.dispose();
    _fromScrollController.dispose();
    _toScrollController.dispose();
    super.dispose();
  }

  void _scheduleAutoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        _performAutoScroll();
      });
    });
  }

  void _performAutoScroll() {
    if (_selectedPayerId != null) {
      final key = _payerChipKeys[_selectedPayerId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    if (_selectedBillTypeId != null) {
      final key = _billTypeChipKeys[_selectedBillTypeId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    if (_selectedFromId != null) {
      final key = _fromChipKeys[_selectedFromId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    if (_selectedToId != null) {
      final key = _toChipKeys[_selectedToId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _setToCurrentDateTime() {
    setState(() {
      _selectedDate = AppDateUtils.todayString();
      _selectedTime = TimeOfDay.now();
    });
  }

  String _getFormattedDateTime() {
    final hh = _selectedTime.hour.toString().padLeft(2, '0');
    final mm = _selectedTime.minute.toString().padLeft(2, '0');
    return '$_selectedDate $hh:$mm';
  }

  Future<void> _submit() async {
    // Ensure keyboard is closed immediately when reviewing
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _error = null;
    });

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount greater than 0');
      return;
    }

    final repo = context.read<FundRepository>();
    final config = repo.config ?? AppConfig();
    final note = _noteController.text.trim();
    final fullDateTime = _getFormattedDateTime();

    // Prepare metadata for confirmation dialog
    String? payerName;
    String? categoryName;
    String? categoryIcon;
    String? fromName;
    String? toName;
    List<String> splitMembers = [];
    List<String> exemptMembers = _exemptions.toList();

    if (_type == 'expense') {
      if (_selectedPayerId == null || _selectedBillTypeId == null) {
        setState(() => _error = 'Please select a payer and a bill category');
        return;
      }
      payerName = config.members.firstWhere(
        (m) => m.id == _selectedPayerId,
        orElse: () => MemberConfig(id: _selectedPayerId!, name: _selectedPayerId!),
      ).name;
      final bill = config.billTypes.firstWhere(
        (b) => b.id == _selectedBillTypeId,
        orElse: () => BillTypeConfig(id: _selectedBillTypeId!, name: _selectedBillTypeId!, icon: '🧾'),
      );
      categoryName = bill.name;
      categoryIcon = bill.icon;

      final activeMembers = config.members.where((m) => m.active).map((m) => m.id).toList();
      splitMembers = activeMembers.where((id) => !_exemptions.contains(id)).toList();
    } else if (_type == 'credit') {
      if (_selectedPayerId == null) {
        setState(() => _error = 'Please select a member');
        return;
      }
      payerName = config.members.firstWhere(
        (m) => m.id == _selectedPayerId,
        orElse: () => MemberConfig(id: _selectedPayerId!, name: _selectedPayerId!),
      ).name;
    } else if (_type == 'debit') {
      if (_selectedBillTypeId == null) {
        setState(() => _error = 'Please select a bill category');
        return;
      }
      final bill = config.billTypes.firstWhere(
        (b) => b.id == _selectedBillTypeId,
        orElse: () => BillTypeConfig(id: _selectedBillTypeId!, name: _selectedBillTypeId!, icon: '🧾'),
      );
      categoryName = bill.name;
      categoryIcon = bill.icon;

      final activeMembers = config.members.where((m) => m.active).map((m) => m.id).toList();
      splitMembers = activeMembers.where((id) => !_exemptions.contains(id)).toList();
    } else if (_type == 'distribute') {
      final activeMembers = config.members.where((m) => m.active).map((m) => m.id).toList();
      splitMembers = activeMembers.where((id) => !_exemptions.contains(id)).toList();
      if (splitMembers.isEmpty) {
        setState(() => _error = 'At least one participant must be included in distribution');
        return;
      }
    } else if (_type == 'settlement' || _type == 'transfer') {
      if (_selectedFromId == null || _selectedToId == null || _selectedFromId == _selectedToId) {
        setState(() => _error = 'Please select different sender and receiver members');
        return;
      }
      fromName = config.members.firstWhere(
        (m) => m.id == _selectedFromId,
        orElse: () => MemberConfig(id: _selectedFromId!, name: _selectedFromId!),
      ).name;
      toName = config.members.firstWhere(
        (m) => m.id == _selectedToId,
        orElse: () => MemberConfig(id: _selectedToId!, name: _selectedToId!),
      ).name;
    }

    // Show Confirmation UI Dialog
    final confirmed = await TransactionConfirmationDialog.show(
      context,
      type: _type,
      amount: amount,
      currency: config.currency,
      dateStr: fullDateTime,
      payerName: payerName,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      fromName: fromName,
      toName: toName,
      note: note,
      splitMembers: splitMembers,
      exemptMembers: exemptMembers,
      isEditing: isEditing,
    );

    if (!confirmed) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool success = false;

      if (_type == 'expense') {
        if (isEditing && widget.existingTransaction?.parentId != null) {
          success = await repo.editQuickExpense(
            parentId: widget.existingTransaction!.parentId!,
            payerId: _selectedPayerId!,
            billTypeId: _selectedBillTypeId!,
            amount: amount,
            note: note,
            date: fullDateTime,
            exemptions: _exemptions.toList(),
          );
        } else {
          success = await repo.addQuickExpense(
            payerId: _selectedPayerId!,
            billTypeId: _selectedBillTypeId!,
            amount: amount,
            note: note,
            date: fullDateTime,
            exemptions: _exemptions.toList(),
          );
        }
      } else if (_type == 'credit') {
        if (isEditing) {
          success = await repo.editSingleTransaction(
            txId: widget.existingTransaction!.id,
            type: 'credit',
            payerId: _selectedPayerId!,
            amount: amount,
            note: note.isNotEmpty ? note : 'Deposit into fund',
            date: fullDateTime,
          );
        } else {
          success = await repo.addSingleTransaction(
            type: 'credit',
            payerId: _selectedPayerId!,
            amount: amount,
            note: note.isNotEmpty ? note : 'Deposit into fund',
            date: fullDateTime,
          );
        }
      } else if (_type == 'debit') {
        final activeMembers = config.members.where((m) => m.active).map((m) => m.id).toList();
        final splitAmong = activeMembers.where((id) => !_exemptions.contains(id)).toList();

        if (isEditing) {
          success = await repo.editSingleTransaction(
            txId: widget.existingTransaction!.id,
            type: 'debit',
            billTypeId: _selectedBillTypeId!,
            amount: amount,
            note: note.isNotEmpty ? note : 'Direct expense from fund',
            date: fullDateTime,
            splitAmong: splitAmong,
            exemptions: _exemptions.toList(),
          );
        } else {
          success = await repo.addSingleTransaction(
            type: 'debit',
            billTypeId: _selectedBillTypeId!,
            amount: amount,
            note: note.isNotEmpty ? note : 'Direct expense from fund',
            date: fullDateTime,
            splitAmong: splitAmong,
            exemptions: _exemptions.toList(),
          );
        }
      } else if (_type == 'distribute') {
        final activeMembers = config.members.where((m) => m.active).map((m) => m.id).toList();
        final participantIds = activeMembers.where((id) => !_exemptions.contains(id)).toList();

        success = await repo.addDistribution(
          totalAmount: amount,
          note: note,
          date: fullDateTime,
          participantIds: participantIds,
        );
      } else if (_type == 'settlement') {
        success = await repo.addSettlement(
          payerId: _selectedFromId!,
          receiverId: _selectedToId!,
          amount: amount,
          note: note,
          date: fullDateTime,
        );
      } else if (_type == 'transfer') {
        success = await repo.addTransfer(
          senderId: _selectedFromId!,
          recipientId: _selectedToId!,
          amount: amount,
          note: note,
          date: fullDateTime,
        );
      }

      if (mounted) {
        if (success) {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();

          final formattedAmt = '${config.currency}${amount.toStringAsFixed(amount % 1.0 == 0.0 ? 0 : 2)}';
          String subtitle = 'Saved to fund ledger';
          if (_type == 'expense') {
            subtitle = 'Quick expense recorded';
          } else if (_type == 'credit') {
            subtitle = 'Deposit recorded';
          } else if (_type == 'debit') {
            subtitle = 'Direct debit recorded';
          } else if (_type == 'distribute') {
            subtitle = 'Distribution recorded';
          } else if (_type == 'settlement') {
            subtitle = 'Debt settlement recorded';
          } else if (_type == 'transfer') {
            subtitle = 'Member transfer recorded';
          }

          await TransactionSuccessDialog.show(
            context,
            title: isEditing ? 'Transaction Updated!' : 'Transaction Recorded!',
            subtitle: subtitle,
            amount: formattedAmt,
            themeColor: _themeColor,
          );

          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() => _error = 'Failed to save transaction');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<FundRepository>();
    final config = repo.config ?? AppConfig();
    final members = config.members;
    final billTypes = config.billTypes;

    Color themeColor;
    switch (_type) {
      case 'credit':
        themeColor = const Color(0xFF10B981);
        break;
      case 'debit':
        themeColor = const Color(0xFFEF4444);
        break;
      case 'distribute':
        themeColor = const Color(0xFF8B5CF6);
        break;
      case 'settlement':
        themeColor = const Color(0xFF059669);
        break;
      case 'transfer':
        themeColor = const Color(0xFF2563EB);
        break;
      default:
        themeColor = const Color(0xFF3B82F6);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Transaction' : 'Record Transaction',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Horizontal Type Selector Chips
              if (!isEditing) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeChip('expense', 'Quick Expense', const Color(0xFF3B82F6), Icons.flash_on),
                      const SizedBox(width: 8),
                      _buildTypeChip('debit', 'Debit', const Color(0xFFEF4444), Icons.arrow_upward),
                      const SizedBox(width: 8),
                      _buildTypeChip('credit', 'Credit', const Color(0xFF10B981), Icons.arrow_downward),
                      const SizedBox(width: 8),
                      _buildTypeChip('distribute', 'Distribute', const Color(0xFF8B5CF6), Icons.people),
                      const SizedBox(width: 8),
                      _buildTypeChip('settlement', 'Settle Debt', const Color(0xFF059669), Icons.handshake),
                      const SizedBox(width: 8),
                      _buildTypeChip('transfer', 'Transfer', const Color(0xFF2563EB), Icons.swap_horiz),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Main Form Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Input
                      _buildSectionHeader('Amount (${config.currency})'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '${config.currency} ',
                          prefixStyle: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: themeColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: themeColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Contextual inputs based on transaction type
                      if (_type == 'expense') ...[
                        _buildSectionHeader('Payer (Who Paid?)'),
                        const SizedBox(height: 8),
                        _buildMemberSelector(
                          members,
                          _selectedPayerId,
                          (id) {
                            setState(() => _selectedPayerId = id);
                            _scheduleAutoScroll();
                          },
                          themeColor,
                          keyGetter: _getPayerKey,
                          scrollController: _payerScrollController,
                        ),
                        const SizedBox(height: 18),

                        _buildSectionHeader('Bill Category'),
                        const SizedBox(height: 8),
                        _buildBillTypeSelector(
                          billTypes,
                          _selectedBillTypeId,
                          (id) {
                            setState(() => _selectedBillTypeId = id);
                            _scheduleAutoScroll();
                          },
                          themeColor,
                          keyGetter: _getBillTypeKey,
                          scrollController: _billTypeScrollController,
                        ),
                        const SizedBox(height: 18),

                        _buildSectionHeader('Split Among Active Members'),
                        const SizedBox(height: 4),
                        const Text('Tap to toggle member inclusion in this expense', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        _buildExemptionToggles(members, themeColor),
                      ] else if (_type == 'credit') ...[
                        _buildSectionHeader('Depositing Member'),
                        const SizedBox(height: 8),
                        _buildMemberSelector(
                          members,
                          _selectedPayerId,
                          (id) {
                            setState(() => _selectedPayerId = id);
                            _scheduleAutoScroll();
                          },
                          themeColor,
                          keyGetter: _getPayerKey,
                          scrollController: _payerScrollController,
                        ),
                      ] else if (_type == 'debit') ...[
                        _buildSectionHeader('Bill Category (Debit from Fund)'),
                        const SizedBox(height: 8),
                        _buildBillTypeSelector(
                          billTypes,
                          _selectedBillTypeId,
                          (id) {
                            setState(() => _selectedBillTypeId = id);
                            _scheduleAutoScroll();
                          },
                          themeColor,
                          keyGetter: _getBillTypeKey,
                          scrollController: _billTypeScrollController,
                        ),
                        const SizedBox(height: 18),

                        _buildSectionHeader('Split Among Active Members'),
                        const SizedBox(height: 4),
                        const Text('Tap to toggle member inclusion in this debit', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        _buildExemptionToggles(members, themeColor),
                      ] else if (_type == 'distribute') ...[
                        _buildSectionHeader('Distribute Credit Equally Among'),
                        const SizedBox(height: 4),
                        const Text('Tap to include or exclude members from receiving this distribution', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        _buildExemptionToggles(members, themeColor, actionVerb: 'Receives'),
                      ] else if (_type == 'settlement' || _type == 'transfer') ...[
                        _buildSectionHeader(_type == 'settlement' ? 'Payer (Paying Settlement)' : 'Sender'),
                        const SizedBox(height: 8),
                        _buildMemberSelector(
                          members,
                          _selectedFromId,
                          (id) {
                            setState(() => _selectedFromId = id);
                            _scheduleAutoScroll();
                          },
                          themeColor,
                          keyGetter: _getFromKey,
                          scrollController: _fromScrollController,
                        ),
                        const SizedBox(height: 18),

                        _buildSectionHeader(_type == 'settlement' ? 'Receiver (Receiving Settlement)' : 'Recipient'),
                        const SizedBox(height: 8),
                        _buildMemberSelector(
                          members,
                          _selectedToId,
                          (id) {
                            setState(() => _selectedToId = id);
                            _scheduleAutoScroll();
                          },
                          themeColor,
                          keyGetter: _getToKey,
                          scrollController: _toScrollController,
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Description / Note Input
                      TextField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          labelText: 'Note / Description (Optional)',
                          hintText: _type == 'expense'
                              ? 'e.g. Dinner, Grocery, WiFi'
                              : _type == 'credit'
                                  ? 'e.g. Monthly contribution'
                                  : _type == 'distribute'
                                      ? 'e.g. Refund distribution'
                                      : 'e.g. Settlement payment',
                          prefixIcon: const Icon(Icons.description_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Date & Time Picker Section
                      _buildDateTimePickers(theme),
                    ],
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : Icon(isEditing ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded, size: 20),
                label: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        isEditing ? 'Review & Update' : 'Review & Save',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePickers(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Date & Time'),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: _setToCurrentDateTime,
              icon: const Icon(Icons.restore_rounded, size: 16),
              label: const Text('Set Now', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Date Picker Tile
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              AppDateUtils.formatDisplayDate(_selectedDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Time Picker Tile
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Time', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              AppDateUtils.formatTimeOfDay(_selectedTime, context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(String typeKey, String label, Color color, IconData icon) {
    final isSelected = _type == typeKey;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) {
        setState(() {
          _type = typeKey;
          _error = null;
        });
        _scheduleAutoScroll();
      },
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : color,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
    );
  }

  Widget _buildMemberSelector(
    List<MemberConfig> members,
    String? selectedId,
    Function(String) onSelect,
    Color activeColor, {
    GlobalKey Function(String)? keyGetter,
    ScrollController? scrollController,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: members.map((m) {
          final isSelected = selectedId == m.id;
          final key = keyGetter != null ? keyGetter(m.id) : null;
          return Padding(
            key: key,
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: CircleAvatar(
                radius: 12,
                backgroundColor: isSelected ? Colors.white24 : activeColor.withOpacity(0.15),
                child: Text(
                  m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : activeColor,
                  ),
                ),
              ),
              label: Text(m.name + (!m.active ? ' (Inactive)' : '')),
              selected: isSelected,
              selectedColor: activeColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => onSelect(m.id),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBillTypeSelector(
    List<BillTypeConfig> billTypes,
    String? selectedId,
    Function(String) onSelect,
    Color activeColor, {
    GlobalKey Function(String)? keyGetter,
    ScrollController? scrollController,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: billTypes.map((b) {
          final isSelected = selectedId == b.id;
          final key = keyGetter != null ? keyGetter(b.id) : null;
          return Padding(
            key: key,
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Text(b.icon, style: const TextStyle(fontSize: 16)),
              label: Text(b.name),
              selected: isSelected,
              selectedColor: activeColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => onSelect(b.id),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExemptionToggles(
    List<MemberConfig> members,
    Color activeColor, {
    String actionVerb = 'Included',
  }) {
    final activeMembers = members.where((m) => m.active).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: activeMembers.map((m) {
        final isIncluded = !_exemptions.contains(m.id);

        return FilterChip(
          selected: isIncluded,
          showCheckmark: false,
          avatar: CircleAvatar(
            radius: 10,
            backgroundColor: isIncluded ? Colors.white : Colors.grey.shade300,
            child: Text(
              m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isIncluded ? activeColor : Colors.grey.shade700,
              ),
            ),
          ),
          label: Text(m.name),
          selectedColor: activeColor.withOpacity(0.2),
          labelStyle: TextStyle(
            color: isIncluded ? activeColor : Colors.grey,
            fontWeight: isIncluded ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _exemptions.remove(m.id);
              } else {
                _exemptions.add(m.id);
              }
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isIncluded ? activeColor : Colors.grey.shade300,
            ),
          ),
        );
      }).toList(),
    );
  }
}
