import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../widgets/settlement_card.dart';
import '../widgets/summary_cards.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'category_expenses_screen.dart';
import 'profile_screen.dart';
import 'repo_selection_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilterType = 'all'; // all, credit, debit
  String? _selectedMonthFilter; // e.g. "2026-08" or null for all
  String? _selectedMemberFilter;
  String? _selectedBillFilter;
  bool _showFilters = false;

  bool get _hasActiveFilters =>
      _selectedFilterType != 'all' ||
      _selectedMonthFilter != null ||
      _selectedMemberFilter != null ||
      _selectedBillFilter != null ||
      _searchController.text.trim().isNotEmpty;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedFilterType != 'all') count++;
    if (_selectedMonthFilter != null) count++;
    if (_selectedMemberFilter != null) count++;
    if (_selectedBillFilter != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openAddSheet([int initialMode = 0]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
      ),
    );
  }

  void _showRepoSwitcherBottomSheet(BuildContext context) {
    final storage = context.read<StorageService>();
    final workspaces = storage.savedWorkspaces;
    final currentOwner = storage.activeRepoOwner;
    final currentRepo = storage.activeRepoName;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Switch Repository',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 12),
              if (workspaces.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No other workspaces saved.', style: TextStyle(color: Colors.grey)),
                )
              else
                ...workspaces.map(
                  (ws) {
                    final isSelected = ws.owner.toLowerCase() == (currentOwner ?? '').toLowerCase() &&
                        ws.repo.toLowerCase() == (currentRepo ?? '').toLowerCase();

                    return ListTile(
                      leading: const Icon(Icons.folder_shared_outlined),
                      title: Text('${ws.owner}/${ws.repo}',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          )),
                      subtitle: Text(ws.title ?? 'Fund Repository'),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isSelected) {
                          context.read<FundRepository>().switchWorkspace(ws.owner, ws.repo);
                        }
                      },
                    );
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                title: const Text('Add or Connect Another Repository'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RepoSelectionScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<FundRepository>();
    final storage = context.watch<StorageService>();
    final config = repo.config ?? AppConfig();
    final data = repo.data ?? FundData();
    final isAdminVerified = storage.isAdminVerified;

    final summaries = BalanceEngine.calculateMemberSummaries(data, config);
    final billTotals = BalanceEngine.calculateBillTypeTotals(data, config);
    final netBalances = summaries.map((k, v) => MapEntry(k, v.netBalance));
    final settlements = BalanceEngine.calculateDebtSettlements(netBalances);

    double totalCredits = 0;
    double totalDebits = 0;
    for (final tx in data.transactions) {
      if (tx.type == 'credit') totalCredits += tx.amount;
      if (tx.type == 'debit') totalDebits += tx.amount;
    }
    final poolBalance = totalCredits - totalDebits;

    // Extract available months for filtering
    final availableMonths = <String>{};
    for (final tx in data.transactions) {
      if (tx.date.length >= 7) {
        availableMonths.add(tx.date.substring(0, 7));
      }
    }
    final sortedMonths = availableMonths.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: kIsWeb
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    config.siteTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (config.siteSubtitle.isNotEmpty)
                    Text(
                      config.siteSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                ],
              )
            : InkWell(
                onTap: () => _showRepoSwitcherBottomSheet(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            config.siteTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          if (config.siteSubtitle.isNotEmpty)
                            Text(
                              config.siteSubtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, size: 22),
                    ],
                  ),
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: theme.brightness == Brightness.dark ? 'Switch to Light Mode' : 'Switch to Dark/Night Mode',
            onPressed: () => storage.toggleTheme(context),
          ),
          // Admin (🛡️) authorization / lock button in header
          IconButton(
            icon: Icon(
              Icons.shield_rounded,
              color: isAdminVerified ? const Color(0xFF10B981) : Colors.amber.shade700,
            ),
            tooltip: isAdminVerified ? 'Admin Authorized (PAT Verified)' : 'Admin Login (Enter PAT)',
            onPressed: () => AdminPatModal.show(context),
          ),
          IconButton(
            icon: repo.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: () => repo.refreshAll(),
            tooltip: 'Refresh from GitHub',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Transactions', icon: Icon(Icons.receipt_long_rounded, size: 20)),
            Tab(text: 'People', icon: Icon(Icons.people_outline_rounded, size: 20)),
            Tab(text: 'Expenses', icon: Icon(Icons.pie_chart_outline_rounded, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (storage.hasPendingSyncFlag)
            Container(
              width: double.infinity,
              color: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Offline changes pending sync to GitHub.',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black26,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    onPressed: () {
                      final token = storage.currentToken;
                      if (token != null && token.isNotEmpty) {
                        repo.syncPending(token);
                      } else {
                        AdminPatModal.show(context);
                      }
                    },
                    child: const Text('Sync Now', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(data, config, poolBalance, totalCredits, totalDebits, sortedMonths),
                _buildPeopleTab(summaries, settlements, config),
                _buildBillsTab(data, billTotals, totalDebits, config),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(
    FundData data,
    AppConfig config,
    double poolBalance,
    double totalCredits,
    double totalDebits,
    List<String> sortedMonths,
  ) {
    final theme = Theme.of(context);
    final query = _searchController.text.toLowerCase().trim();

    final filtered = data.transactions.where((tx) {
      if (_selectedFilterType != 'all' && tx.type != _selectedFilterType) return false;
      if (_selectedMonthFilter != null && !tx.date.startsWith(_selectedMonthFilter!)) return false;
      if (_selectedMemberFilter != null &&
          tx.payerId != _selectedMemberFilter &&
          tx.whoOrBill != _selectedMemberFilter &&
          (tx.splitAmong == null || !tx.splitAmong!.contains(_selectedMemberFilter))) {
        return false;
      }
      if (_selectedBillFilter != null &&
          tx.billTypeId != _selectedBillFilter &&
          tx.whoOrBill != _selectedBillFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final payer = config.members.firstWhere(
          (m) => m.id == tx.payerId || m.id == tx.whoOrBill,
          orElse: () => MemberConfig(id: tx.whoOrBill, name: tx.whoOrBill),
        );
        final bill = config.billTypes.firstWhere(
          (b) => b.id == tx.billTypeId || b.id == tx.whoOrBill,
          orElse: () => BillTypeConfig(id: tx.whoOrBill, name: tx.whoOrBill, icon: ''),
        );
        final matchesNote = tx.note.toLowerCase().contains(query);
        final matchesWho = tx.whoOrBill.toLowerCase().contains(query);
        final matchesPayer = payer.name.toLowerCase().contains(query);
        final matchesBill = bill.name.toLowerCase().contains(query);
        final matchesAmount = tx.amount.toString().contains(query);
        final matchesDate = tx.date.toLowerCase().contains(query);

        if (!matchesNote &&
            !matchesWho &&
            !matchesPayer &&
            !matchesBill &&
            !matchesAmount &&
            !matchesDate) {
          return false;
        }
      }
      return true;
    }).toList();

    // Calculate month-specific totals when a month filter is active
    double monthCredits = 0.0;
    double monthDebits = 0.0;
    int monthTxCount = 0;
    if (_selectedMonthFilter != null) {
      for (final tx in data.transactions) {
        if (tx.date.startsWith(_selectedMonthFilter!)) {
          monthTxCount++;
          if (tx.type == 'credit') {
            monthCredits += tx.amount;
          } else if (tx.type == 'debit') {
            monthDebits += tx.amount;
          }
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () => context.read<FundRepository>().refreshAll(),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          FundBalanceSummaryCard(
            totalBalance: poolBalance,
            totalCredits: totalCredits,
            totalDebits: totalDebits,
            currency: config.currency,
          ),
          const SizedBox(height: 14),

          // Transactions Header with Search & Filter Toggle Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transactions (${filtered.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Badge(
                  isLabelVisible: _hasActiveFilters,
                  label: Text('$_activeFilterCount'),
                  child: Icon(
                    _showFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                    size: 18,
                    color: _hasActiveFilters ? theme.colorScheme.primary : null,
                  ),
                ),
                label: Text(
                  _showFilters ? 'Hide Filters' : 'Search & Filter',
                  style: TextStyle(
                    fontWeight: _hasActiveFilters ? FontWeight.bold : FontWeight.w600,
                    color: _hasActiveFilters ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Search and Filters Area
          if (_showFilters) ...[
            _buildSearchAndFilters(config, sortedMonths),
            const SizedBox(height: 10),
          ] else if (_hasActiveFilters) ...[
            _buildActiveFiltersQuickBar(config),
            const SizedBox(height: 10),
          ],

          // Month Overview Card (shown when a month is selected)
          if (_selectedMonthFilter != null)
            MonthSummaryCard(
              monthKey: _selectedMonthFilter!,
              totalCredits: monthCredits,
              totalDebits: monthDebits,
              transactionCount: monthTxCount,
              currency: config.currency,
              onClear: () => setState(() => _selectedMonthFilter = null),
            ),
          const SizedBox(height: 4),

          if (filtered.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 50, color: Colors.grey.withOpacity(0.4)),
                  const SizedBox(height: 10),
                  const Text('No transactions match the criteria', style: TextStyle(color: Colors.grey)),
                  if (query.isNotEmpty || _selectedFilterType != 'all' || _selectedMonthFilter != null || _selectedMemberFilter != null || _selectedBillFilter != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _selectedFilterType = 'all';
                          _selectedMonthFilter = null;
                          _selectedMemberFilter = null;
                          _selectedBillFilter = null;
                        });
                      },
                      child: const Text('Reset All Filters'),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            ...filtered.map(
              (tx) => TransactionTile(
                transaction: tx,
                config: config,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(transaction: tx),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 72),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(AppConfig config, List<String> sortedMonths) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Bar
        TextField(
          controller: _searchController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search note, payer, category, amount...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
          onChanged: (val) => setState(() {}),
        ),
        const SizedBox(height: 10),

        // Horizontal Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Type Filter
              FilterChip(
                showCheckmark: false,
                label: Text(_selectedFilterType == 'all'
                    ? 'All Types'
                    : _selectedFilterType == 'credit'
                        ? 'Deposits / Credits'
                        : 'Expenses / Debits'),
                selected: _selectedFilterType != 'all',
                onSelected: (_) => _showTypeFilterSheet(),
              ),
              const SizedBox(width: 8),

              // Month Filter
              FilterChip(
                showCheckmark: false,
                label: Text(_selectedMonthFilter == null
                    ? 'All Months'
                    : AppDateUtils.formatMonthName(_selectedMonthFilter!)),
                selected: _selectedMonthFilter != null,
                onSelected: (_) => _showMonthFilterSheet(sortedMonths),
              ),
              const SizedBox(width: 8),

              // Member Filter
              FilterChip(
                showCheckmark: false,
                label: Text(_selectedMemberFilter == null
                    ? 'All Members'
                    : (config.members.firstWhere((m) => m.id == _selectedMemberFilter, orElse: () => MemberConfig(id: _selectedMemberFilter!, name: _selectedMemberFilter!)).name)),
                selected: _selectedMemberFilter != null,
                onSelected: (_) => _showMemberFilterSheet(config),
              ),
              const SizedBox(width: 8),

              // Bill Filter
              FilterChip(
                showCheckmark: false,
                label: Text(_selectedBillFilter == null
                    ? 'All Categories'
                    : (config.billTypes.firstWhere((b) => b.id == _selectedBillFilter, orElse: () => BillTypeConfig(id: _selectedBillFilter!, name: _selectedBillFilter!, icon: '')).name)),
                selected: _selectedBillFilter != null,
                onSelected: (_) => _showBillFilterSheet(config),
              ),

              if (_selectedFilterType != 'all' ||
                  _selectedMonthFilter != null ||
                  _selectedMemberFilter != null ||
                  _selectedBillFilter != null ||
                  _searchController.text.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.close, size: 14),
                  label: const Text('Clear All'),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedFilterType = 'all';
                      _selectedMonthFilter = null;
                      _selectedMemberFilter = null;
                      _selectedBillFilter = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersQuickBar(AppConfig config) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_searchController.text.trim().isNotEmpty) ...[
            Chip(
              avatar: const Icon(Icons.search, size: 14),
              label: Text('"${_searchController.text.trim()}"'),
              onDeleted: () {
                setState(() {
                  _searchController.clear();
                });
              },
            ),
            const SizedBox(width: 6),
          ],
          if (_selectedFilterType != 'all') ...[
            Chip(
              avatar: const Icon(Icons.filter_alt_outlined, size: 14),
              label: Text(_selectedFilterType == 'credit' ? 'Deposits' : 'Expenses'),
              onDeleted: () {
                setState(() {
                  _selectedFilterType = 'all';
                });
              },
            ),
            const SizedBox(width: 6),
          ],
          if (_selectedMonthFilter != null) ...[
            Chip(
              avatar: const Icon(Icons.calendar_month_outlined, size: 14),
              label: Text(AppDateUtils.formatMonthName(_selectedMonthFilter!)),
              onDeleted: () {
                setState(() {
                  _selectedMonthFilter = null;
                });
              },
            ),
            const SizedBox(width: 6),
          ],
          if (_selectedMemberFilter != null) ...[
            Chip(
              avatar: const Icon(Icons.person_outline, size: 14),
              label: Text(
                config.members
                    .firstWhere(
                      (m) => m.id == _selectedMemberFilter,
                      orElse: () => MemberConfig(id: _selectedMemberFilter!, name: _selectedMemberFilter!),
                    )
                    .name,
              ),
              onDeleted: () {
                setState(() {
                  _selectedMemberFilter = null;
                });
              },
            ),
            const SizedBox(width: 6),
          ],
          if (_selectedBillFilter != null) ...[
            Chip(
              avatar: const Icon(Icons.category_outlined, size: 14),
              label: Text(
                config.billTypes
                    .firstWhere(
                      (b) => b.id == _selectedBillFilter,
                      orElse: () => BillTypeConfig(id: _selectedBillFilter!, name: _selectedBillFilter!, icon: ''),
                    )
                    .name,
              ),
              onDeleted: () {
                setState(() {
                  _selectedBillFilter = null;
                });
              },
            ),
            const SizedBox(width: 6),
          ],
          ActionChip(
            avatar: const Icon(Icons.close_rounded, size: 14),
            label: const Text('Clear All'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedFilterType = 'all';
                _selectedMonthFilter = null;
                _selectedMemberFilter = null;
                _selectedBillFilter = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showTypeFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter by Transaction Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded),
                title: const Text('All Transactions'),
                trailing: _selectedFilterType == 'all' ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _selectedFilterType = 'all');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward_rounded, color: Colors.green),
                title: const Text('Deposits / Credits'),
                trailing: _selectedFilterType == 'credit' ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _selectedFilterType = 'credit');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward_rounded, color: Colors.red),
                title: const Text('Expenses / Debits'),
                trailing: _selectedFilterType == 'debit' ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _selectedFilterType = 'debit');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthFilterSheet(List<String> months) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter by Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Months'),
                trailing: _selectedMonthFilter == null ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _selectedMonthFilter = null);
                  Navigator.pop(ctx);
                },
              ),
              ...months.map(
                (m) => ListTile(
                  title: Text(AppDateUtils.formatMonthName(m)),
                  subtitle: Text(m, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: _selectedMonthFilter == m ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    setState(() => _selectedMonthFilter = m);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberFilterSheet(AppConfig config) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter by Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Members'),
                trailing: _selectedMemberFilter == null ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _selectedMemberFilter = null);
                  Navigator.pop(ctx);
                },
              ),
              ...config.members.map(
                (m) => ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(m.name),
                  subtitle: Text('@${m.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: _selectedMemberFilter == m.id ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    setState(() => _selectedMemberFilter = m.id);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBillFilterSheet(AppConfig config) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter by Bill Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Categories'),
                trailing: _selectedBillFilter == null ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _selectedBillFilter = null);
                  Navigator.pop(ctx);
                },
              ),
              ...config.billTypes.map(
                (b) => ListTile(
                  leading: Text(b.icon, style: const TextStyle(fontSize: 20)),
                  title: Text(b.name),
                  subtitle: Text(b.id, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: _selectedBillFilter == b.id ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    setState(() => _selectedBillFilter = b.id);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeopleTab(
    Map<String, MemberFinancialSummary> summaries,
    List<Settlement> settlements,
    AppConfig config,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        const Text(
          'Individual Balances',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...summaries.values.map(
          (summary) => MemberSummaryCard(
            summary: summary,
            config: config,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(memberId: summary.memberId),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 72),
      ],
    );
  }

  Widget _buildBillsTab(
    FundData data,
    Map<String, double> billTotals,
    double totalDebits,
    AppConfig config,
  ) {
    // Count transactions per category
    final categoryTxCounts = <String, int>{};
    for (final tx in data.transactions) {
      if (tx.type == 'debit') {
        final bId = (tx.billTypeId != null && tx.billTypeId!.isNotEmpty)
            ? tx.billTypeId!
            : tx.whoOrBill;
        categoryTxCounts[bId] = (categoryTxCounts[bId] ?? 0) + 1;
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Expenditure', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  FormatUtils.formatCurrency(totalDebits, config.currency),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Expenditure by Category',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Tap category to view expenses',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...config.billTypes.map((bill) {
          final total = billTotals[bill.id] ?? 0.0;
          final count = categoryTxCounts[bill.id] ?? 0;
          final pct = totalDebits > 0 ? (total / totalDebits) : 0.0;

          return BillTypeSummaryCard(
            billType: bill,
            totalAmount: total,
            percentage: pct,
            transactionCount: count,
            currency: config.currency,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryExpensesScreen(billTypeId: bill.id),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 72),
      ],
    );
  }
}
