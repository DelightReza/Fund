import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../screens/repo_selection_screen.dart';

/// An authentication guard widget that verifies whether a valid session token
/// exists. If authenticated, it renders [child]. If not authenticated, it renders
/// [fallback] (if provided) or a user-friendly locked state with an action to
/// configure/authenticate with a GitHub Personal Access Token.
class AuthGuard extends ConsumerWidget {
  const AuthGuard({
    super.key,
    required this.child,
    this.fallback,
    this.title = 'Admin Access Required',
    this.message = 'A valid GitHub Personal Access Token (PAT) is required to access administrative controls.',
    this.onAuthenticated,
  });

  final Widget child;
  final Widget? fallback;
  final String title;
  final String message;
  final VoidCallback? onAuthenticated;

  void _showTokenDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ref.read(appStateProvider).token ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter GitHub PAT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide a Personal Access Token with repo scope to authenticate for administrative actions.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token',
                hintText: 'ghp_...',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final token = controller.text.trim();
              if (token.isNotEmpty) {
                await ref.read(appStateProvider.notifier).setToken(token);
                ref.read(appStateProvider.notifier).syncNow();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save & Authenticate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (isAuthenticated) {
      onAuthenticated?.call();
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        if (kIsWeb) {
                          _showTokenDialog(context, ref);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RepoSelectionScreen(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('Authenticate with Token'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
