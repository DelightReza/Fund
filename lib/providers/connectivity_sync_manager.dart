import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../services/github_service.dart';

class ConnectivitySyncManager {
  ConnectivitySyncManager(this.ref) {
    _init();
  }

  final Ref ref;
  Timer? _pollingTimer;
  bool _isOnline = true;
  bool _isSyncing = false;

  void _init() {
    if (kIsWeb) return;

    // Check connectivity periodically (every 15s) and trigger sync immediately on reconnection
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkConnectivity());
  }

  Future<void> _checkConnectivity() async {
    if (_isSyncing) return;
    try {
      final result = await InternetAddress.lookup('api.github.com').timeout(const Duration(seconds: 4));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
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
      final github = GitHubService(
        owner: appState.config.repoOwner,
        repo: appState.config.repoName,
        branch: appState.config.repoBranch,
        dataFileName: appState.config.dataFileName,
        token: token,
      );

      final remainingCount = await syncService.flushQueue(github);
      ref.read(appStateProvider.notifier).syncPendingOperations();
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
