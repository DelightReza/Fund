import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_config.dart';
import '../../models/fund_data.dart';
import '../../repositories/fund_repository.dart';
import '../../utils/file_helper.dart';

/// Modal bottom sheet and import dialogs for managing data export and import in Admin
class AdminDataManagementHelper {
  static void showManageDataModal({
    required BuildContext context,
    required FundRepository repo,
    required void Function(String text, String label) onCopy,
    required void Function(String title, String content) onShowRawJson,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Manage Data (Export & Import)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              const SizedBox(height: 16),

              // Export Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'DOWNLOAD & EXPORT DATA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.download_rounded, color: Colors.blue, size: 20),
                ),
                title: const Text('Download data.json'),
                subtitle: const Text('Save ledger and transaction records to your device'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy JSON text',
                  onPressed: () {
                    final json = repo.exportToJsonFormatted();
                    onCopy(json, 'data.json');
                  },
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final json = repo.exportToJsonFormatted();
                  final res = await saveAndDownloadFile(
                    fileName: 'data.json',
                    content: json,
                    mimeType: 'application/json',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () => onShowRawJson('data.json', json),
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.file_download_outlined, color: Colors.purple, size: 20),
                ),
                title: const Text('Download config.json'),
                subtitle: const Text('Save workspace settings and members to your device'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy JSON text',
                  onPressed: () {
                    final json = repo.exportConfigJsonFormatted();
                    onCopy(json, 'config.json');
                  },
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final json = repo.exportConfigJsonFormatted();
                  final res = await saveAndDownloadFile(
                    fileName: 'config.json',
                    content: json,
                    mimeType: 'application/json',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () => onShowRawJson('config.json', json),
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.table_chart_outlined, color: Colors.green, size: 20),
                ),
                title: const Text('Download CSV Ledger'),
                subtitle: const Text('Save transactions as spreadsheet-ready CSV'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy CSV',
                  onPressed: () {
                    final csv = repo.exportToCsv();
                    onCopy(csv, 'CSV Export');
                  },
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final csv = repo.exportToCsv();
                  final dateStr = DateTime.now().toIso8601String().substring(0, 10);
                  final res = await saveAndDownloadFile(
                    fileName: 'fund_transactions_$dateStr.csv',
                    content: csv,
                    mimeType: 'text/csv',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        action: SnackBarAction(
                          label: 'Copy',
                          onPressed: () => onCopy(csv, 'CSV Export'),
                        ),
                      ),
                    );
                  }
                },
              ),

              const Divider(height: 24, indent: 16, endIndent: 16),

              // Import Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'UPLOAD & IMPORT DATA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.drive_folder_upload_rounded, color: Colors.teal, size: 20),
                ),
                title: const Text('Upload & Import JSON File'),
                subtitle: const Text('Pick any .json file from your device to auto-detect & import'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final content = await pickAndReadFile(allowedExtensions: ['json']);
                  if (content != null && content.isNotEmpty) {
                    bool isConfig = false;
                    try {
                      final decoded = jsonDecode(content);
                      if (decoded is Map<String, dynamic> && decoded.containsKey('siteTitle')) {
                        isConfig = true;
                      }
                    } catch (_) {}
                    if (context.mounted) {
                      showImportJsonDialog(
                        context: context,
                        isConfig: isConfig,
                        repo: repo,
                        initialJson: content,
                      );
                    }
                  } else {
                    if (context.mounted) {
                      showImportJsonDialog(
                        context: context,
                        isConfig: false,
                        repo: repo,
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: Color(0xFFD97706), size: 20),
                ),
                title: const Text('Import data.json (Paste or Upload)'),
                subtitle: const Text('Import transactions & merge with 3-way concurrent sync'),
                onTap: () {
                  Navigator.pop(ctx);
                  showImportJsonDialog(context: context, isConfig: false, repo: repo);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_backup_restore_rounded, color: Colors.indigo, size: 20),
                ),
                title: const Text('Import config.json (Paste or Upload)'),
                subtitle: const Text('Import workspace configuration and member list'),
                onTap: () {
                  Navigator.pop(ctx);
                  showImportJsonDialog(context: context, isConfig: true, repo: repo);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showImportJsonDialog({
    required BuildContext context,
    required bool isConfig,
    required FundRepository repo,
    String? initialJson,
  }) {
    final textCtrl = TextEditingController(text: initialJson ?? '');
    String? validationMessage;
    bool isValid = false;
    dynamic parsedObject;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void validate(String val) {
            final trimmed = val.trim();
            if (trimmed.isEmpty) {
              setDialogState(() {
                validationMessage = null;
                isValid = false;
                parsedObject = null;
              });
              return;
            }

            try {
              final decoded = jsonDecode(trimmed);
              if (isConfig) {
                if (decoded is Map<String, dynamic>) {
                  final cfg = AppConfig.fromJson(decoded);
                  setDialogState(() {
                    isValid = true;
                    parsedObject = cfg;
                    validationMessage =
                        '✓ Valid config: "${cfg.siteTitle}", ${cfg.members.length} members, ${cfg.billTypes.length} bill categories';
                  });
                } else {
                  setDialogState(() {
                    isValid = false;
                    parsedObject = null;
                    validationMessage = '⚠️ JSON must be a valid configuration object';
                  });
                }
              } else {
                if (decoded is Map<String, dynamic> && decoded.containsKey('transactions')) {
                  final data = FundData.fromJson(decoded);
                  setDialogState(() {
                    isValid = true;
                    parsedObject = data;
                    validationMessage =
                        '✓ Valid ledger: ${data.transactions.length} transactions, fund balance ₹${(data.totalCredits - data.totalDebits).toStringAsFixed(2)}';
                  });
                } else {
                  setDialogState(() {
                    isValid = false;
                    parsedObject = null;
                    validationMessage = '⚠️ JSON must contain a "transactions" array';
                  });
                }
              }
            } catch (e) {
              setDialogState(() {
                isValid = false;
                parsedObject = null;
                validationMessage = '⚠️ JSON Parsing Error: ${e.toString().split('\n').first}';
              });
            }
          }

          if (initialJson != null && initialJson.isNotEmpty && validationMessage == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => validate(initialJson));
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isConfig ? Icons.settings_suggest_outlined : Icons.upload_file_rounded,
                  color: isConfig ? Colors.indigo : const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConfig ? 'Import config.json' : 'Import data.json',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConfig
                          ? 'Upload a file or paste raw JSON for config.json to update workspace settings and members.'
                          : 'Upload a file or paste raw JSON for data.json to import ledger and transactions with 3-way automated merge.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textCtrl,
                      maxLines: 8,
                      onChanged: validate,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '{\n  ...\n}',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Upload File'),
                          onPressed: () async {
                            final content = await pickAndReadFile(allowedExtensions: ['json']);
                            if (content != null && content.isNotEmpty) {
                              textCtrl.text = content;
                              validate(content);
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.paste, size: 16),
                          label: const Text('Paste'),
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              textCtrl.text = data!.text!;
                              validate(data.text!);
                            }
                          },
                        ),
                      ],
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isValid
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          validationMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isValid ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isValid && parsedObject != null
                    ? () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Confirm Import'),
                            content: Text(
                              isConfig
                                  ? 'This will update your workspace configuration and sync to GitHub. Proceed?'
                                  : 'This will import the transaction ledger and sync with automated 3-way merge. Proceed?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange.shade800,
                                ),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Proceed Import'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          Navigator.of(dialogCtx).pop();
                          if (isConfig) {
                            final ok = await repo.updateConfig(parsedObject as AppConfig);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'config.json imported and updated'
                                        : 'Saved locally (sync pending)',
                                  ),
                                ),
                              );
                            }
                          } else {
                            final ok = await repo.importFundData(parsedObject as FundData);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'data.json imported and synchronized'
                                        : 'Saved locally (sync pending)',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      }
                    : null,
                child: const Text('Import & Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
