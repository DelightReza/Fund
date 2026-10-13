import 'package:flutter/material.dart';
import '../../models/app_config.dart';
import '../../utils/date_utils.dart';

/// Modal bottom sheet helpers for filtering transactions by Type, Month, Member, and Bill Category
/// Built with isScrollControlled: true, Scrollbar, flexible height constraints, and instant search
class TransactionFilterSheets {
  static void _showScrollableFilterSheet({
    required BuildContext context,
    required String title,
    String? searchHint,
    required List<Widget> Function(BuildContext ctx, String searchQuery) itemsBuilder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.78;
        String query = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final items = itemsBuilder(ctx, query.toLowerCase().trim());
            final theme = Theme.of(ctx);

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top drag handle
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Header with title and close button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Live search bar if enabled
                    if (searchHint != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          onChanged: (val) => setSheetState(() => query = val),
                          decoration: InputDecoration(
                            hintText: searchHint,
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            suffixIcon: query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () => setSheetState(() => query = ''),
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                            ),
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                    ],

                    const Divider(height: 1),

                    // Scrollable list of items
                    Flexible(
                      child: items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                              child: Text(
                                'No matching items found',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              child: ListView(
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                children: items,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showTypeFilterSheet({
    required BuildContext context,
    required String currentType,
    required ValueChanged<String> onSelected,
  }) {
    _showScrollableFilterSheet(
      context: context,
      title: 'Filter by Transaction Type',
      itemsBuilder: (ctx, _) {
        final theme = Theme.of(ctx);
        return [
          ListTile(
            leading: const Icon(Icons.all_inclusive_rounded),
            title: const Text('All Transactions'),
            selected: currentType == 'all',
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            trailing: currentType == 'all' ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
            onTap: () {
              onSelected('all');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.arrow_downward_rounded, color: Colors.green),
            title: const Text('Deposits / Credits'),
            selected: currentType == 'credit',
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            trailing: currentType == 'credit' ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
            onTap: () {
              onSelected('credit');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.arrow_upward_rounded, color: Colors.red),
            title: const Text('Expenses / Debits'),
            selected: currentType == 'debit',
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            trailing: currentType == 'debit' ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
            onTap: () {
              onSelected('debit');
              Navigator.pop(ctx);
            },
          ),
        ];
      },
    );
  }

  static void showMonthFilterSheet({
    required BuildContext context,
    required List<String> months,
    required String? currentMonth,
    required ValueChanged<String?> onSelected,
  }) {
    _showScrollableFilterSheet(
      context: context,
      title: 'Filter by Month',
      searchHint: months.length > 5 ? 'Search month (e.g. October, 2026)...' : null,
      itemsBuilder: (ctx, query) {
        final theme = Theme.of(ctx);
        final filteredMonths = months.where((m) {
          if (query.isEmpty) return true;
          final formatted = AppDateUtils.formatMonthName(m).toLowerCase();
          return formatted.contains(query) || m.toLowerCase().contains(query);
        }).toList();

        final widgets = <Widget>[];

        if (query.isEmpty) {
          widgets.add(
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('All Months', style: TextStyle(fontWeight: FontWeight.w600)),
              selected: currentMonth == null,
              selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              trailing: currentMonth == null ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
              onTap: () {
                onSelected(null);
                Navigator.pop(ctx);
              },
            ),
          );
        }

        for (final m in filteredMonths) {
          final isSelected = currentMonth == m;
          widgets.add(
            ListTile(
              leading: Icon(
                Icons.event_note_rounded,
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
              ),
              title: Text(
                AppDateUtils.formatMonthName(m),
                style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text(m, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              trailing: isSelected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
              onTap: () {
                onSelected(m);
                Navigator.pop(ctx);
              },
            ),
          );
        }

        return widgets;
      },
    );
  }

  static void showMemberFilterSheet({
    required BuildContext context,
    required AppConfig config,
    required String? currentMemberId,
    required ValueChanged<String?> onSelected,
  }) {
    _showScrollableFilterSheet(
      context: context,
      title: 'Filter by Member',
      searchHint: config.members.length > 5 ? 'Search members...' : null,
      itemsBuilder: (ctx, query) {
        final theme = Theme.of(ctx);
        final filteredMembers = config.members.where((m) {
          if (query.isEmpty) return true;
          return m.name.toLowerCase().contains(query) || m.id.toLowerCase().contains(query);
        }).toList();

        final widgets = <Widget>[];

        if (query.isEmpty) {
          widgets.add(
            ListTile(
              leading: const Icon(Icons.group_rounded),
              title: const Text('All Members', style: TextStyle(fontWeight: FontWeight.w600)),
              selected: currentMemberId == null,
              selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              trailing: currentMemberId == null ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
              onTap: () {
                onSelected(null);
                Navigator.pop(ctx);
              },
            ),
          );
        }

        for (final m in filteredMembers) {
          final isSelected = currentMemberId == m.id;
          widgets.add(
            ListTile(
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isSelected ? Colors.white : theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                m.name,
                style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text('@${m.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              trailing: isSelected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
              onTap: () {
                onSelected(m.id);
                Navigator.pop(ctx);
              },
            ),
          );
        }

        return widgets;
      },
    );
  }

  static void showBillFilterSheet({
    required BuildContext context,
    required AppConfig config,
    required String? currentBillId,
    required ValueChanged<String?> onSelected,
  }) {
    _showScrollableFilterSheet(
      context: context,
      title: 'Filter by Bill Category',
      searchHint: config.billTypes.length > 5 ? 'Search categories...' : null,
      itemsBuilder: (ctx, query) {
        final theme = Theme.of(ctx);
        final filteredBills = config.billTypes.where((b) {
          if (query.isEmpty) return true;
          return b.name.toLowerCase().contains(query) ||
              b.id.toLowerCase().contains(query) ||
              b.icon.contains(query);
        }).toList();

        final widgets = <Widget>[];

        if (query.isEmpty) {
          widgets.add(
            ListTile(
              leading: const Icon(Icons.category_rounded),
              title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.w600)),
              selected: currentBillId == null,
              selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              trailing: currentBillId == null ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
              onTap: () {
                onSelected(null);
                Navigator.pop(ctx);
              },
            ),
          );
        }

        for (final b in filteredBills) {
          final isSelected = currentBillId == b.id;
          widgets.add(
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : theme.dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  b.icon.trim().isNotEmpty ? b.icon : '🧾',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              title: Text(
                b.name,
                style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text(b.id, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              trailing: isSelected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
              onTap: () {
                onSelected(b.id);
                Navigator.pop(ctx);
              },
            ),
          );
        }

        return widgets;
      },
    );
  }
}
