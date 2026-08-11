
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/github_service.dart';

class RepoSelectionScreen extends ConsumerStatefulWidget {
  const RepoSelectionScreen({super.key});

  @override
  ConsumerState<RepoSelectionScreen> createState() => _RepoSelectionScreenState();
}

class _RepoSelectionScreenState extends ConsumerState<RepoSelectionScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _showToken = false;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(storageProvider);
    final saved = storage.loadSavedRepos();

    return Scaffold(
      appBar: AppBar(title: const Text('Select Fund Repository')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect to a GitHub repository',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            if (saved.isNotEmpty) ...[
              const Text('Saved repositories:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: saved.length,
                  itemBuilder: (context, index) {
                    final entry = saved[index];
                    return ListTile(
                      leading: const Icon(Icons.book),
                      title: Text(entry),
                      onTap: () => _connect(entry),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          final updated = List<String>.from(saved)..removeAt(index);
                          storage.saveSavedRepos(updated);
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
            ],
            const Text('Or add a new one:'),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'owner/repo or full URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              obscureText: !_showToken,
              decoration: InputDecoration(
                labelText: 'GitHub Token (optional)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showToken = !_showToken),
                  icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : () => _connect(_urlController.text.trim()),
              child: _loading ? const CircularProgressIndicator() : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connect(String input) async {
    if (input.isEmpty) {
      setState(() => _error = 'Please enter a repository');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = _tokenController.text.trim().isNotEmpty
          ? _tokenController.text.trim()
          : null;
      // Parse owner/repo
      String owner, repo;
      if (input.contains('github.com') || input.contains('github.io')) {
        final uri = Uri.tryParse(input);
        if (uri != null) {
          final segments = uri.pathSegments;
          if (segments.isNotEmpty) {
            owner = segments[0];
            repo = segments.length > 1 ? segments[1] : '';
          } else {
            throw Exception('Invalid URL');
          }
        } else {
          throw Exception('Invalid URL');
        }
      } else {
        final parts = input.split('/');
        if (parts.length != 2) throw Exception('Invalid format, use owner/repo');
        owner = parts[0];
        repo = parts[1];
      }

      // Try to fetch config
      AppConfig config;
      try {
        final service = GitHubService(owner: owner, repo: repo, token: token);
        config = await service.fetchConfig();
      } catch (_) {
        // Fallback raw
        final rawUrl = 'https://raw.githubusercontent.com/$owner/$repo/main/config.json';
        config = await GitHubService.fetchConfigRaw(rawUrl);
      }

      // Save config
      final fullConfig = config.copyWith(
        repoOwner: owner,
        repoName: repo,
        repoBranch: 'main',
        dataFileName: 'data.json',
      );
      await ref.read(configProvider.notifier).setConfig(fullConfig);
      // Save repo
      final storage = ref.read(storageProvider);
      final saved = storage.loadSavedRepos();
      if (!saved.contains(input)) {
        storage.saveSavedRepos([...saved, input]);
      }
      // Save token if provided
      if (token != null) {
        await ref.read(authProvider.notifier).setToken(token);
      }
      // Navigate to user selection
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/user_selection');
      }
    } catch (e) {
      setState(() => _error = 'Failed to connect: $e');
    }
    setState(() => _loading = false);
  }
}

