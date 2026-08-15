import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config.dart';
import '../providers/providers.dart';

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
    return Scaffold(
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
              IconButton(onPressed: _addMember, icon: const Icon(Icons.add)),
            ],
          ),
          ..._people.asMap().entries.map((entry) {
            final index = entry.key;
            final person = entry.value;
            return ListTile(
              title: Text(person.name),
              subtitle: Text(person.id),
              trailing: Switch(
                value: person.active,
                onChanged: (val) {
                  setState(() {
                    _people[index] = person.copyWith(active: val);
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bill Types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(onPressed: _addBillType, icon: const Icon(Icons.add)),
            ],
          ),
          ..._billTypes.map((bill) {
            return ListTile(
              leading: Text(bill.icon, style: const TextStyle(fontSize: 24)),
              title: Text(bill.name),
              subtitle: Text(bill.id),
            );
          }),
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
    );
  }

  Future<void> _addMember() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID (e.g. johndoe)')),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (result == true && idCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
      setState(() {
        _people.add(MemberConfig(id: idCtrl.text.trim(), name: nameCtrl.text.trim()));
      });
    }
  }

  Future<void> _addBillType() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '🧾');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bill Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID (e.g. internet)')),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Emoji Icon')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (result == true && idCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
      setState(() {
        _billTypes.add(BillTypeConfig(id: idCtrl.text.trim(), name: nameCtrl.text.trim(), icon: iconCtrl.text.trim()));
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
      if (pushed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved and pushed to GitHub!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved locally! (Push to GitHub required PAT)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      Navigator.pop(context);
    }
  }
}
