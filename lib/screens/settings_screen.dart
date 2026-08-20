import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config.dart';
import '../providers/providers.dart';
import '../widgets/auth_guard.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _currencyController = TextEditingController();
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _branchController = TextEditingController();
  final _dataFileController = TextEditingController();

  List<MemberConfig> _people = [];
  List<BillTypeConfig> _billTypes = [];

  @override
  void initState() {
    super.initState();
    final config = ref.read(appStateProvider).config;
    _titleController.text = config.siteTitle;
    _subtitleController.text = config.siteSubtitle;
    _currencyController.text = config.currency;
    _ownerController.text = config.repoOwner;
    _repoController.text = config.repoName;
    _branchController.text = config.repoBranch;
    _dataFileController.text = config.dataFileName;

    _people = List.from(config.people);
    _billTypes = List.from(config.billTypes);
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      title: 'Configuration Settings',
      message: 'A valid Personal Access Token is required to modify repository configuration and settings.',
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          const Text('Basic Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Site Title')),
          const SizedBox(height: 12),
          TextField(controller: _subtitleController, decoration: const InputDecoration(labelText: 'Site Subtitle')),
          const SizedBox(height: 12),
          TextField(controller: _currencyController, decoration: const InputDecoration(labelText: 'Currency Symbol')),
          const SizedBox(height: 24),

          const Text('Repository Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          TextField(controller: _ownerController, decoration: const InputDecoration(labelText: 'Repository Owner')),
          const SizedBox(height: 12),
          TextField(controller: _repoController, decoration: const InputDecoration(labelText: 'Repository Name')),
          const SizedBox(height: 12),
          TextField(controller: _branchController, decoration: const InputDecoration(labelText: 'Branch')),
          const SizedBox(height: 12),
          TextField(controller: _dataFileController, decoration: const InputDecoration(labelText: 'Data File Name')),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton.icon(onPressed: _addMember, icon: const Icon(Icons.person_add), label: const Text('Add Member')),
            ],
          ),
          Card(
            child: _people.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('No members configured.'))
                : Column(
                    children: _people.asMap().entries.map((entry) {
                      final index = entry.key;
                      final person = entry.value;
                      return ListTile(
                        leading: CircleAvatar(child: Text(person.name.isNotEmpty ? person.name[0].toUpperCase() : '?')),
                        title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(person.id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: person.active,
                              onChanged: (val) {
                                setState(() {
                                  _people[index] = person.copyWith(active: val);
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Remove this person?'),
                                    content: const Text(
                                        'Historical data will still exist but won\'t be linked directly in dropdowns.'),
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
                                  setState(() {
                                    _people.removeAt(index);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bill Types / Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton.icon(onPressed: _addBillType, icon: const Icon(Icons.add_circle_outline), label: const Text('Add Category')),
            ],
          ),
          Card(
            child: _billTypes.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('No bill types configured.'))
                : Column(
                    children: _billTypes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final bill = entry.value;
                      return ListTile(
                        leading: Text(bill.icon, style: const TextStyle(fontSize: 24)),
                        title: Text(bill.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(bill.id),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove this bill category?'),
                                content: const Text('Existing transactions using this category will keep their data, but it will disappear from pickers.'),
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
                              setState(() {
                                _billTypes.removeAt(index);
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _saveSettings,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload),
            label: Text(_saving ? 'Pushing to GitHub...' : 'Save & Push Configuration'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
}

  /// Matches the slugification used by the TypeScript web app and the
  /// Kotlin app's expectations for member/bill-type ids, so ids generated
  /// here stay consistent with ids created by the other clients against
  /// the same shared config.json.
  String _slugify(String input) {
    final lower = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    return lower.replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  Future<void> _addMember() async {
    final nameCtrl = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Display Name', errorText: errorText),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = 'Name is required');
                  return;
                }
                final id = _slugify(name);
                final duplicate = _people.any((p) => p.id == id || p.name.toLowerCase() == name.toLowerCase());
                if (id.isEmpty || duplicate) {
                  setDialogState(() => errorText = 'Person already exists');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      setState(() {
        _people.add(MemberConfig(id: _slugify(name), name: name));
      });
    }
  }

  Future<void> _addBillType() async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '🧾');
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Bill Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(labelText: 'Emoji Icon'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Bill Type Name', errorText: errorText),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = 'Name is required');
                  return;
                }
                final id = _slugify(name);
                final duplicate = _billTypes.any((b) => b.id == id || b.name.toLowerCase() == name.toLowerCase());
                if (id.isEmpty || duplicate) {
                  setDialogState(() => errorText = 'Bill type already exists');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final icon = iconCtrl.text.trim().isEmpty ? '🧾' : iconCtrl.text.trim();
      setState(() {
        _billTypes.add(BillTypeConfig(id: _slugify(name), name: name, icon: icon));
      });
    }
  }

  bool _saving = false;

  Future<void> _saveSettings() async {
    final newConfig = AppConfig(
      siteTitle: _titleController.text.trim(),
      siteSubtitle: _subtitleController.text.trim(),
      currency: _currencyController.text.trim(),
      repoOwner: _ownerController.text.trim(),
      repoName: _repoController.text.trim(),
      repoBranch: _branchController.text.trim(),
      dataFileName: _dataFileController.text.trim(),
      people: _people,
      billTypes: _billTypes,
    );

    setState(() => _saving = true);

    bool pushed = false;
    try {
      pushed = await ref.read(appStateProvider.notifier).updateConfig(newConfig);
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (mounted) {
      final appStateAfter = ref.read(appStateProvider);

      if (pushed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved and pushed to GitHub!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (appStateAfter.error != null && appStateAfter.error!.isNotEmpty) {
        // A push was actually attempted and failed — show the real reason
        // instead of a generic "you need a PAT" message that's misleading
        // when a PAT is already configured.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally, but push to GitHub failed: ${appStateAfter.error}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved locally. Push to GitHub requires a valid PAT and repository.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      Navigator.pop(context);
    }
  }
}