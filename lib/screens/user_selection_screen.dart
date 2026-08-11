
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class UserSelectionScreen extends ConsumerWidget {
  const UserSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final people = config.people.where((p) => p.active).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Who are you?')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Welcome to ${config.siteTitle}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];
                  return Card(
                    child: InkWell(
                      onTap: () async {
                        await ref.read(userProvider.notifier).state = person.id;
                        await ref.read(storageProvider).saveUser(person.id);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/dashboard');
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            child: Text(person.name[0].toUpperCase()),
                          ),
                          const SizedBox(height: 8),
                          Text(person.name),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

