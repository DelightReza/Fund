import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/fund_repository.dart';
import '../services/github_api_service.dart';
import '../services/storage_service.dart';

class AdminPatModal extends StatefulWidget {
  const AdminPatModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const AdminPatModal(),
    );
  }

  @override
  State<AdminPatModal> createState() => _AdminPatModalState();
}

class _AdminPatModalState extends State<AdminPatModal> {
  final TextEditingController _patController = TextEditingController();
  final GitHubApiService _api = GitHubApiService();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    final token = storage.currentToken ?? '';
    _patController.text = token;
  }

  @override
  void dispose() {
    _patController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndSave() async {
    final token = _patController.text.trim();
    if (token.isEmpty) {
      setState(() => _errorMessage =
          'Please enter your GitHub Personal Access Token (PAT)');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final repo = context.read<FundRepository>();
    final storage = context.read<StorageService>();
    final config = repo.config;

    final owner = config?.repoOwner ?? storage.activeRepoOwner ?? '';
    final repoName = config?.repoName ?? storage.activeRepoName ?? '';

    if (owner.isEmpty || repoName.isEmpty) {
      setState(() {
        _isVerifying = false;
        _errorMessage =
            'No active repository selected. Please connect a repo first.';
      });
      return;
    }

    final hasAccess = await _api.verifyRepoAccess(
      token: token,
      owner: owner,
      repo: repoName,
    );

    if (!mounted) return;

    if (hasAccess) {
      await storage.saveToken(token, owner: owner, repo: repoName);
      await storage.setAdminVerified(true, owner: owner, repo: repoName);

      // Auto-sync if there was pending changes
      if (storage.hasPendingSyncFlagFor(owner: owner, repo: repoName)) {
        await repo.syncPending(token);
      }

      setState(() => _isVerifying = false);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🛡️ Verified write access for $owner/$repoName'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      setState(() {
        _isVerifying = false;
        _errorMessage =
            'Invalid PAT or insufficient write permissions for $owner/$repoName.';
      });
    }
  }

  Future<void> _revokeAccess() async {
    final storage = context.read<StorageService>();
    final repo = context.read<FundRepository>();
    final owner = repo.config?.repoOwner ?? storage.activeRepoOwner;
    final repoName = repo.config?.repoName ?? storage.activeRepoName;

    await storage.saveToken(null, owner: owner, repo: repoName);
    await storage.setAdminVerified(false, owner: owner, repo: repoName);

    if (mounted) {
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin session signed out.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = context.watch<StorageService>();
    final repo = context.watch<FundRepository>();
    final owner = repo.config?.repoOwner ?? storage.activeRepoOwner ?? '';
    final repoName = repo.config?.repoName ?? storage.activeRepoName ?? '';
    final isAlreadyVerified = storage.isAdminVerified;

    return AlertDialog(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF151F32).withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAlreadyVerified
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: isAlreadyVerified
                  ? const Color(0xFF10B981)
                  : theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAlreadyVerified
                      ? 'Admin Authorized'
                      : 'Admin Authorization',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (owner.isNotEmpty)
                  Text(
                    '$owner/$repoName',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.normal),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAlreadyVerified
                    ? 'Your GitHub Personal Access Token is verified with write access to this repository. You can manage transactions, configuration, and rollback commits.'
                    : 'Enter your GitHub Personal Access Token (PAT) with repo scope to unlock Admin controls and transaction editing.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _patController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'GitHub Personal Access Token',
                  hintText: 'ghp_...',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: _errorMessage,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Token requires "repo" or contents write permissions.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isAlreadyVerified)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _isVerifying ? null : _revokeAccess,
            child: const Text('Sign Out Admin'),
          ),
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isVerifying ? null : _verifyAndSave,
          icon: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.verified_user_rounded, size: 18),
          label: Text(_isVerifying
              ? 'Verifying...'
              : (isAlreadyVerified ? 'Update Token' : 'Verify & Unlock')),
        ),
      ],
    );
  }
}
