import 'package:flutter/material.dart';
import '../../models/app_config.dart';
import '../../utils/format_utils.dart';

class CustomSplitAllocationSection extends StatelessWidget {
  final List<MemberConfig> members;
  final Set<String> exemptions;
  final TextEditingController amountController;
  final Color activeColor;
  final String currency;
  final String splitMode;
  final ValueChanged<String> onSplitModeChanged;
  final TextEditingController Function(String memberId) getController;
  final VoidCallback onDistributeEvenly;
  final VoidCallback onClearAll;
  final VoidCallback onSplitRemaining;
  final void Function(String memberId, bool included) onToggleExemption;
  final VoidCallback onCustomAmountChanged;

  const CustomSplitAllocationSection({
    super.key,
    required this.members,
    required this.exemptions,
    required this.amountController,
    required this.activeColor,
    required this.currency,
    required this.splitMode,
    required this.onSplitModeChanged,
    required this.getController,
    required this.onDistributeEvenly,
    required this.onClearAll,
    required this.onSplitRemaining,
    required this.onToggleExemption,
    required this.onCustomAmountChanged,
  });

  double _getCustomAllocatedTotal() {
    double sum = 0.0;
    for (final m in members) {
      if (m.active && !exemptions.contains(m.id)) {
        final val = double.tryParse(getController(m.id).text.trim()) ?? 0.0;
        sum += val;
      }
    }
    return sum;
  }

  Widget _buildSplitModeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers = members.where((m) => m.active).toList();
    final double totalAmount =
        double.tryParse(amountController.text.trim()) ?? 0.0;
    final double allocated = _getCustomAllocatedTotal();
    final double diff = totalAmount - allocated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Split Allocation',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _buildSplitModeChip(
                    label: 'Equal',
                    icon: Icons.pie_chart_outline_rounded,
                    isSelected: splitMode == 'equal',
                    onTap: () => onSplitModeChanged('equal'),
                  ),
                  _buildSplitModeChip(
                    label: 'Custom',
                    icon: Icons.tune_rounded,
                    isSelected: splitMode == 'custom',
                    onTap: () => onSplitModeChanged('custom'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (splitMode == 'equal') ...[
          const Text(
            'Tap member chips to toggle inclusion or exemption in this split:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activeMembers.map((m) {
              final isIncluded = !exemptions.contains(m.id);

              return FilterChip(
                selected: isIncluded,
                showCheckmark: false,
                avatar: CircleAvatar(
                  radius: 10,
                  backgroundColor:
                      isIncluded ? Colors.white : Colors.grey.shade300,
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
                selectedColor: activeColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isIncluded ? activeColor : Colors.grey,
                  fontWeight: isIncluded ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) => onToggleExemption(m.id, selected),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isIncluded ? activeColor : Colors.grey.shade300,
                  ),
                ),
              );
            }).toList(),
          ),
          if (totalAmount > 0) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final includedCount = activeMembers
                    .where((m) => !exemptions.contains(m.id))
                    .length;
                if (includedCount > 0) {
                  final perPerson = totalAmount / includedCount;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: activeColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: activeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Split equally among $includedCount member${includedCount > 1 ? 's' : ''}: ~${FormatUtils.formatCurrency(perPerson, currency)} each',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: activeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ] else ...[
          // EXACT AMOUNT SPLIT MODE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Enter exact amounts allocated to each member:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  InkWell(
                    onTap: onDistributeEvenly,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high,
                              size: 14, color: activeColor),
                          const SizedBox(width: 4),
                          Text(
                            'Split Evenly',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: activeColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onClearAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.refresh, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Clear',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...activeMembers.map((m) {
            final isIncluded = !exemptions.contains(m.id);
            final ctrl = getController(m.id);
            final memberVal = double.tryParse(ctrl.text.trim()) ?? 0.0;
            final pct = totalAmount > 0 ? (memberVal / totalAmount) * 100 : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isIncluded
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isIncluded
                      ? (memberVal > 0
                          ? activeColor.withValues(alpha: 0.5)
                          : Colors.grey.shade300)
                      : Colors.transparent,
                  width: memberVal > 0 ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      onToggleExemption(m.id, !isIncluded);
                    },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: isIncluded
                          ? activeColor.withValues(alpha: 0.15)
                          : Colors.grey.shade300,
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isIncluded ? activeColor : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isIncluded ? null : Colors.grey,
                            decoration:
                                isIncluded ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        if (isIncluded && totalAmount > 0 && memberVal > 0)
                          Text(
                            '${pct.toStringAsFixed(1)}% of total',
                            style: TextStyle(
                                fontSize: 11,
                                color: activeColor,
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                  if (isIncluded) ...[
                    SizedBox(
                      width: 130,
                      height: 42,
                      child: TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        onChanged: (_) => onCustomAmountChanged(),
                        decoration: InputDecoration(
                          prefixText: '$currency ',
                          prefixStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: activeColor,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: activeColor, width: 2),
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Exempt',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: diff.abs() <= 0.05
                    ? Colors.green.withValues(alpha: 0.5)
                    : (diff > 0.05
                        ? Colors.orange.withValues(alpha: 0.5)
                        : Colors.red.withValues(alpha: 0.5)),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Expense:',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                    Text(
                      FormatUtils.formatCurrency(totalAmount, currency),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Allocated So Far:',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                    Text(
                      FormatUtils.formatCurrency(allocated, currency),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: diff.abs() <= 0.05
                            ? Colors.green
                            : (diff > 0 ? Colors.orange.shade800 : Colors.red),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  children: [
                    Icon(
                      diff.abs() <= 0.05
                          ? Icons.check_circle_rounded
                          : (diff > 0.05
                              ? Icons.pending_outlined
                              : Icons.error_outline_rounded),
                      size: 16,
                      color: diff.abs() <= 0.05
                          ? Colors.green
                          : (diff > 0 ? Colors.orange.shade800 : Colors.red),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        diff.abs() <= 0.05
                            ? 'Allocations perfectly match transaction amount'
                            : (diff > 0.05
                                ? '${FormatUtils.formatCurrency(diff, currency)} remaining to allocate'
                                : '${FormatUtils.formatCurrency(-diff, currency)} over-allocated'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: diff.abs() <= 0.05
                              ? Colors.green
                              : (diff > 0
                                  ? Colors.orange.shade800
                                  : Colors.red),
                        ),
                      ),
                    ),
                    if (diff > 0.05) ...[
                      InkWell(
                        onTap: onSplitRemaining,
                        child: Text(
                          'Fill Remaining',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: activeColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
