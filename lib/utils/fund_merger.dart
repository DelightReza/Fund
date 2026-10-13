import '../models/app_config.dart';
import '../models/fund_data.dart';
import '../models/transaction.dart';
import 'date_utils.dart';

/// Intelligent merge utility for resolving concurrent edits between
/// remote GitHub repository state and local device changes.
class FundDataMerger {
  static const Duration _duplicateWindow = Duration(hours: 1);

  /// Checks if two transactions represent the exact same event
  static bool isEquivalent(TransactionModel a, TransactionModel b) {
    if (a.id.isNotEmpty && a.id == b.id) return true;
    if (a.type != b.type) return false;
    if ((a.amount - b.amount).abs() > 0.0001) return false;

    final dtA = AppDateUtils.parseDateTime(a.date);
    final dtB = AppDateUtils.parseDateTime(b.date);
    if (dtA.difference(dtB).abs() > _duplicateWindow) return false;

    final aNote = a.note.trim().toLowerCase();
    final bNote = b.note.trim().toLowerCase();
    if (aNote != bNote) return false;

    final aWho = a.whoOrBill.trim().toLowerCase();
    final bWho = b.whoOrBill.trim().toLowerCase();
    if (aWho != bWho) return false;

    final aPayer = (a.payerId ?? (a.type == 'credit' ? a.whoOrBill : ''))
        .trim()
        .toLowerCase();
    final bPayer = (b.payerId ?? (b.type == 'credit' ? b.whoOrBill : ''))
        .trim()
        .toLowerCase();
    if (aPayer != bPayer) return false;

    final aBill = (a.billTypeId ?? (a.type == 'debit' ? a.whoOrBill : ''))
        .trim()
        .toLowerCase();
    final bBill = (b.billTypeId ?? (b.type == 'debit' ? b.whoOrBill : ''))
        .trim()
        .toLowerCase();
    if (aBill != bBill) return false;

    if (((a.distributionTotal ?? 0.0) - (b.distributionTotal ?? 0.0)).abs() >
        0.0001) return false;

    return true;
  }

  /// Merges remote and local FundData without losing any transactions or duplicating concurrent entries.
  /// Respects tombstones (deletedIds, deletedParentIds) to prevent deleted transactions from being resurrected.
  /// Also enforces group transaction supersession so edited group transactions replace obsolete remote legs.
  static FundData merge({
    required FundData remoteData,
    required FundData localData,
    required AppConfig config,
    Set<String> deletedIds = const {},
    Set<String> deletedParentIds = const {},
  }) {
    final remoteTxs = List<TransactionModel>.from(remoteData.transactions);
    final remoteMap = {for (var t in remoteTxs) t.id: t};

    final localTxs = localData.transactions;
    final mergedList = <TransactionModel>[];
    final processedIds = <String>{};

    // Track all parentIds present locally to prevent resurrecting superseded legs of edited group transactions
    final localParentIds = localTxs
        .map((t) => t.parentId)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toSet();

    // 1. Process all local transactions
    for (final localTx in localTxs) {
      // Discard if tombstoned
      if (deletedIds.contains(localTx.id)) continue;
      if (localTx.parentId != null &&
          deletedParentIds.contains(localTx.parentId)) continue;

      TransactionModel? matchedRemote;
      if (remoteMap.containsKey(localTx.id)) {
        matchedRemote = remoteMap[localTx.id];
      } else {
        // Find equivalent remote transaction to avoid duplicating concurrent/offline entries
        matchedRemote = remoteTxs.cast<TransactionModel?>().firstWhere(
              (r) =>
                  r != null &&
                  !processedIds.contains(r.id) &&
                  !deletedIds.contains(r.id) &&
                  (r.parentId == null ||
                      !deletedParentIds.contains(r.parentId)) &&
                  isEquivalent(localTx, r),
              orElse: () => null,
            );
      }

      if (matchedRemote != null) {
        // Exists in both or matches equivalent remote entry: keep local version, mark both as processed
        mergedList.add(localTx);
        processedIds.add(localTx.id);
        processedIds.add(matchedRemote.id);
      } else {
        // Local-only transaction
        mergedList.add(localTx);
        processedIds.add(localTx.id);
      }
    }

    // 2. Add remote transactions created by other members that are missing locally
    for (final remoteTx in remoteTxs) {
      if (processedIds.contains(remoteTx.id)) continue;

      // Discard if explicitly deleted locally (tombstoned)
      if (deletedIds.contains(remoteTx.id)) continue;
      if (remoteTx.parentId != null &&
          deletedParentIds.contains(remoteTx.parentId)) continue;

      // Discard if local already has transactions for this parentId (group transaction supersession)
      if (remoteTx.parentId != null &&
          remoteTx.parentId!.isNotEmpty &&
          localParentIds.contains(remoteTx.parentId)) {
        continue;
      }

      mergedList.add(remoteTx);
      processedIds.add(remoteTx.id);
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
