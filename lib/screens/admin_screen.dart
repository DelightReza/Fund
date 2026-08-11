
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../services/calculations.dart';
import '../utils/format_utils.dart';
import '../widgets/balance_card.dart';
import '../screens/add_transaction_screen.dart'; // for navigation
import '../screens/reset_commit_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final data = ref.watch(dataProvider);
    final balances = ref.watch(balancesProvider);
    final settlements = ref.watch(debtSettlementsProvider);
    final totals = ref.watch(totalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Forms'),
            Tab(text: 'History'),
            Tab(text: 'Balances'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Forms tab
          _buildFormsTab(),
          // History tab
          _buildHistoryTab(),
          // Balances tab
          _buildBalancesTab(balances, settlements, config.currency),
          // Settings tab
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildFormsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Quick Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ElevatedButton.icon(
          onPressed: () => context.go('/add_transaction', extra: {'type': 'expense'}),
          icon: const Icon(Icons.flash_on),
          label: const Text('Record Expense'),
        ),
        const SizedBox(height: 12),
        const Text('Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ElevatedButton.icon(
          onPressed: () => context.go('/add_transaction', extra: {'type': 'credit'}),
          icon: const Icon(Icons.arrow_downward),
          label: const Text('Add Credit'),
        ),
        const SizedBox(height: 12),
        const Text('Debit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ElevatedButton.icon(
          onPressed: () => context.go('/add_transaction', extra: {'type': 'debit'}),
          icon: const Icon(Icons.arrow_upward),
          label: const Text('Add Debit'),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const Text('Advanced Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ElevatedButton.icon(
          onPressed: () => context.go('/add_transaction', extra: {'type': 'distribute'}),
          icon: const Icon(Icons.group),
          label: const Text('Distribution'),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/add_transaction', extra: {'type': 'settlement'}),
          icon: const Icon(Icons.handshake),
          label: const Text('Settlement'),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/add_transaction', extra: {'type': 'transfer'}),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Transfer'),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/reset_commit'),
          icon: const Icon(Icons.restore),
          label: const Text('Reset Commit'),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final config = ref.watch(configProvider);
    final data = ref.watch(dataProvider);
    // Simple list
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: data.transactions.length,
      itemBuilder: (context, index) {
        final tx = data.transactions[index];
        String display = tx.type == 'credit' ? 'Credit' : 'Debit';
        return ListTile(
          title: Text('$display - ${tx.whoOrBill}'),
          subtitle: Text('${tx.note} ${tx.date}'),
          trailing: Text(FormatUtils.formatCurrency(tx.amount, config.currency)),
          onTap: () => context.go('/transaction_detail/${tx.id}'),
        );
      },
    );
  }

  Widget _buildBalancesTab(Map<String, double> balances, List settlements, String currency) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Balances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ...balances.entries.map((entry) {
          return BalanceCard(
            name: entry.key,
            amount: entry.value,
            currency: currency,
          );
        }).toList(),
        if (settlements.isNotEmpty) ...[
          const Divider(),
          const Text('Debt Simplification', style: TextStyle(fontWeight: FontWeight.bold)),
          ...settlements.map((s) => ListTile(
            leading: const Icon(Icons.arrow_forward),
            title: Text('${s.from} → ${s.to}'),
            trailing: Text(FormatUtils.formatCurrency(s.amount, currency)),
          )),
        ],
      ],
    );
  }

  Widget _buildSettingsTab() {
    final config = ref.watch(configProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('General Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        ListTile(
          title: const Text('Site Title'),
          trailing: Text(config.siteTitle),
          onTap: () {
            // Edit dialog
            _showEditDialog('Site Title', config.siteTitle, (val) {
              final newConfig = config.copyWith(siteTitle: val);
              ref.read(configProvider.notifier).setConfig(newConfig);
            });
          },
        ),
        ListTile(
          title: const Text('Currency'),
          trailing: Text(config.currency),
          onTap: () {
            _showEditDialog('Currency', config.currency, (val) {
              final newConfig = config.copyWith(currency: val);
              ref.read(configProvider.notifier).setConfig(newConfig);
            });
          },
        ),
        const Divider(),
        const Text('People', style: TextStyle(fontWeight: FontWeight.bold)),
        ...config.people.map((p) => ListTile(
          title: Text(p.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(p.active ? Icons.check_circle : Icons.cancel, color: p.active ? Colors.green : Colors.red),
                onPressed: () {
                  final updatedPeople = config.people.map((m) {
                    if (m.id == p.id) return m.copyWith(active: !m.active);
                    return m;
                  }).toList();
                  ref.read(configProvider.notifier).setConfig(config.copyWith(people: updatedPeople));
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  final updatedPeople = config.people.where((m) => m.id != p.id).toList();
                  ref.read(configProvider.notifier).setConfig(config.copyWith(people: updatedPeople));
                },
              ),
            ],
          ),
        )),
        const Divider(),
        const Text('Bill Types', style: TextStyle(fontWeight: FontWeight.bold)),
        ...config.billTypes.map((b) => ListTile(
          title: Text('${b.icon} ${b.name}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              final updated = config.billTypes.where((bt) => bt.id != b.id).toList();
              ref.read(configProvider.notifier).setConfig(config.copyWith(billTypes: updated));
            },
          ),
        )),
      ],
    );
  }

  void _showEditDialog(String label, String current, Function(String) onSave) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

