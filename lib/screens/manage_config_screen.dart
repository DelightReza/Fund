import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../repositories/fund_repository.dart';
import '../widgets/confirmation_dialog.dart';
import '../utils/app_router.dart';
import 'main_screen.dart';

class ManageConfigScreen extends StatefulWidget {
  final bool isRestoredAfterRefresh;

  const ManageConfigScreen({
    super.key,
    this.isRestoredAfterRefresh = false,
  });

  @override
  State<ManageConfigScreen> createState() => _ManageConfigScreenState();
}

class _ManageConfigScreenState extends State<ManageConfigScreen> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _currencyController;
  late List<MemberConfig> _members;
  late List<BillTypeConfig> _billTypes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<FundRepository>().config ?? AppConfig();
    _titleController = TextEditingController(text: config.siteTitle);
    _subtitleController = TextEditingController(text: config.siteSubtitle);
    _currencyController = TextEditingController(text: config.currency);
    _members = List.from(config.members);
    _billTypes = List.from(config.billTypes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _addMemberDialog() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    bool userEditedId = false;

    nameCtrl.addListener(() {
      if (!userEditedId) {
        final auto = nameCtrl.text.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (idCtrl.text != auto) {
          idCtrl.value = TextEditingValue(
            text: auto,
            selection: TextSelection.collapsed(offset: auto.length),
          );
        }
      }
    });

    idCtrl.addListener(() {
      final expectedAuto = nameCtrl.text.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      if (idCtrl.text.trim().isEmpty) {
        userEditedId = false;
      } else if (idCtrl.text != expectedAuto) {
        userEditedId = true;
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Alice',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Unique ID',
                hintText: 'e.g. alice',
                helperText: 'Auto-generated lowercase identifier',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty && idCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _members.add(MemberConfig(
                    id: idCtrl.text.trim().toLowerCase(),
                    name: nameCtrl.text.trim(),
                    active: true,
                  ));
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      nameCtrl.dispose();
      idCtrl.dispose();
    });
  }

  void _addBillTypeDialog() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '🧾');
    bool userEditedId = false;

    nameCtrl.addListener(() {
      if (!userEditedId) {
        final auto = nameCtrl.text.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (idCtrl.text != auto) {
          idCtrl.value = TextEditingValue(
            text: auto,
            selection: TextSelection.collapsed(offset: auto.length),
          );
        }
      }
    });

    idCtrl.addListener(() {
      final expectedAuto = nameCtrl.text.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      if (idCtrl.text.trim().isEmpty) {
        userEditedId = false;
      } else if (idCtrl.text != expectedAuto) {
        userEditedId = true;
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bill Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Groceries',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Unique ID',
                hintText: 'e.g. groceries',
                helperText: 'Auto-generated lowercase identifier',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconCtrl,
              decoration: const InputDecoration(
                labelText: 'Emoji Icon',
                hintText: '🛒',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty && idCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _billTypes.add(BillTypeConfig(
                    id: idCtrl.text.trim().toLowerCase(),
                    name: nameCtrl.text.trim(),
                    icon: iconCtrl.text.trim().isNotEmpty ? iconCtrl.text.trim() : '🧾',
                  ));
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      nameCtrl.dispose();
      idCtrl.dispose();
      iconCtrl.dispose();
    });
  }

  Future<void> _deleteMember(int index) async {
    final member = _members[index];
    final confirmed = await ActionConfirmationDialog.show(
      context,
      title: 'Remove Member?',
      message: 'Are you sure you want to remove "${member.name}" (@${member.id}) from the configuration?',
      confirmLabel: 'Remove Member',
      confirmColor: Colors.red,
      icon: Icons.person_remove_rounded,
    );
    if (confirmed == true && mounted) {
      setState(() {
        _members.removeAt(index);
      });
    }
  }

  Future<void> _deleteBillType(int index) async {
    final bill = _billTypes[index];
    final confirmed = await ActionConfirmationDialog.show(
      context,
      title: 'Remove Bill Category?',
      message: 'Are you sure you want to remove category "${bill.icon} ${bill.name}" (@${bill.id}) from the configuration?',
      confirmLabel: 'Remove Category',
      confirmColor: Colors.red,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true && mounted) {
      setState(() {
        _billTypes.removeAt(index);
      });
    }
  }

  Future<void> _saveConfig() async {
    final confirmed = await ActionConfirmationDialog.show(
      context,
      title: 'Save Configuration?',
      message: 'This will update config.json and synchronize settings, members, and categories to GitHub.',
      confirmLabel: 'Save Changes',
      confirmColor: Theme.of(context).colorScheme.primary,
      icon: Icons.save_rounded,
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final repo = context.read<FundRepository>();
    final curConfig = repo.config ?? AppConfig();

    final updated = curConfig.copyWith(
      siteTitle: _titleController.text.trim(),
      siteSubtitle: _subtitleController.text.trim(),
      currency: _currencyController.text.trim(),
      members: _members,
      billTypes: _billTypes,
    );

    final ok = await repo.updateConfig(updated);
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved to GitHub config.json')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally (GitHub sync failed or missing token)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    void handleBack() {
      AppRouter.popOrNavigateTo(
        context,
        'admin',
        forceDirect: widget.isRestoredAfterRefresh,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: handleBack,
          ),
          title: const Text('Manage Configuration'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveConfig,
            tooltip: 'Save to GitHub',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('General Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Site / Fund Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subtitleController,
                    decoration: const InputDecoration(labelText: 'Subtitle / Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _currencyController,
                    decoration: const InputDecoration(labelText: 'Currency Symbol (e.g. ₹, \$, €)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Members / People', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                        onPressed: _addMemberDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._members.asMap().entries.map((entry) {
                    final index = entry.key;
                    final member = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('@${member.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: member.active,
                            onChanged: (val) {
                              setState(() {
                                _members[index] = member.copyWith(active: val);
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            onPressed: () => _deleteMember(index),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bill Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                        onPressed: _addBillTypeDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._billTypes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final bill = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(bill.icon, style: const TextStyle(fontSize: 20)),
                      title: Text(bill.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('@${bill.id}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () => _deleteBillType(index),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    ),
    );
  }
}
