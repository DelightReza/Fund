
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/config.dart';
import '../models/fund_data.dart';
import '../models/transaction.dart';
import 'github_service.dart';
import 'storage_service.dart';

class SyncService {
  final StorageService storage;
  final GitHubService github;

  SyncService({required this.storage, required this.github});

  // --- Offline queue ---
  List<Map<String, dynamic>> _pendingOps = [];

  Future<void> loadPendingOps() async {
    _pendingOps = storage.loadPendingOps();
  }

  Future<void> _savePendingOps() async {
    await storage.savePendingOps(_pendingOps);
  }

  void addPendingOp(String type, Map<String, dynamic> data, {String? message}) {
    _pendingOps.add({
      'type': type,
      'data': data,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _savePendingOps();
  }

  Future<void> clearPendingOps() async {
    _pendingOps.clear();
    await _savePendingOps();
  }

  // --- Flush queue (retry) ---
  Future<void> flushQueue() async {
    if (_pendingOps.isEmpty) return;
    // We'll iterate and try each operation; remove on success.
    final List<Map<String, dynamic>> remaining = [];
    for (final op in _pendingOps) {
      final success = await _executeOperation(op);
      if (!success) {
        remaining.add(op);
      }
    }
    _pendingOps = remaining;
    await _savePendingOps();
  }

  Future<bool> _executeOperation(Map<String, dynamic> op) async {
    final type = op['type'] as String;
    final data = op['data'] as Map<String, dynamic>;
    final message = op['message'] as String?;

    try {
      switch (type) {
        case 'add_transaction':
          final tx = Transaction.fromJson(data);
          // Fetch latest data, append, commit
          final current = await github.fetchData();
          final newTxList = [tx, ...current.transactions];
          final updated = current.copyWith(transactions: newTxList);
          await github.commitData(updated, message ?? 'Add transaction');
          return true;

        case 'edit_transaction':
          final tx = Transaction.fromJson(data);
          final current = await github.fetchData();
          final index = current.transactions.indexWhere((t) => t.id == tx.id);
          if (index == -1) return false;
          final newList = List<Transaction>.from(current.transactions)
            ..[index] = tx;
          final updated = current.copyWith(transactions: newList);
          await github.commitData(updated, message ?? 'Edit transaction');
          return true;

        case 'delete_transaction':
          final id = data['id'] as String;
          final current = await github.fetchData();
          final newList = current.transactions.where((t) => t.id != id).toList();
          final updated = current.copyWith(transactions: newList);
          await github.commitData(updated, message ?? 'Delete transaction');
          return true;

        case 'update_config':
          final config = AppConfig.fromJson(data);
          await github.commitConfig(config, message ?? 'Update config');
          return true;

        default:
          return false;
      }
    } catch (e) {
      debugPrint('Sync failed for op $type: $e');
      return false;
    }
  }

  // --- Helpers for adding operations ---
  Future<void> addTransaction(Transaction tx, {String? message}) async {
    // Update local storage immediately
    final currentData = storage.loadData() ?? FundData();
    final newData = currentData.copyWith(
      transactions: [tx, ...currentData.transactions],
    );
    await storage.saveData(newData);
    // Queue op
    addPendingOp('add_transaction', tx.toJson(), message: message);
    // Try to flush immediately
    await flushQueue();
  }

  // Similarly for edit, delete, config update
}

