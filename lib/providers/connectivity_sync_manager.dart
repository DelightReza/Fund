import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'providers.dart';

class ConnectivitySyncManager {
  ConnectivitySyncManager(this.ref) {
    _init();
  }

  final Ref ref;
  Timer? _pollingTimer;
  bool _isOnline = true;
  bool _isSyncing = false;

  void _init() {
    // Check connectivity periodically (every 20s) and trigger sync immediately on reconnection
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkConnectivity());
  }

  Future<void> _checkConnectivity() async {
    if (_isSyncing) return;
    try {
      final appState = ref.read(appStateProvider);
      final token = appState.token;
      final headers = <String, String>{
        if (token != null && token.isNotEmpty)
          'Authorization': token.startsWith('github_pat_') ? 'Bearer $token' : 'token $token',
      };

      final res = await http
          .head(Uri.parse('https://api.github.com'), headers: headers)
          .timeout(const Duration(seconds: 4));
      final online = res.statusCode > 0 && res.statusCode != 403;

      if (online && !_isOnline) {
        _isOnline = true;
        await triggerAutoSync();
      } else {
        _isOnline = online;
      }
    } catch (_) {
      _isOnline = false;
    }
  }

  Future<void> triggerAutoSync() async {
    final appState = ref.read(appStateProvider);
    if (!appState.config.hasRepository) return;

    final token = appState.token;
    if (token == null || token.isEmpty) return;

    final syncService = ref.read(syncServiceProvider);
    final queue = syncService.loadQueue();
    if (queue.isEmpty) return;

    _isSyncing = true;
    try {
      await ref.read(appStateProvider.notifier).syncNow();
    } catch (_) {
      // Keep in queue for next connectivity check
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
  }
}

final connectivitySyncManagerProvider = Provider<ConnectivitySyncManager>((ref) {
  final manager = ConnectivitySyncManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
});

