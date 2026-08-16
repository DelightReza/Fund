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
    for (final operation in queue) {
      try {
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
