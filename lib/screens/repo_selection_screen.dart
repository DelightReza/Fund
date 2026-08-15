import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_repo.dart';
import '../providers/providers.dart';

class RepoSelectionScreen extends ConsumerStatefulWidget {
  const RepoSelectionScreen({super.key});

  @override
  ConsumerState<RepoSelectionScreen> createState() => _RepoSelectionScreenState();
}

class _RepoSelectionScreenState extends ConsumerState<RepoSelectionScreen> {
  final _urlController = TextEditingController();
  final _ownerController = TextEditingController(text: 'DelightReza');
  final _repoController = TextEditingController(text: 'Fund-Template-App');
  final _branchController = TextEditingController(text: 'main');
  final _dataFileController = TextEditingController(text: 'data.json');
  final _tokenController = TextEditingController();
  final _titleController = TextEditingController();

  bool _showAddForm = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _ownerController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    _dataFileController.dispose();
    _tokenController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _parseUrl(String value) {
    final clean = value.trim();
    if (clean.contains('github.com/')) {
      try {
        final uri = Uri.parse(clean.startsWith('http') ? clean : 'https://$clean');
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.length >= 2) {
          setState(() {
            _ownerController.text = segments[0];
            _repoController.text = segments[1].replaceAll('.git', '');
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final savedRepos = appState.savedRepos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repositories'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _showAddForm = !_showAddForm);
            },
            icon: Icon(_showAddForm ? Icons.close : Icons.add),
            tooltip: _showAddForm ? 'Close Add Form' : 'Add Repository',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (savedRepos.isNotEmpty && !_showAddForm) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Saved Repositories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ...savedRepos.map((repo) => _buildRepoCard(context, repo)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAddForm = true),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Repository'),
                ),
              ],

              if (savedRepos.isEmpty || _showAddForm) ...[
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          savedRepos.isEmpty ? 'Connect GitHub Repository' : 'Add New Repository',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Connect your repository to sync fund transactions and configuration data.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'Paste GitHub URL (optional)',
                            hintText: 'https://github.com/DelightReza/Fund-Template-App',
                            prefixIcon: Icon(Icons.link),
                          ),
                          onChanged: _parseUrl,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _ownerController,
                                decoration: const InputDecoration(labelText: 'GitHub Owner *'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _repoController,
                                decoration: const InputDecoration(labelText: 'Repository Name *'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _branchController,
                                decoration: const InputDecoration(labelText: 'Branch'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _dataFileController,
                                decoration: const InputDecoration(labelText: 'Data File'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Display Title / Nickname (optional)',
                            hintText: 'e.g. My Expense Tracker',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _tokenController,
                          decoration: const InputDecoration(
                            labelText: 'GitHub Personal Access Token (PAT)',
                            hintText: 'ghp_xxxxxxxxxxxx',
                            helperText: 'Required to push changes to GitHub. Leave blank for read-only.',
                            prefixIcon: Icon(Icons.key),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Fill DelightReza Template'),
                              onPressed: () {
                                setState(() {
                                  _ownerController.text = 'DelightReza';
                                  _repoController.text = 'Fund-Template-App';
                                  _branchController.text = 'main';
                                  _dataFileController.text = 'data.json';
                                  _titleController.text = 'Fund Template';
                                });
                              },
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (savedRepos.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(() => _showAddForm = false),
                                child: const Text('Cancel'),
                              ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _loading ? null : _connect,
                              icon: _loading
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check),
                              label: Text(_loading ? 'Connecting...' : 'Connect & Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepoCard(BuildContext context, SavedRepo repo) {
    final activeConfig = ref.watch(appStateProvider).config;
    final isActive = activeConfig.repoOwner.toLowerCase() == repo.owner.toLowerCase() && activeConfig.repoName.toLowerCase() == repo.repo.toLowerCase();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.folder_special : Icons.folder_outlined,
                  color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repo.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${repo.owner}/${repo.repo} (${repo.branch})',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'token') {
                      _promptTokenDialog(context, repo);
                    } else if (val == 'delete') {
                      _confirmDeleteRepo(context, repo);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'token', child: Text('Update PAT Token')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Repository', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  avatar: Icon(
                    repo.hasToken ? Icons.check_circle : Icons.warning_amber,
                    size: 16,
                    color: repo.hasToken ? Colors.green : Colors.amber.shade800,
                  ),
                  label: Text(
                    repo.hasToken ? 'PAT Configured' : 'No PAT (Read-Only)',
                    style: TextStyle(
                      fontSize: 12,
                      color: repo.hasToken ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                  backgroundColor: repo.hasToken ? Colors.green.shade50 : Colors.amber.shade50,
                  side: BorderSide.none,
                ),
                const Spacer(),
                if (isActive)
                  const Chip(
                    label: Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    backgroundColor: Colors.blue,
                    side: BorderSide.none,
                  )
                else
                  FilledButton.tonal(
                    onPressed: () {
                      ref.read(appStateProvider.notifier).switchRepository(repo);
                    },
                    child: const Text('Switch Repo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptTokenDialog(BuildContext context, SavedRepo repo) async {
    final tokenCtrl = TextEditingController(text: repo.token ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('GitHub PAT for ${repo.displayTitle}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter Personal Access Token to enable pushing changes to GitHub:'),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              decoration: const InputDecoration(labelText: 'GitHub Token', hintText: 'ghp_...'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save Token')),
        ],
      ),
    );

    if (result == true) {
      try {
        final token = tokenCtrl.text.trim();
        await ref.read(appStateProvider.notifier).setToken(token.isEmpty ? null : token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token updated!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _confirmDeleteRepo(BuildContext context, SavedRepo repo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Repository?'),
        content: Text('Remove ${repo.displayTitle} from saved repositories?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(appStateProvider.notifier).deleteSavedRepository(repo.id);
    }
  }

  Future<void> _connect() async {
    final owner = _ownerController.text.trim();
    final repo = _repoController.text.trim();
    if (owner.isEmpty || repo.isEmpty) {
      setState(() => _error = 'GitHub owner and repository name are required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(appStateProvider.notifier).connectRepository(
            owner: owner,
            repo: repo,
            branch: _branchController.text.trim().isEmpty ? 'main' : _branchController.text.trim(),
            dataFileName: _dataFileController.text.trim().isEmpty ? 'data.json' : _dataFileController.text.trim(),
            token: _tokenController.text.trim().isEmpty ? null : _tokenController.text.trim(),
            title: _titleController.text.trim(),
          );
      setState(() => _showAddForm = false);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
