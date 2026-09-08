import 'app_config.dart';
import 'transaction.dart';

class FundData {
  final Map<String, double> billTypes;
  final Map<String, double> people;
  final List<TransactionModel> transactions;

  FundData({
    Map<String, double>? billTypes,
    Map<String, double>? people,
    List<TransactionModel>? transactions,
  })  : billTypes = billTypes ?? {},
        people = people ?? {},
        transactions = transactions ?? [];

  FundData copyWith({
    Map<String, double>? billTypes,
    Map<String, double>? people,
    List<TransactionModel>? transactions,
  }) {
    return FundData(
      billTypes: billTypes ?? Map.from(this.billTypes),
      people: people ?? Map.from(this.people),
      transactions: transactions ?? List.from(this.transactions),
    );
  }

  /// Recalculates people (total credited deposits) and billTypes (total debited category expenses)
  void updateSummaries(AppConfig config) {
    // 1. Calculate bill totals
    final billTotals = <String, double>{};
    for (final bt in config.billTypes) {
      billTotals[bt.id] = 0.0;
    }
    for (final tx in transactions) {
      if (tx.type == 'debit') {
        final btId = (tx.billTypeId != null && tx.billTypeId!.isNotEmpty)
            ? tx.billTypeId!
            : tx.whoOrBill;
        if (btId.isNotEmpty) {
          billTotals[btId] = (billTotals[btId] ?? 0.0) + tx.amount;
        }
      }
    }
    billTypes.clear();
    billTotals.forEach((k, v) {
      if (v > 0.0) {
        billTypes[k] = v;
      }
    });

    // 2. Calculate people totals (deposits/credits)
    final peopleTotals = <String, double>{};
    for (final m in config.members) {
      peopleTotals[m.id] = 0.0;
    }
    for (final tx in transactions) {
      if (tx.type == 'credit') {
        final pid = (tx.payerId != null && tx.payerId!.isNotEmpty)
            ? tx.payerId!
            : tx.whoOrBill;
        if (pid.isNotEmpty) {
          peopleTotals[pid] = (peopleTotals[pid] ?? 0.0) + tx.amount;
        }
      }
    }
    people.clear();
    peopleTotals.forEach((k, v) {
      if (v > 0.0) {
        people[k] = v;
      }
    });
  }

  factory FundData.fromJson(Map<String, dynamic> json) {
    final rawBillTypes = (json['billTypes'] as Map<String, dynamic>?) ?? {};
    final rawPeople = (json['people'] as Map<String, dynamic>?) ?? {};
    final rawTxs = (json['transactions'] as List<dynamic>?) ?? [];

    return FundData(
      billTypes: rawBillTypes.map((k, v) => MapEntry(k, (v as num).toDouble())),
      people: rawPeople.map((k, v) => MapEntry(k, (v as num).toDouble())),
      transactions: rawTxs
          .map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final peopleObj = people.map((k, v) => MapEntry(k, v % 1.0 == 0.0 ? v.toInt() : v));
    final billTypesObj = billTypes.map((k, v) => MapEntry(k, v % 1.0 == 0.0 ? v.toInt() : v));

    return {
      'people': peopleObj,
      'billTypes': billTypesObj,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }

  double get totalCredits =>
      transactions.where((t) => t.type == 'credit').fold(0.0, (acc, t) => acc + t.amount);

  double get totalDebits =>
      transactions.where((t) => t.type == 'debit').fold(0.0, (acc, t) => acc + t.amount);

  double get fundBalance => totalCredits - totalDebits;
}
