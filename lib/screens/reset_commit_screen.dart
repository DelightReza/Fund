import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../models/github_models.dart';
import '../repositories/fund_repository.dart';
import '../services/github_api_service.dart';
import '../services/storage_service.dart';
import '../utils/date_utils.dart';
import '../widgets/admin_pat_modal.dart';
import '../widgets/confirmation_dialog.dart';

enum CommitFilterMode {
  all,
  data,
  config,
}

class ResetCommitScreen extends StatefulWidget {
  const ResetCommitScreen({super.key});

  @override
  State<ResetCommitScreen> createState() => _ResetCommitScreenState();
}

class _ResetCommitScreenState extends State<ResetCommitScreen> {
  final GitHubApiService _api = GitHubApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<GitHubCommit> _commits = [];
  bool _isLoading = true;
  String? _error;
  String? _revertingSha;
  CommitFilterMode _filterMode = CommitFilterMode.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCommits();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCommits() async {
    final storage = context.read<StorageService>();
    final config = context.read<FundRepository>().config ?? AppConfig();
    final token = await storage.getToken(owner: config.repoOwner, repo: config.repoName);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? pathFilter;
      if (_filterMode == CommitFilterMode.data) {
        pathFilter = config.dataFileName;
      } else if (_filterMode == CommitFilterMode.config) {
        pathFilter = 'config.json';
      }

      final list = await _api.getRecentCommits(
        token: token,
        owner: config.repoOwner,
        repo: config.repoName,
        path: pathFilter,
        perPage: 50,
      );

      if (mounted) {
        setState(() {
          _commits = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load repository commits: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<GitHubCommit> get _filteredCommits {
    if (_searchQuery.trim().isEmpty) return _commits;
    final q = _searchQuery.toLowerCase().trim();
    return _commits.where((c) {
      return c.message.toLowerCase().contains(q) ||
          c.authorName.toLowerCase().contains(q) ||
          c.sha.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _revertToCommit(GitHubCommit commit) async {
    final repo = context.read<FundRepository>();
    final storage = context.read<StorageService>();
    final config = repo.config ?? AppConfig();
    final shortSha = commit.sha.substring(0, 7.clamp(0, commit.sha.length));

    var token = await storage.getToken(owner: config.repoOwner, repo: config.repoName);
    if (token == null || token.trim().isEmpty) {
      final patEntered = await AdminPatModal.show(context);
      if (patEntered != true || !mounted) return;
      token = await storage.getToken(owner: config.repoOwner, repo: config.repoName);
      if (token == null || token.trim().isEmpty) return;
    }

    setState(() => _revertingSha = commit.sha);

    // Fetch snapshots at this commit SHA
    final oldDataJson = await _api.getFileContentAtCommit(
      owner: config.repoOwner,
      repo: config.repoName,
      sha: commit.sha,
      path: config.dataFileName,
      token: token,
    );

    final oldConfigJson = await _api.getFileContentAtCommit(
      owner: config.repoOwner,
      repo: config.repoName,
      sha: commit.sha,
      path: 'config.json',
      token: token,
    );

    if (!mounted) return;
    setState(() => _revertingSha = null);

    if (oldDataJson == null && oldConfigJson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text(
            'Neither ${config.dataFileName} nor config.json was found at commit $shortSha.',
          ),
        ),
      );
      return;
    }

    // Determine preview details
    FundData? previewData;
    if (oldDataJson != null) {
      try {
        previewData = FundData.fromJson(jsonDecode(oldDataJson));
      } catch (_) {}
    }

    bool revertData = oldDataJson != null;
    bool revertConfig = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Revert to Commit',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Commit metadata
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  shortSha,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  commit.authorName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            commit.message,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppDateUtils.formatDisplayDate(commit.date),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Select files to restore from this snapshot:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Option 1: Data ledger
                    if (oldDataJson != null) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: revertData,
                        title: Text(
                          'Ledger Data (${config.dataFileName})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: previewData != null
                            ? Text(
                                'Balance: ${config.currency}${previewData.poolBalance.toStringAsFixed(2)} • ${previewData.transactions.length} transactions',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              )
                            : const Text('Found in snapshot', style: TextStyle(fontSize: 11)),
                        onChanged: (val) => setDialogState(() => revertData = val ?? false),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '⚠️ ${config.dataFileName} did not exist in this commit',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ],

                    // Option 2: Config file
                    if (oldConfigJson != null) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: revertConfig,
                        title: const Text(
                          'Workspace Config (config.json)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Restores members, currency & group settings',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        onChanged: (val) => setDialogState(() => revertConfig = val ?? false),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'This will create a new commit on GitHub setting the selected files to this commit’s exact state.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Revert to Snapshot'),
                  onPressed: (!revertData && !revertConfig)
                      ? null
                      : () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _revertingSha = commit.sha);

    try {
      bool anySuccess = false;

      // 1. Revert Data
      if (revertData && oldDataJson != null) {
        final currentFile = await _api.getFileDetails(
          token: token,
          owner: config.repoOwner,
          repo: config.repoName,
          path: config.dataFileName,
        );

        final encoded = base64.encode(utf8.encode(oldDataJson));
        final ok = await _api.updateFile(
          token: token,
          owner: config.repoOwner,
          repo: config.repoName,
          path: config.dataFileName,
          message: 'Revert ${config.dataFileName} to $shortSha: ${commit.message}',
          base64Content: encoded,
          sha: currentFile?.sha,
        );

        if (ok) {
          anySuccess = true;
          try {
            final parsed = FundData.fromJson(jsonDecode(oldDataJson));
            await storage.saveDataCache(parsed, owner: config.repoOwner, repo: config.repoName);
          } catch (_) {}
        }
      }

      // 2. Revert Config
      if (revertConfig && oldConfigJson != null) {
        final currentConfigFile = await _api.getFileDetails(
          token: token,
          owner: config.repoOwner,
          repo: config.repoName,
          path: 'config.json',
        );

        final encoded = base64.encode(utf8.encode(oldConfigJson));
        final ok = await _api.updateFile(
          token: token,
          owner: config.repoOwner,
          repo: config.repoName,
          path: 'config.json',
          message: 'Revert config.json to $shortSha: ${commit.message}',
          base64Content: encoded,
          sha: currentConfigFile?.sha,
        );

        if (ok) {
          anySuccess = true;
          try {
            final parsed = AppConfig.fromJson(jsonDecode(oldConfigJson));
            await storage.saveConfig(parsed, owner: config.repoOwner, repo: config.repoName);
          } catch (_) {}
        }
      }

      if (anySuccess) {
        await repo.refreshAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF047857),
              content: Text('✓ Successfully restored snapshot from commit $shortSha'),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              content: const Text('Failed to update files on GitHub. Please verify your token permissions.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Error during revert: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _revertingSha = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<FundRepository>().config ?? AppConfig();
    final filtered = _filteredCommits;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Commit History & Revert', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              '${config.repoOwner}/${config.repoName}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh commits',
            onPressed: _loadCommits,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Mode Segmented Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: SegmentedButton<CommitFilterMode>(
              segments: [
                const ButtonSegment<CommitFilterMode>(
                  value: CommitFilterMode.all,
                  label: Text('Full Repo'),
                  icon: Icon(Icons.all_inclusive_rounded, size: 16),
                ),
                ButtonSegment<CommitFilterMode>(
                  value: CommitFilterMode.data,
                  label: Text(config.dataFileName),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                ),
                const ButtonSegment<CommitFilterMode>(
                  value: CommitFilterMode.config,
                  label: Text('config.json'),
                  icon: Icon(Icons.settings_rounded, size: 16),
                ),
              ],
              selected: {_filterMode},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _filterMode = newSelection.first;
                });
                _loadCommits();
              },
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by message, author, or SHA...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Count & Status Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _filterMode == CommitFilterMode.all
                      ? 'Full Repository Commits (${filtered.length})'
                      : _filterMode == CommitFilterMode.data
                          ? 'Ledger Data Commits (${filtered.length})'
                          : 'Config Commits (${filtered.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                if (_searchQuery.isNotEmpty)
                  Text(
                    'Filtered: ${filtered.length} of ${_commits.length}',
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
              ],
            ),
          ),

          // Commits List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _loadCommits,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No commits matching "$_searchQuery"'
                                        : 'No commits found for this selection.',
                                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final c = filtered[index];
                              final isReverting = _revertingSha == c.sha;
                              final shortSha = c.sha.substring(0, 7.clamp(0, c.sha.length));

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.15)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top row: Commit badge + Author + Date
                                      Row(
                                        children: [
                                          InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: c.sha));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  duration: const Duration(seconds: 2),
                                                  content: Text('Copied SHA: ${c.sha}'),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primaryContainer,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    shortSha,
                                                    style: TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.copy_rounded,
                                                    size: 11,
                                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              c.authorName.isNotEmpty ? c.authorName : 'Unknown',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            AppDateUtils.formatDisplayDate(c.date),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Commit message
                                      Text(
                                        c.message,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 8),

                                      // Bottom Actions: Revert Button
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (isReverting) ...[
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Checking snapshot...',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ] else ...[
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFDC2626),
                                                side: const BorderSide(color: Color(0xFFDC2626)),
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              ),
                                              icon: const Icon(Icons.history_rounded, size: 16),
                                              label: const Text('Revert to this'),
                                              onPressed: () => _revertToCommit(c),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
