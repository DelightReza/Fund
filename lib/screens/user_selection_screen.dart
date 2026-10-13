import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/fund_repository.dart';
import '../services/storage_service.dart';
import '../widgets/glass_container.dart';
import 'main_screen.dart';

class UserSelectionScreen extends StatelessWidget {
  const UserSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<FundRepository>();
    final config = repo.config;
    final members = config?.members.where((m) => m.active).toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Who are you?'),
      ),
      body: AuroraBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select your profile',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This helps filter your personal shares, paid expenses, and debt settlements.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (members.isEmpty) ...[
                    GlassContainer(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text(
                              'No active members configured in config.json.'),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen()),
                              );
                            },
                            child: const Text('Continue as Guest'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ...members.map(
                      (member) => GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        borderRadius: 18,
                        padding: EdgeInsets.zero,
                        onTap: () async {
                          final storage = context.read<StorageService>();
                          await storage.saveUser(member.id);
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => const MainScreen()),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  member.name.isNotEmpty
                                      ? member.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    Text('@${member.id}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
