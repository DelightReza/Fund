import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../models/transaction.dart';

/// Intelligent merge utility for resolving concurrent edits between
/// remote GitHub repository state and local device changes.
class FundDataMerger {
  /// Merges remote and local FundData without losing any transactions.
  static FundData merge({
    required FundData remoteData,
    required FundData localData,
    required AppConfig config,
  }) {
    final remoteTxs = List<TransactionModel>.from(remoteData.transactions);
    final remoteMap = {for (var t in remoteTxs) t.id: t};

    final localTxs = localData.transactions;
    final mergedList = <TransactionModel>[];
    final processedIds = <String>{};

    // 1. Process all local transactions
    for (final localTx in localTxs) {
      if (!remoteMap.containsKey(localTx.id)) {
        // Local-only transaction (newly created locally during concurrent session or offline)
        mergedList.add(localTx);
        processedIds.add(localTx.id);
      } else {
        // Exists in both: keep local version (preserves local edits)
        mergedList.add(localTx);
        processedIds.add(localTx.id);
      }
    }

    // 2. Add remote transactions created by other members that are missing locally
    for (final remoteTx in remoteTxs) {
      if (!processedIds.contains(remoteTx.id)) {
        mergedList.add(remoteTx);
        processedIds.add(remoteTx.id);
      }
    }

    // 3. Stable sorting: primary by date descending, preserving parent-child pairing
    mergedList.sort((a, b) {
      if (a.parentId != null && a.parentId == b.parentId) {
        if (a.type == 'debit' && b.type == 'credit') return -1;
        if (a.type == 'credit' && b.type == 'debit') return 1;
      }
      return b.date.compareTo(a.date);
    });

    final result = FundData(transactions: mergedList);
    result.updateSummaries(config);
    return result;
  }
}
