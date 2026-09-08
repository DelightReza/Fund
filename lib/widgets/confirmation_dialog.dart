import 'package:flutter/material.dart';
import '../utils/date_utils.dart';
import '../utils/format_utils.dart';

class TransactionConfirmationDialog extends StatelessWidget {
  final String type; // 'expense', 'credit', 'debit', 'distribute', 'settlement', 'transfer'
  final double amount;
  final String currency;
  final String dateStr;
  final String? payerName;
  final String? categoryName;
  final String? categoryIcon;
  final String? fromName;
  final String? toName;
  final String note;
  final List<String> splitMembers;
  final List<String> exemptMembers;
  final Map<String, double>? customSplit;
  final Map<String, double>? splitPercentages;
  final Map<String, String>? memberNames;
  final bool isEditing;

  const TransactionConfirmationDialog({
    super.key,
    required this.type,
    required this.amount,
    required this.currency,
    required this.dateStr,
    this.payerName,
    this.categoryName,
    this.categoryIcon,
    this.fromName,
    this.toName,
    required this.note,
    this.splitMembers = const [],
    this.exemptMembers = const [],
    this.customSplit,
    this.splitPercentages,
    this.memberNames,
    required this.isEditing,
  });

  static Future<bool> show(
    BuildContext context, {
    required String type,
    required double amount,
    required String currency,
    required String dateStr,
    String? payerName,
    String? categoryName,
    String? categoryIcon,
    String? fromName,
    String? toName,
    required String note,
    List<String> splitMembers = const [],
    List<String> exemptMembers = const [],
    Map<String, double>? customSplit,
    Map<String, double>? splitPercentages,
    Map<String, String>? memberNames,
    required bool isEditing,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TransactionConfirmationDialog(
        type: type,
        amount: amount,
        currency: currency,
        dateStr: dateStr,
        payerName: payerName,
        categoryName: categoryName,
        categoryIcon: categoryIcon,
        fromName: fromName,
        toName: toName,
        note: note,
        splitMembers: splitMembers,
        exemptMembers: exemptMembers,
        customSplit: customSplit,
        splitPercentages: splitPercentages,
        memberNames: memberNames,
        isEditing: isEditing,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color themeColor;
    String typeLabel;
    IconData typeIcon;

    switch (type) {
      case 'credit':
        themeColor = const Color(0xFF10B981);
        typeLabel = 'Deposit into Fund';
        typeIcon = Icons.add_circle_outline_rounded;
        break;
      case 'debit':
        themeColor = const Color(0xFFEF4444);
        typeLabel = 'Direct Expense (Fund Debit)';
        typeIcon = Icons.remove_circle_outline_rounded;
        break;
      case 'distribute':
        themeColor = const Color(0xFF8B5CF6);
        typeLabel = 'Distribution (Refund / Dividend)';
        typeIcon = Icons.call_split_rounded;
        break;
      case 'settlement':
        themeColor = const Color(0xFF06B6D4);
        typeLabel = 'Debt Settlement';
        typeIcon = Icons.handshake_outlined;
        break;
      case 'transfer':
        themeColor = const Color(0xFF3B82F6);
        typeLabel = 'Member-to-Member Transfer';
        typeIcon = Icons.swap_horiz_rounded;
        break;
      default:
        themeColor = const Color(0xFFF59E0B);
        typeLabel = 'Grouped Expense';
        typeIcon = Icons.receipt_long_rounded;
    }

    final isCredit = type == 'credit';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: themeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Confirm Update' : 'Confirm Transaction',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Prominent Amount Display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeColor.withOpacity(0.25)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL AMOUNT',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isCredit ? '+' : (type == 'debit' || type == 'expense' ? '-' : '')}${FormatUtils.formatCurrency(amount, currency)}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isCredit ? const Color(0xFF047857) : (type == 'debit' || type == 'expense' ? const Color(0xFFDC2626) : theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Details Summary List
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildRow(
                      icon: Icons.access_time_rounded,
                      label: 'Date & Time',
                      value: AppDateUtils.formatDisplayDate(dateStr),
                    ),
                    if (payerName != null) ...[
                      const Divider(height: 16),
                      _buildRow(
                        icon: Icons.person_rounded,
                        label: type == 'credit' ? 'Deposited By' : 'Paid By',
                        value: payerName!,
                      ),
                    ],
                    if (categoryName != null) ...[
                      const Divider(height: 16),
                      _buildRow(
                        icon: Icons.category_rounded,
                        label: 'Category',
                        value: '${categoryIcon ?? '🧾'} $categoryName',
                      ),
                    ],
                    if (fromName != null && toName != null) ...[
                      const Divider(height: 16),
                      _buildRow(
                        icon: Icons.arrow_forward_rounded,
                        label: 'From ➔ To',
                        value: '$fromName ➔ $toName',
                      ),
                    ],
                    if (note.trim().isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildRow(
                        icon: Icons.notes_rounded,
                        label: 'Note',
                        value: note.trim(),
                      ),
                    ],
                    if (customSplit != null && customSplit!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildRow(
                        icon: Icons.pie_chart_outline_rounded,
                        label: 'Split Mode',
                        value: 'Custom Split (${customSplit!.length} members)',
                        valueColor: themeColor,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: customSplit!.entries.map((entry) {
                            final name = memberNames?[entry.key] ?? entry.key;
                            final exactPct = splitPercentages?[entry.key] ??
                                (amount > 0 ? (entry.value / amount) * 100 : 0.0);
                            final pctStr = exactPct % 1.0 == 0.0
                                ? exactPct.toInt().toString()
                                : exactPct.toStringAsFixed(1);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${FormatUtils.formatCurrency(entry.value, currency)} ($pctStr%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: themeColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ] else if (splitMembers.isNotEmpty && (type == 'expense' || type == 'debit' || type == 'distribute')) ...[
                      const Divider(height: 16),
                      _buildRow(
                        icon: Icons.group_rounded,
                        label: type == 'distribute' ? 'Recipients' : 'Split Among',
                        value: '${splitMembers.length} active members (${FormatUtils.formatCurrency(amount / splitMembers.length, currency)}/person)',
                      ),
                    ],
                    if (exemptMembers.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildRow(
                        icon: Icons.person_off_rounded,
                        label: 'Exempt',
                        value: '${exemptMembers.length} excluded',
                        valueColor: Colors.amber.shade800,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please verify details before saving. This will update the fund ledger and balance calculations.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Back to Edit'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(isEditing ? Icons.check_circle_rounded : Icons.save_rounded, size: 18),
          label: Text(isEditing ? 'Confirm & Update' : 'Confirm & Save'),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class ActionConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final Widget? extraContent;

  const ActionConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.confirmColor = Colors.red,
    this.icon = Icons.warning_amber_rounded,
    this.extraContent,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    Color confirmColor = Colors.red,
    IconData icon = Icons.warning_amber_rounded,
    Widget? extraContent,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ActionConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        icon: icon,
        extraContent: extraContent,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: confirmColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: confirmColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            if (extraContent != null) ...[
              const SizedBox(height: 14),
              extraContent!,
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class TransactionSuccessDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String amount;
  final Color themeColor;

  const TransactionSuccessDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.themeColor = const Color(0xFF10B981),
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String amount,
    Color themeColor = const Color(0xFF10B981),
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Transaction Saved',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => TransactionSuccessDialog(
        title: title,
        subtitle: subtitle,
        amount: amount,
        themeColor: themeColor,
      ),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<TransactionSuccessDialog> createState() => _TransactionSuccessDialogState();
}

class _TransactionSuccessDialogState extends State<TransactionSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _iconScale;
  late Animation<double> _ringScale;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    _ringScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();

    // Auto dismiss after 1.2s
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.themeColor.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: widget.themeColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Checkmark Bloom
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing outer halo ring
                      Transform.scale(
                        scale: _ringScale.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.themeColor.withOpacity(0.15),
                          ),
                        ),
                      ),
                      // Core checkmark badge
                      Transform.scale(
                        scale: _iconScale.value,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                widget.themeColor,
                                widget.themeColor.withOpacity(0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.themeColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              if (widget.amount.isNotEmpty)
                Text(
                  widget.amount,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: widget.themeColor,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
