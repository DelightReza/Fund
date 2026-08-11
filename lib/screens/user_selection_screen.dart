import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class UserSelectionScreen extends ConsumerWidget {
  const UserSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final members = state.config.people.where((p) => p.active).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('User Selection')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: members.isEmpty
            ? const Center(child: Text('No active members found in config.json'))
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final person = members[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => ref.read(appStateProvider.notifier).selectUser(person.id),
                      child: Center(
                        child: Text(person.name, style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
