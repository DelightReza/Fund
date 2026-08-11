import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class RepoSelectionScreen extends ConsumerStatefulWidget {
  const RepoSelectionScreen({super.key});

  @override
  ConsumerState<RepoSelectionScreen> createState() => _RepoSelectionScreenState();
}

class _RepoSelectionScreenState extends ConsumerState<RepoSelectionScreen> {
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');
  final _dataFileController = TextEditingController(text: 'data.json');
  final _tokenController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repository Selection')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(controller: _ownerController, decoration: const InputDecoration(labelText: 'GitHub owner')),
              const SizedBox(height: 12),
              TextField(controller: _repoController, decoration: const InputDecoration(labelText: 'Repository name')),
              const SizedBox(height: 12),
              TextField(controller: _branchController, decoration: const InputDecoration(labelText: 'Branch')),
              const SizedBox(height: 12),
              TextField(controller: _dataFileController, decoration: const InputDecoration(labelText: 'Data file name')),
              const SizedBox(height: 12),
              TextField(controller: _tokenController, decoration: const InputDecoration(labelText: 'GitHub PAT (optional)'), obscureText: true),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _connect,
                child: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final owner = _ownerController.text.trim();
    final repo = _repoController.text.trim();
    if (owner.isEmpty || repo.isEmpty) {
      setState(() => _error = 'Owner and repository are required.');
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
          );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
