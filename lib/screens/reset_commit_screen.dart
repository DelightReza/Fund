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
import '../widgets/glass_container.dart';
import '../utils/app_router.dart';

class ResetCommitScreen extends StatefulWidget {
  final bool isRestoredAfterRefresh;

  const ResetCommitScreen({
    super.key,
    this.isRestoredAfterRefresh = false,
  });

  @override
  State<ResetCommitScreen> createState() => _ResetCommitScreenState();
}

class _ResetCommitScreenState extends State<ResetCommitScreen> {
  final GitHubApiService _api = GitHubApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<GitHubCommit> _commits = [];
  bool _isLoading = true;
  String? _error;
  String? _resettingSha;
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
      final list = await _api.getRecentCommits(
        token: token,
        owner: config.repoOwner,
        repo: config.repoName,
        branch: config.repoBranch.isNotEmpty ? config.repoBranch : null,
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

  Future<void> _hardResetToCommit(GitHubCommit commit, {bool isHeadMinusOne = false}) async {
    final repo = context.read<FundRepository>();
    final storage = context.read<StorageService>();
    final config = repo.config ?? AppConfig();
    final shortSha = commit.sha.substring(0, 7.clamp(0, commit.sha.length));
    final branch = config.repoBranch.isEmpty ? 'main' : config.repoBranch;

    var token = await storage.getToken(owner: config.repoOwner, repo: config.repoName);
    if (token == null || token.trim().isEmpty) {
      final patEntered = await AdminPatModal.show(context);
      if (patEntered != true || !mounted) return;
      token = await storage.getToken(owner: config.repoOwner, repo: config.repoName);
      if (token == null || token.trim().isEmpty) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Hard Reset (git reset --hard)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward_rounded, color: Color(0xFFB91C1C), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            isHeadMinusOne ? 'Target: HEAD~1 ($shortSha)' : 'Target: $shortSha',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        commit.message,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF450A0A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By ${commit.authorName} on ${AppDateUtils.formatDisplayDate(commit.date)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Git Command Equivalent:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'git reset --hard $shortSha\ngit push origin $branch --force',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ WARNING: This forcefully moves branch HEAD directly to this commit. Any commits made after this will be discarded from branch history.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.3),
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
              icon: const Icon(Icons.restore_page_rounded, size: 16),
              label: const Text('Execute Reset'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _resettingSha = commit.sha);

    try {
      final result = await _api.hardResetBranchRef(
        token: token,
        owner: config.repoOwner,
        repo: config.repoName,
        branch: branch,
        targetSha: commit.sha,
      );

      if (result.isSuccess) {
        // Fetch files at the new HEAD and update local cache
        final newLedgerJson = await _api.getFileContentAtCommit(
          owner: config.repoOwner,
          repo: config.repoName,
          sha: commit.sha,
          path: config.dataFileName,
          token: token,
        );
        if (newLedgerJson != null) {
          try {
            final parsed = FundData.fromJson(jsonDecode(newLedgerJson));
            await storage.saveDataCache(parsed, owner: config.repoOwner, repo: config.repoName);
          } catch (_) {}
        }

        final newConfigJson = await _api.getFileContentAtCommit(
          owner: config.repoOwner,
          repo: config.repoName,
          sha: commit.sha,
          path: 'config.json',
          token: token,
        );
        if (newConfigJson != null) {
          try {
            final parsed = AppConfig.fromJson(jsonDecode(newConfigJson));
            await storage.saveConfig(parsed, owner: config.repoOwner, repo: config.repoName);
          } catch (_) {}
        }

        await repo.refreshAll();
        await _loadCommits();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF047857),
              content: Text('✓ Hard reset to $shortSha completed (HEAD is now at $shortSha)'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              content: Text(
                'Failed to reset branch: ${result.errorMessage ?? "HTTP ${result.statusCode}"}. Check branch protection or token permissions.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Error executing git reset: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _resettingSha = null);
      }
    }
  }

  Widget _buildQuickResetHeadCard(AppConfig config, BuildContext context) {
    if (_commits.length < 2) return const SizedBox.shrink();
    final parentCommit = _commits[1];
    final parentShortSha = parentCommit.sha.substring(0, 7.clamp(0, parentCommit.sha.length));
    final latestCommit = _commits[0];
    final latestShortSha = latestCommit.sha.substring(0, 7.clamp(0, latestCommit.sha.length));
    final isResetting = _resettingSha == parentCommit.sha;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.undo_rounded, color: Color(0xFFEF4444), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Quick Undo: Reset HEAD~1',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'git reset --hard HEAD~1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Discards latest commit $latestShortSha ("${latestCommit.message}") and resets branch HEAD back to $parentShortSha.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                icon: isResetting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.restore_page_rounded, size: 16),
                label: Text(isResetting ? 'Resetting HEAD...' : 'Reset HEAD~1'),
                onPressed: isResetting ? null : () => _hardResetToCommit(parentCommit, isHeadMinusOne: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<FundRepository>().config ?? AppConfig();
    final filtered = _filteredCommits;

    void handleBack() {
      AppRouter.popOrNavigateTo(
        context,
        'admin',
        forceDirect: widget.isRestoredAfterRefresh,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: handleBack,
          ),
          title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reset Commit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              '${config.repoOwner}/${config.repoName} • ${config.repoBranch.isEmpty ? "main" : config.repoBranch}',
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
      body: AuroraBackground(
        child: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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

          // Quick Undo Banner if available
          if (!_isLoading && _searchQuery.isEmpty)
            _buildQuickResetHeadCard(config, context),

          // Count & Status Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Repository Commits (${filtered.length})',
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
                              final isResetting = _resettingSha == c.sha;
                              final isHead = index == 0 && _searchQuery.isEmpty;
                              final shortSha = c.sha.substring(0, 7.clamp(0, c.sha.length));

                              return GlassCard(
                                borderRadius: 18,
                                padding: const EdgeInsets.all(14),
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
                                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (isHead) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade700,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'HEAD',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
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

                                      // Bottom Actions: Reset Button
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (isResetting) ...[
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Resetting branch HEAD...',
                                              style: TextStyle(fontSize: 12, color: Colors.red),
                                            ),
                                          ] else if (isHead) ...[
                                            Text(
                                              'Current Branch Head',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ] else ...[
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFDC2626),
                                                side: const BorderSide(color: Color(0xFFDC2626)),
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              ),
                                              icon: const Icon(Icons.restore_page_rounded, size: 16),
                                              label: const Text('Reset HEAD to here'),
                                              onPressed: () => _hardResetToCommit(c),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                            },
                          ),
          ),
        ],
      ),
    ),
    ),
  );
}
}
