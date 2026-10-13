import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../repositories/fund_repository.dart';
import '../services/storage_service.dart';
import '../utils/debt_simplifier.dart';
import '../utils/format_utils.dart';
import '../utils/web_route_helper.dart';
import '../widgets/admin_pat_modal.dart';
import '../widgets/glass_container.dart';
import '../widgets/admin/admin_action_card.dart';
import '../widgets/admin/admin_data_management_helper.dart';
import 'add_transaction_screen.dart';
import 'manage_config_screen.dart';
import 'reset_commit_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isSyncing = false;

  void _openAddTransaction(String initialType) {
    WebRouteHelper.setRoute('add_tx?from=admin');
    context.read<StorageService>().pushRoute('add_tx?from=admin');
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          initialType: initialType,
          returnRoute: 'admin',
        ),
      ),
    )
        .then((_) {
      if (mounted) {
        WebRouteHelper.setRoute('admin');
        context.read<StorageService>().popRoute();
      }
    });
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
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7)),
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
      text:
          'Push update: ledger with $totalCount transactions from Admin panel',
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857)),
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
            backgroundColor:
                ok ? const Color(0xFF047857) : Colors.orange.shade800,
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
            backgroundColor:
                ok ? const Color(0xFF047857) : Colors.orange.shade800,
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
    final hasToken =
        storage.currentToken != null && storage.currentToken!.isNotEmpty;
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
                        Icon(Icons.sync_rounded,
                            color: Color(0xFF0284C7), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'GitHub Sync & Replication',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Repository:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                          Text(
                            '${config.repoOwner}/${config.repoName}',
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Token Status:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasToken
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hasToken
                                  ? '✓ PAT Configured'
                                  : '⚠️ No PAT Connected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: hasToken
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Local Ledger:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                          Text('$txCount transactions',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (hasPending) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pending Sync:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.orange)),
                            Text(
                              'Offline changes unpushed',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800),
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
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: Color(0xFF0284C7), size: 22),
                ),
                title: const Text('Pull from GitHub (Fetch Latest)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Download latest data.json & config.json from repo, overwriting local state'),
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
                    color: const Color(0xFF047857).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_rounded,
                      color: Color(0xFF047857), size: 22),
                ),
                title: const Text('Push to GitHub (Commit Local Data)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Upload $txCount local transactions and update data.json on GitHub'),
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
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sync_rounded,
                      color: Color(0xFF7C3AED), size: 22),
                ),
                title: const Text('Auto Sync (Push Pending & Pull)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Push any pending offline changes and refresh latest remote updates'),
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
                    color: Colors.blueGrey.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.vpn_key_outlined,
                      color: Colors.blueGrey, size: 22),
                ),
                title: const Text('GitHub Token (PAT) Settings',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Configure or test your GitHub Personal Access Token permissions'),
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
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            tooltip: theme.brightness == Brightness.dark
                ? 'Switch to Light Mode'
                : 'Switch to Dark/Night Mode',
            onPressed: () => storage.toggleTheme(context),
          ),
          IconButton(
            icon: const Icon(Icons.shield, color: Color(0xFF10B981)),
            tooltip: 'Admin Authorization (PAT Active)',
            onPressed: () => AdminPatModal.show(context),
          ),
        ],
      ),
      body: AuroraBackground(
        child: ListView(
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
                      WebRouteHelper.setRoute('reset_commit');
                      context.read<StorageService>().pushRoute('reset_commit');
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(
                            builder: (_) => const ResetCommitScreen()),
                      )
                          .then((_) {
                        if (mounted) {
                          WebRouteHelper.setRoute('admin');
                          context.read<StorageService>().popRoute();
                        }
                      });
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
                    icon: _isSyncing
                        ? Icons.hourglass_top_rounded
                        : Icons.sync_rounded,
                    color: const Color(0xFF0284C7),
                    onClick:
                        _isSyncing ? null : () => _showSyncGitHubModal(repo),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Debt Simplifier Section (if settlements exist)
            if (settlements.isNotEmpty) ...[
              _buildSectionTitle(context, 'Debt Simplifier'),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: settlements.map((s) {
                    final fromName = config.members
                        .firstWhere((m) => m.id == s.from,
                            orElse: () =>
                                MemberConfig(id: s.from, name: s.from))
                        .name;
                    final toName = config.members
                        .firstWhere((m) => m.id == s.to,
                            orElse: () => MemberConfig(id: s.to, name: s.to))
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
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.arrow_forward,
                                      size: 14, color: Colors.grey),
                                ),
                                Flexible(
                                  child: Text(
                                    toName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            FormatUtils.formatCurrency(
                                s.amount, config.currency),
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
              const SizedBox(height: 24),
            ],

            // 4. Configuration Section (Liquid Glass Cards)
            _buildSectionTitle(context, 'Configuration'),
            const SizedBox(height: 12),

            GlassCard(
              borderRadius: 18,
              padding: EdgeInsets.zero,
              onTap: () {
                WebRouteHelper.setRoute('manage_config');
                context.read<StorageService>().pushRoute('manage_config');
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(builder: (_) => const ManageConfigScreen()),
                )
                    .then((_) {
                  if (mounted) {
                    WebRouteHelper.setRoute('admin');
                    context.read<StorageService>().popRoute();
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.settings,
                          color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage Config',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'People, categories, currency & repository sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
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
            const SizedBox(height: 12),

            // Cache Reset Tile
            GlassCard(
              borderRadius: 18,
              padding: EdgeInsets.zero,
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
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear Cache'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  await storage.clearCacheOnly(
                      owner: config.repoOwner, repo: config.repoName);
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
                        color: Colors.red.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.delete_sweep_rounded,
                          color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Clear Local Cache',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Delete cached offline files and re-sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
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
            const SizedBox(height: 80),
          ],
        ),
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
    AdminDataManagementHelper.showManageDataModal(
      context: context,
      repo: repo,
      onCopy: _copyToClipboard,
      onShowRawJson: _showRawJsonModal,
    );
  }
}
