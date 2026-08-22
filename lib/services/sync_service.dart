import '../models/config.dart';
import '../models/fund_data.dart';
import '../models/pending_operation.dart';
import '../utils/date_utils.dart';
import 'github_service.dart';
import 'storage_service.dart';

class SyncService {
  SyncService(this.storage);

  final StorageService storage;

  List<PendingOperation> loadQueue() => storage.loadPendingOperations();

  Future<int> queueSnapshot({
    required AppConfig config,
    required FundData data,
    required String message,
  }) async {
    final current = storage.loadPendingOperations();
    current.add(
      PendingOperation(
        id: AppDateUtils.generateId(),
        message: message,
        configJson: config.toJson(),
        dataJson: data.toJson(),
        createdAt: AppDateUtils.nowIso(),
      ),
    );
    await storage.savePendingOperations(current);
    return current.length;
  }

  Future<int> flushQueue(GitHubService github) async {
    final queue = storage.loadPendingOperations();
    if (queue.isEmpty) return 0;

    final remaining = <PendingOperation>[];
    for (int i = 0; i < queue.length; i++) {
      final operation = queue[i];
      try {
        if (operation.message.toLowerCase().contains('config')) {
          final config = AppConfig.fromJson(operation.configJson);
          await github.commitConfig(config, message: operation.message);
          await Future.delayed(const Duration(milliseconds: 400));
        }

        final data = FundData.fromJson(operation.dataJson);
        await github.commitData(data, message: operation.message);
      } catch (_) {
        remaining.add(operation);
      }
    }

    await storage.savePendingOperations(remaining);
    return remaining.length;
  }
}
