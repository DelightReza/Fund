import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../repositories/fund_repository.dart';
import '../services/storage_service.dart';
import '../utils/debt_simplifier.dart';
import '../utils/file_helper.dart';
import '../utils/format_utils.dart';
import '../widgets/admin_pat_modal.dart';
import 'add_transaction_screen.dart';
import 'manage_config_screen.dart';
import 'repo_selection_screen.dart';
import 'reset_commit_screen.dart';
import 'user_selection_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isSyncing = false;

  void _openAddTransaction(String initialType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: initialType),
      ),
    );
  }

  Future<void> _handlePullFromGitHub(FundRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Pull from GitHub'),
          ],
        ),
        content: const Text(
          'This will fetch the latest config.json and data.json from GitHub and replace your local cached transactions.\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Pull Latest'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSyncing = true);

    try {
      final ok = await repo.pullFromGitHub();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? const Color(0xFF047857) : Colors.red.shade800,
            content: Text(
              ok
                  ? '✓ Pulled latest data & configuration from GitHub'
                  : '⚠️ Failed to pull from GitHub. Please verify repository connection.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Pull Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _handlePushToGitHub(FundRepository repo) async {
    final storage = context.read<StorageService>();
    final token = storage.currentToken;

    if (token == null || token.isEmpty) {
      final configured = await AdminPatModal.show(context);
      if (configured != true) return;
    }

    final totalCount = repo.data?.transactions.length ?? 0;
    final commitCtrl = TextEditingController(
      text: 'Push update: ledger with $totalCount transactions from Admin panel',
    );

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.upload_rounded, color: Color(0xFF047857)),
            SizedBox(width: 8),
            Text('Push to GitHub'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload and commit current local transactions ($totalCount records) directly to GitHub.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            const Text(
              'Commit Message:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: commitCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('Push Changes'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    setState(() => _isSyncing = true);

    try {
      final ok = await repo.pushToGitHub(commitMessage: commitCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? const Color(0xFF047857) : Colors.orange.shade800,
            content: Text(
              ok
                  ? '✓ Successfully pushed and committed data.json to GitHub'
                  : '⚠️ Could not push to GitHub. Saved locally with pending sync.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Push Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _handleFullSync(FundRepository repo) async {
    final storage = context.read<StorageService>();
    final token = storage.currentToken;

    if (token == null || token.isEmpty) {
      final configured = await AdminPatModal.show(context);
      if (configured != true) return;
    }

    setState(() => _isSyncing = true);

    try {
      final ok = await repo.forceSyncGitHub();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? const Color(0xFF047857) : Colors.orange.shade800,
            content: Text(
              ok
                  ? '✓ Successfully synced with GitHub (pulled latest ledger & pushed pending changes)'
                  : '⚠️ Refreshed local view. Connect a valid GitHub PAT to push changes.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Sync Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showSyncGitHubModal(FundRepository repo) {
    final storage = context.read<StorageService>();
    final config = repo.config ?? AppConfig();
    final hasToken = storage.currentToken != null && storage.currentToken!.isNotEmpty;
    final hasPending = storage.hasPendingSyncFlag;
    final txCount = repo.data?.transactions.length ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sync_rounded, color: Color(0xFF0284C7), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'GitHub Sync & Replication',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Status Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Repository:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          Text(
                            '${config.repoOwner}/${config.repoName}',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Token Status:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasToken ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hasToken ? '✓ PAT Configured' : '⚠️ No PAT Connected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: hasToken ? Colors.green.shade800 : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Local Ledger:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          Text('$txCount transactions', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (hasPending) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pending Sync:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange)),
                            Text(
                              'Offline changes unpushed',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 6),

              // Option 1: Pull from GitHub
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 22),
                ),
                title: const Text('Pull from GitHub (Fetch Latest)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Download latest data.json & config.json from repo, overwriting local state'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePullFromGitHub(repo);
                },
              ),

              // Option 2: Push to GitHub
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_rounded, color: Color(0xFF047857), size: 22),
                ),
                title: const Text('Push to GitHub (Commit Local Data)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Upload $txCount local transactions and update data.json on GitHub'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePushToGitHub(repo);
                },
              ),

              // Option 3: Bidirectional Auto Sync
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sync_rounded, color: Color(0xFF7C3AED), size: 22),
                ),
                title: const Text('Auto Sync (Push Pending & Pull)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Push any pending offline changes and refresh latest remote updates'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleFullSync(repo);
                },
              ),

              // Option 4: Token Settings
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.vpn_key_outlined, color: Colors.blueGrey, size: 22),
                ),
                title: const Text('GitHub Token (PAT) Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Configure or test your GitHub Personal Access Token permissions'),
                onTap: () {
                  Navigator.pop(ctx);
                  AdminPatModal.show(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  void _showRawJsonModal(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            onPressed: () {
              _copyToClipboard(content, title);
              Navigator.of(ctx).pop();
            },
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
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

    final summaries = BalanceEngine.calculateMemberSummaries(data, config);
    final netBalances = summaries.map((k, v) => MapEntry(k, v.netBalance));
    final settlements = BalanceEngine.calculateDebtSettlements(netBalances);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: theme.brightness == Brightness.dark ? 'Switch to Light Mode' : 'Switch to Dark/Night Mode',
            onPressed: () => storage.toggleTheme(context),
          ),
          IconButton(
            icon: const Icon(Icons.shield, color: Color(0xFF10B981)),
            tooltip: 'Admin Authorization (PAT Active)',
            onPressed: () => AdminPatModal.show(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Transaction Entry Section (Kotlin Grid Action Cards)
          _buildSectionTitle(context, 'Transaction Entry'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminActionCard(
                  title: 'Quick Expense',
                  icon: Icons.flash_on,
                  color: const Color(0xFF3B82F6),
                  onClick: () => _openAddTransaction('expense'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminActionCard(
                  title: 'Add Credit',
                  icon: Icons.arrow_downward,
                  color: const Color(0xFF10B981),
                  onClick: () => _openAddTransaction('credit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminActionCard(
                  title: 'Add Debit',
                  icon: Icons.arrow_upward,
                  color: const Color(0xFFEF4444),
                  onClick: () => _openAddTransaction('debit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Advanced Tools Section
          _buildSectionTitle(context, 'Advanced Tools'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminActionCard(
                  title: 'Distribute',
                  icon: Icons.people,
                  color: const Color(0xFF8B5CF6),
                  onClick: () => _openAddTransaction('distribute'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminActionCard(
                  title: 'Settle Debt',
                  icon: Icons.handshake,
                  color: const Color(0xFF059669),
                  onClick: () => _openAddTransaction('settlement'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminActionCard(
                  title: 'Transfer',
                  icon: Icons.swap_horiz,
                  color: const Color(0xFF2563EB),
                  onClick: () => _openAddTransaction('transfer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminActionCard(
                  title: 'Reset Commit',
                  icon: Icons.history,
                  color: const Color(0xFFDC2626),
                  onClick: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ResetCommitScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminActionCard(
                  title: 'Manage Data',
                  icon: Icons.import_export_rounded,
                  color: const Color(0xFFD97706),
                  onClick: () => _showManageDataModal(repo),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminActionCard(
                  title: _isSyncing ? 'Syncing...' : 'Sync GitHub',
                  icon: _isSyncing ? Icons.hourglass_top_rounded : Icons.sync_rounded,
                  color: const Color(0xFF0284C7),
                  onClick: _isSyncing ? null : () => _showSyncGitHubModal(repo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Debt Simplifier Section (if settlements exist)
          if (settlements.isNotEmpty) ...[
            _buildSectionTitle(context, 'Debt Simplifier'),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: settlements.map((s) {
                    final fromName = config.members
                        .firstWhere((m) => m.id == s.from, orElse: () => MemberConfig(id: s.from, name: s.from))
                        .name;
                    final toName = config.members
                        .firstWhere((m) => m.id == s.to, orElse: () => MemberConfig(id: s.to, name: s.to))
                        .name;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    fromName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                ),
                                Flexible(
                                  child: Text(
                                    toName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            FormatUtils.formatCurrency(s.amount, config.currency),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 4. Configuration Section (Kotlin Style M3 Cards)
          _buildSectionTitle(context, 'Configuration'),
          const SizedBox(height: 12),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
            ),
            elevation: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageConfigScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.settings, color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage Config',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'People, categories, currency & repository sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cache Reset Tile
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
            ),
            elevation: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Local Cache?'),
                    content: const Text(
                      'This will delete all offline cache data and reload fresh data from GitHub.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear Cache'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  await storage.clearCacheOnly();
                  await repo.refreshAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Local cache cleared')),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Clear Local Cache',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Delete cached offline files and re-sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.2,
      ),
    );
  }

  void _showManageDataModal(FundRepository repo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Manage Data (Export & Import)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              const SizedBox(height: 16),

              // Export Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'DOWNLOAD & EXPORT DATA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.download_rounded, color: Colors.blue, size: 20),
                ),
                title: const Text('Download data.json (Phone / PC)'),
                subtitle: const Text('Save ledger and transaction records to your device'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy JSON text',
                  onPressed: () {
                    final json = repo.exportToJsonFormatted();
                    _copyToClipboard(json, 'data.json');
                  },
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final json = repo.exportToJsonFormatted();
                  final res = await saveAndDownloadFile(
                    fileName: 'data.json',
                    content: json,
                    mimeType: 'application/json',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () => _showRawJsonModal('data.json', json),
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.file_download_outlined, color: Colors.purple, size: 20),
                ),
                title: const Text('Download config.json (Phone / PC)'),
                subtitle: const Text('Save workspace settings and members to your device'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy JSON text',
                  onPressed: () {
                    final json = repo.exportConfigJsonFormatted();
                    _copyToClipboard(json, 'config.json');
                  },
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final json = repo.exportConfigJsonFormatted();
                  final res = await saveAndDownloadFile(
                    fileName: 'config.json',
                    content: json,
                    mimeType: 'application/json',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () => _showRawJsonModal('config.json', json),
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.table_chart_outlined, color: Colors.green, size: 20),
                ),
                title: const Text('Download CSV Ledger'),
                subtitle: const Text('Save transactions as spreadsheet-ready CSV'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy CSV',
                  onPressed: () {
                    final csv = repo.exportToCsv();
                    _copyToClipboard(csv, 'CSV Export');
                  },
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final csv = repo.exportToCsv();
                  final dateStr = DateTime.now().toIso8601String().substring(0, 10);
                  final res = await saveAndDownloadFile(
                    fileName: 'fund_transactions_$dateStr.csv',
                    content: csv,
                    mimeType: 'text/csv',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        action: SnackBarAction(
                          label: 'Copy',
                          onPressed: () => _copyToClipboard(csv, 'CSV Export'),
                        ),
                      ),
                    );
                  }
                },
              ),

              const Divider(height: 24, indent: 16, endIndent: 16),

              // Import Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'UPLOAD & IMPORT DATA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.drive_folder_upload_rounded, color: Colors.teal, size: 20),
                ),
                title: const Text('Upload & Import JSON File'),
                subtitle: const Text('Pick any .json file from your device/phone to auto-detect & import'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final content = await pickAndReadFile(allowedExtensions: ['json']);
                  if (content != null && content.isNotEmpty) {
                    bool isConfig = false;
                    try {
                      final decoded = jsonDecode(content);
                      if (decoded is Map<String, dynamic> && decoded.containsKey('siteTitle')) {
                        isConfig = true;
                      }
                    } catch (_) {}
                    if (mounted) {
                      _showImportJsonDialog(isConfig: isConfig, repo: repo, initialJson: content);
                    }
                  } else {
                    if (mounted) {
                      _showImportJsonDialog(isConfig: false, repo: repo);
                    }
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFD97706).withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.upload_file_rounded, color: Color(0xFFD97706), size: 20),
                ),
                title: const Text('Import data.json (Paste or Upload)'),
                subtitle: const Text('Import transactions & merge with 3-way concurrent sync'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportJsonDialog(isConfig: false, repo: repo);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.settings_backup_restore_rounded, color: Colors.indigo, size: 20),
                ),
                title: const Text('Import config.json (Paste or Upload)'),
                subtitle: const Text('Import workspace configuration and member list'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportJsonDialog(isConfig: true, repo: repo);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportJsonDialog({required bool isConfig, required FundRepository repo, String? initialJson}) {
    final textCtrl = TextEditingController(text: initialJson ?? '');
    String? validationMessage;
    bool isValid = false;
    dynamic parsedObject;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void validate(String val) {
            final trimmed = val.trim();
            if (trimmed.isEmpty) {
              setDialogState(() {
                validationMessage = null;
                isValid = false;
                parsedObject = null;
              });
              return;
            }

            try {
              final decoded = jsonDecode(trimmed);
              if (isConfig) {
                if (decoded is Map<String, dynamic>) {
                  final cfg = AppConfig.fromJson(decoded);
                  setDialogState(() {
                    isValid = true;
                    parsedObject = cfg;
                    validationMessage =
                        '✓ Valid config: "${cfg.siteTitle}", ${cfg.members.length} members, ${cfg.billTypes.length} bill categories';
                  });
                } else {
                  setDialogState(() {
                    isValid = false;
                    parsedObject = null;
                    validationMessage = '⚠️ JSON must be a valid configuration object';
                  });
                }
              } else {
                if (decoded is Map<String, dynamic> && decoded.containsKey('transactions')) {
                  final data = FundData.fromJson(decoded);
                  setDialogState(() {
                    isValid = true;
                    parsedObject = data;
                    validationMessage =
                        '✓ Valid ledger: ${data.transactions.length} transactions, pool balance ₹${(data.totalCredits - data.totalDebits).toStringAsFixed(2)}';
                  });
                } else {
                  setDialogState(() {
                    isValid = false;
                    parsedObject = null;
                    validationMessage = '⚠️ JSON must contain a "transactions" array';
                  });
                }
              }
            } catch (e) {
              setDialogState(() {
                isValid = false;
                parsedObject = null;
                validationMessage = '⚠️ JSON Parsing Error: ${e.toString().split('\n').first}';
              });
            }
          }

          // Initial validation if initialJson was provided
          if (initialJson != null && initialJson.isNotEmpty && validationMessage == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => validate(initialJson));
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isConfig ? Icons.settings_suggest_outlined : Icons.upload_file_rounded,
                  color: isConfig ? Colors.indigo : const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConfig ? 'Import config.json' : 'Import data.json',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConfig
                          ? 'Upload a file or paste raw JSON for config.json to update workspace settings and members.'
                          : 'Upload a file or paste raw JSON for data.json to import ledger and transactions with 3-way automated merge.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textCtrl,
                      maxLines: 8,
                      onChanged: validate,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '{\n  ...\n}',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Upload File'),
                          onPressed: () async {
                            final content = await pickAndReadFile(allowedExtensions: ['json']);
                            if (content != null && content.isNotEmpty) {
                              textCtrl.text = content;
                              validate(content);
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.paste, size: 16),
                          label: const Text('Paste'),
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              textCtrl.text = data!.text!;
                              validate(data.text!);
                            }
                          },
                        ),
                      ],
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isValid ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          validationMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isValid ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isValid && parsedObject != null
                  ? () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Confirm Import'),
                          content: Text(
                            isConfig
                                ? 'This will update your workspace configuration and sync to GitHub. Proceed?'
                                : 'This will import the transaction ledger and sync with automated 3-way merge. Proceed?',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Proceed Import'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        Navigator.of(dialogCtx).pop();
                        if (isConfig) {
                          final ok = await repo.updateConfig(parsedObject as AppConfig);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok ? 'config.json imported and updated' : 'Saved locally (sync pending)',
                                ),
                              ),
                            );
                          }
                        } else {
                          final ok = await repo.importFundData(parsedObject as FundData);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok ? 'data.json imported and synchronized' : 'Saved locally (sync pending)',
                                ),
                              ),
                            );
                          }
                        }
                      }
                    }
                  : null,
                child: const Text('Import & Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onClick;

  const AdminActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onClick,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
