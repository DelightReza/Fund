import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/github_service.dart';
import '../widgets/auth_guard.dart';

class ResetCommitScreen extends ConsumerStatefulWidget {
  const ResetCommitScreen({super.key});

  @override
  ConsumerState<ResetCommitScreen> createState() => _ResetCommitScreenState();
}

class _ResetCommitScreenState extends ConsumerState<ResetCommitScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _commits = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final state = ref.read(appStateProvider);
    if (state.token == null || state.token!.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'PAT is required for reset operations.';
      });
      return;
    }

    try {
      final github = GitHubService(
        owner: state.config.repoOwner,
        repo: state.config.repoName,
        branch: state.config.repoBranch,
        dataFileName: state.config.dataFileName,
        token: state.token,
      );
      final commits = await github.getCommits();
      if (mounted) {
        setState(() {
          _commits = commits;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      title: 'Reset Remote Branch',
      message: 'A valid Personal Access Token is required to inspect and reset remote Git commits.',
      child: Scaffold(
        appBar: AppBar(title: const Text('Reset Commit')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView.builder(
                    itemCount: _commits.length,
                    itemBuilder: (context, index) {
                      final commit = _commits[index];
                      final sha = (commit['sha'] ?? '').toString();
                      final message = (commit['commit']?['message'] ?? '').toString();
                      return ListTile(
                        title: Text(message),
                        subtitle: Text(sha),
                        onTap: () => _confirmReset(sha),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _confirmReset(String sha) async {
    final state = ref.read(appStateProvider);
    final github = GitHubService(
      owner: state.config.repoOwner,
      repo: state.config.repoName,
      branch: state.config.repoBranch,
      dataFileName: state.config.dataFileName,
      token: state.token,
    );

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to commit?'),
        content: Text(sha),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );

    if (approved != true) return;

    try {
      await github.resetToCommit(sha);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch reset completed.')));
      await ref.read(appStateProvider.notifier).refreshReadOnly();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
