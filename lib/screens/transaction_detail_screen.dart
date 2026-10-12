import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../models/transaction.dart';
import '../repositories/fund_repository.dart';
import '../services/storage_service.dart';
import '../utils/date_utils.dart';
import '../utils/debt_simplifier.dart';
import '../utils/format_utils.dart';
import '../widgets/admin_pat_modal.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/glass_container.dart';
import '../utils/web_route_helper.dart';
import '../utils/app_router.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;
  final String? personId;
  final String? returnRoute;
  final bool isRestoredAfterRefresh;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.personId,
    this.returnRoute,
    this.isRestoredAfterRefresh = false,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool _isDeleting = false;

  void _handleBack() {
    final target = widget.returnRoute ?? 'transactions';
    AppRouter.popOrNavigateTo(
      context,
      target,
      forceDirect: widget.isRestoredAfterRefresh,
    );
  }

  Future<void> _delete() async {
    final repo = context.read<FundRepository>();
    final config = repo.config ?? AppConfig();
    final tx = widget.transaction;
    final isGrouped = tx.parentId != null && tx.parentId!.isNotEmpty;

    final confirmed = await ActionConfirmationDialog.show(
      context,
      title: 'Delete Transaction?',
      confirmLabel: 'Permanently Delete',
      confirmColor: const Color(0xFFDC2626),
      icon: Icons.delete_forever_rounded,
      message: isGrouped
          ? 'This is a grouped expense. Deleting it will remove both the contributor payment and the bill expense records permanently from the ledger.'
          : 'Are you sure you want to delete this transaction record? This will update the fund ledger and recalculate balances.',
      extraContent: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tx.type.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                ),
                Text(
                  FormatUtils.formatCurrency(tx.amount, config.currency),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Date: ${AppDateUtils.formatDisplayDate(tx.date)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (tx.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Note: ${tx.note}',
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      final ok = await repo.deleteTransaction(widget.transaction);
      if (mounted) {
        setState(() => _isDeleting = false);
        if (ok) {
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete transaction')),
          );
        }
      }
    }
  }

  void _edit(TransactionModel tx, List<TransactionModel> siblings) async {
    TransactionModel? pairedDebit;
    if (tx.parentId != null) {
      pairedDebit = siblings.firstWhere((t) => t.type == 'debit', orElse: () => tx);
    }

    final currentTxRoute = widget.returnRoute != null
        ? WebRouteHelper.buildTxRouteFromReturnRoute(widget.transaction.id, widget.returnRoute!)
        : 'tx?id=${widget.transaction.id}';
    final editRoute = 'add_tx?from=${Uri.encodeComponent(currentTxRoute)}';
    WebRouteHelper.setRoute(editRoute);
    context.read<StorageService>().pushRoute(editRoute);

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          existingTransaction: tx,
          pairedExpenseTransaction: pairedDebit,
          returnRoute: currentTxRoute,
        ),
      ),
    );

    if (updated == true && mounted) {
      _handleBack();
    } else if (mounted) {
      WebRouteHelper.setRoute(currentTxRoute);
      context.read<StorageService>().setLastRoute(currentTxRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<FundRepository>();
    final storage = context.watch<StorageService>();
    final config = repo.config ?? AppConfig();
    final data = repo.data ?? FundData();
    final isAdminVerified = storage.isAdminVerified;

    final tx = widget.transaction;
    final isCredit = tx.type == 'credit';

    List<TransactionModel> groupSiblings = [];
    if (tx.parentId != null && tx.parentId!.isNotEmpty) {
      groupSiblings = data.transactions.where((t) => t.parentId == tx.parentId).toList();
    }

    final payerMember = tx.payerId != null && tx.payerId!.isNotEmpty
        ? config.members.firstWhere(
            (m) => m.id == tx.payerId,
            orElse: () => MemberConfig(id: tx.payerId!, name: tx.payerId!),
          )
        : null;

    final billCategory = tx.billTypeId != null && tx.billTypeId!.isNotEmpty
        ? config.billTypes.firstWhere(
            (b) => b.id == tx.billTypeId,
            orElse: () => BillTypeConfig(id: tx.billTypeId!, name: tx.billTypeId!, icon: '🧾'),
          )
        : null;

    final debitSibling = tx.parentId != null
        ? groupSiblings.firstWhere((t) => t.type == 'debit', orElse: () => tx)
        : null;
    final activeCustomSplit = tx.customSplit ?? debitSibling?.customSplit;
    final hasCustomSplit = activeCustomSplit != null && activeCustomSplit.isNotEmpty;

    final splitMembers = hasCustomSplit
        ? activeCustomSplit.keys.toList()
        : (tx.splitAmong ??
            debitSibling?.splitAmong ??
            config.members.where((m) => m.active).map((m) => m.id).toList());

    final perPersonSplit = splitMembers.isNotEmpty ? (tx.amount / splitMembers.length) : 0.0;

    // Focused member for balance stats (only shown when inspecting a specific member's timeline)
    final targetPersonId = widget.personId;
    MemberConfig? focusedMember;
    Map<String, double>? balanceStats;

    if (targetPersonId != null) {
      focusedMember = config.members.firstWhere(
        (m) => m.id == targetPersonId,
        orElse: () => MemberConfig(id: targetPersonId, name: targetPersonId),
      );

      final allMemberIds = config.members.map((m) => m.id).toList();
      balanceStats = BalanceEngine.calculatePersonRunningBalanceForTx(
        data.transactions,
        tx.id,
        targetPersonId,
        allMemberIds,
      );
    }

    final personChange = balanceStats?['personShare'] ?? 0.0;
    final isPersonInvolved = personChange != 0.0;
    final personBalBefore = balanceStats?['balanceBefore'] ?? 0.0;
    final personBalAfter = balanceStats?['balanceAfter'] ?? 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to previous page',
            onPressed: _handleBack,
          ),
          title: const Text('Transaction Details'),
        actions: [
          // Only show edit & delete actions when admin write access is verified
          if (isAdminVerified) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(tx, groupSiblings),
              tooltip: 'Edit Transaction',
            ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    )
                  : const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isDeleting ? null : _delete,
              tooltip: 'Delete Transaction',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.shield_outlined, color: Colors.amber),
              tooltip: 'Unlock Admin to Edit',
              onPressed: () => AdminPatModal.show(context),
            ),
          ],
        ],
      ),
      body: AuroraBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Liquid Glass Header Card
                  GlassContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isCredit ? const Color(0xFF047857) : const Color(0xFFDC2626),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCredit ? 'CREDIT / DEPOSIT' : 'DEBIT / EXPENSE',
                            style: TextStyle(
                              color: isCredit ? const Color(0xFF047857) : const Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        FormatUtils.formatCurrency(tx.amount, config.currency),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: isCredit ? const Color(0xFF047857) : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppDateUtils.formatDisplayDate(tx.date),
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Focused Person's Running Balance & Impact Card (if involved)
                if (focusedMember != null && isPersonInvolved) ...[
                  const SizedBox(height: 16),
                  GlassContainer(
                    borderRadius: 20,
                    blur: 16,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                              child: Text(
                                focusedMember.name.isNotEmpty ? focusedMember.name[0] : '?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${focusedMember.name}\'s Balance Statement',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: personChange >= 0
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${personChange >= 0 ? '+' : '-'}${FormatUtils.formatCurrency(personChange.abs(), config.currency)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: personChange >= 0
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'Balance Before',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${personBalBefore >= 0 ? '+' : '-'}${FormatUtils.formatCurrency(personBalBefore.abs(), config.currency)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: personBalBefore >= 0
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            Column(
                              children: [
                                const Text(
                                  'Balance After',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${personBalAfter >= 0 ? '+' : '-'}${FormatUtils.formatCurrency(personBalAfter.abs(), config.currency)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: personBalAfter >= 0
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // General Information Liquid Glass Card
                GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Description', tx.note.isNotEmpty ? tx.note : '—'),
                      const Divider(height: 24),
                      _buildDetailRow('Reference Code', tx.whoOrBill.isNotEmpty ? tx.whoOrBill : '—'),
                      if (payerMember != null) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Paid By', '${payerMember.name} (@${tx.payerId})'),
                      ],
                      if (billCategory != null) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Category', '${billCategory.icon} ${billCategory.name}'),
                      ],
                      const Divider(height: 24),
                      _buildDetailRow('Transaction ID', tx.id, isMonospace: true),
                    ],
                  ),
                ),

                // Split Details Breakdown Liquid Glass Card
                if (!isCredit || (tx.parentId != null && tx.parentId!.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                hasCustomSplit ? 'Custom Split Breakdown' : 'Split Breakdown',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              hasCustomSplit
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Custom / Unequal',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      '${FormatUtils.formatCurrency(perPersonSplit, config.currency)} / person',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Participants (${splitMembers.length}):',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: splitMembers.map((id) {
                              final memberObj = config.members.firstWhere(
                                (m) => m.id == id,
                                orElse: () => MemberConfig(id: id, name: id),
                              );
                              final isTarget = id == targetPersonId;
                              final memberShare = hasCustomSplit
                                  ? (activeCustomSplit[id] ?? 0.0)
                                  : perPersonSplit;
                              final pct = tx.amount > 0 ? (memberShare / tx.amount) * 100 : 0.0;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isTarget
                                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      child: Text(
                                        memberObj.name.isNotEmpty ? memberObj.name[0] : '?',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        memberObj.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isTarget ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (hasCustomSplit)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Text(
                                          '(${pct.toStringAsFixed(1)}%)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '-${FormatUtils.formatCurrency(memberShare, config.currency)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
    ),
  );
}

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
