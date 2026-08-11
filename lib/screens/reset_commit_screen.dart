
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class ResetCommitScreen extends ConsumerStatefulWidget {
  const ResetCommitScreen({super.key});

  @override
  ConsumerState<ResetCommitScreen> createState() => _ResetCommitScreenState();
}

class _ResetCommitScreenState extends ConsumerState<ResetCommitScreen> {
  List<Map<String, dynamic>> _commits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCommits();
  }

  Future<void> _loadCommits() async {
    setState(() => _loading = true);
    try {
      final config = ref.read(configProvider);
      final token = ref.read(authProvider);
      if (token == null) throw Exception('No PAT');
      final service = GitHubService(
        owner: config.repoOwner,
        repo: config.repoName,
        token: token,
        branch: config.repoBranch,
        dataFileName: config.dataFileName,
      );
      final commits = await service.getCommits();
      setState(() {
        _commits = commits;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Commit')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : ListView.builder(
                    itemCount: _commits.length,
                    itemBuilder: (context, index) {
                      final commit = _commits[index];
                      final sha = commit['sha'] as String;
                      final message = commit['commit']['message'] as String;
                      final date = commit['commit']['author']['date'] as String;
                      return ListTile(
                        title: Text(message),
                        subtitle: Text('$sha\n$date'),
                        onTap: () {
                          _showResetDialog(sha);
                        },
                      );
                    },
                  ),
      ),
    );
  }

  void _showResetDialog(String sha) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to this commit?'),
        content: const Text('This will force the branch to this commit.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final token = ref.read(authProvider);
              if (token == null) return;
              final config = ref.read(configProvider);
              final service = GitHubService(
                owner: config.repoOwner,
                repo: config.repoName,
                token: token,
                branch: config.repoBranch,
                dataFileName: config.dataFileName,
              );
              try {
                await service.resetToCommit(sha);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset successful!')),
                );
                // Refresh data
                await ref.read(dataProvider.notifier).syncDataFromGitHub(token: token);
                await ref.read(configProvider.notifier).syncConfigFromGitHub(token: token);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reset failed: $e')),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

